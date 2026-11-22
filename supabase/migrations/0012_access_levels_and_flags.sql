-- BrainWake database, part 12: who gets which questions, the Pro and
-- Ultra plans, and questions flagged for review.
--
-- THE MODEL
--   guest  (no account)        the first 10 questions of topics marked
--                              "guest" (the starter topics)
--   free   (account, no plan)  the same, plus the first 10 questions of
--                              topics marked "free"
--   paid   (Pro or Ultra)      every published question
-- Every topic's NAME stays readable by everyone, so the app can show the
-- locked ones with a padlock. The questions themselves never leave the
-- database for someone whose plan does not cover them.
--
-- The older per-unit "premium" switch is no longer used for this: the
-- topic's own setting decides.

-- ------------------------------------------------------------ topic access
alter table public.topics
  add column access text not null default 'paid'
  check (access in ('guest', 'free', 'paid'));

-- The starter topics (the same ones the app ships with). Change them at
-- any time on the admin site.
update public.topics set access = 'guest'
  where name in ('General principles', 'Cardiovascular drugs');
update public.topics set access = 'free'
  where name in ('Autonomic nervous system', 'Antimicrobials');

-- How many questions of an open topic someone without a paid plan gets.
insert into public.app_config (key, value, note) values
  ('sample_questions', '10', 'Questions per open topic for guests and free accounts')
on conflict (key) do nothing;

-- True when this question is one of the sample questions of a topic the
-- caller may open without a paid plan.
create function public.can_sample(q_id text, q_topic text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
      select 1 from topics t
      where t.id = q_topic
        and t.deleted_at is null
        and (t.access = 'guest' or (t.access = 'free' and auth.uid() is not null))
    )
    and q_id in (
      select q.id from questions q
      where q.topic_id = q_topic and q.status = 'published' and q.deleted_at is null
      order by q.created_at, q.id
      limit greatest(0, coalesce(
        (select (value #>> '{}')::integer from app_config where key = 'sample_questions'), 10))
    );
$$;
revoke execute on function public.can_sample(text, text) from public;
grant execute on function public.can_sample(text, text) to anon, authenticated;

drop policy "read published questions; premium units need a plan" on public.questions;
create policy "read published questions by plan" on public.questions
  for select to anon, authenticated
  using (
    public.is_admin()
    or (
      status = 'published'
      and (public.has_premium() or public.can_sample(id, topic_id))
    )
  );

-- ------------------------------------------------------------------- plans
-- Pro: KES 100 a month, 100 AI calls a day. Ultra: KES 150 a month, 500 AI
-- calls a day and faster support. Pro's yearly price stays as the owner set
-- it; Ultra has none (not sold yearly) until the owner sets one.
update public.tiers set
    name = 'Pro',
    description = 'The whole question bank, the AI and your own alarm volume.',
    features = '["Every topic in the question bank",
                 "AI tutor and new AI questions: 100 a day",
                 "Trends and figures for every topic",
                 "Choose and lock each alarm''s volume"]'::jsonb,
    price_month = 100, ai_daily_limit = 100, sort_order = 1, active = true
  where id = 'pro';
insert into public.tiers (id, name, description, features, price_month, price_year, ai_daily_limit, sort_order)
values ('ultra', 'Ultra', 'Everything in Pro, far more AI and faster support.',
        '["Everything in Pro",
          "AI tutor and new AI questions: 500 a day",
          "Faster replies from the support team"]'::jsonb,
        150, null, 500, 2)
on conflict (id) do update set
  name = excluded.name, description = excluded.description, features = excluded.features,
  price_month = excluded.price_month, ai_daily_limit = excluded.ai_daily_limit,
  sort_order = excluded.sort_order;

-- The AI is a paid feature: free accounts get none.
update public.app_config set value = '0', note = 'AI calls per day for a free account (0 = the AI is for paid plans only)'
  where key = 'ai_daily_limit_free';

-- --------------------------------------------------------- flagged questions
-- A user can flag a question they met in their history ("the answer is
-- wrong", "unclear"...). Admins see the flags and mark them dealt with.
create table public.question_flags (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Not a foreign key: it may be one of the user's own questions, and the
  -- flag should outlive a question that gets replaced.
  question_id   text not null check (length(question_id) between 1 and 200),
  -- The question as the user saw it.
  question_text text not null default '' check (length(question_text) <= 4000),
  reason        text not null default 'other'
                check (reason in ('wrong_answer', 'unclear', 'typo', 'picture', 'other')),
  note          text not null default '' check (length(note) <= 300),
  status        text not null default 'open' check (status in ('open', 'resolved')),
  created_at    timestamptz not null default now(),
  resolved_at   timestamptz,
  resolved_by   uuid references auth.users (id) on delete set null,
  unique (user_id, question_id)
);
create index question_flags_open_idx on public.question_flags (created_at desc) where status = 'open';

alter table public.question_flags enable row level security;
create policy "flag a question as yourself" on public.question_flags
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'open' and resolved_at is null and resolved_by is null);
create policy "see your own flags" on public.question_flags
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy "admins handle flags" on public.question_flags
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admins remove flags" on public.question_flags
  for delete to authenticated using (public.is_admin());
grant select, insert, update, delete on public.question_flags to authenticated;

-- At most 30 flags a day per person, so the list cannot be flooded.
create function public.limit_question_flags() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from question_flags
      where user_id = new.user_id and created_at > now() - interval '1 day') >= 30 then
    raise exception 'You have flagged many questions today. Try again tomorrow.'
      using errcode = 'check_violation';
  end if;
  return new;
end $$;
create trigger question_flags_limit before insert on public.question_flags
  for each row execute function public.limit_question_flags();

-- ADMINS. The flags, newest first, with the question as it is now.
create function public.admin_list_flags(only_open boolean default true, max_rows integer default 200)
returns table (
  id uuid, created_at timestamptz, status text, reason text, note text, email text,
  question_id text, question_text text, in_bank boolean, topic_id text, topic text, unit_id text, unit text,
  current_text text, current_answer text, others integer
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = 'insufficient_privilege';
  end if;
  return query
    select f.id, f.created_at, f.status, f.reason, f.note, u.email::text,
           f.question_id, f.question_text, q.id is not null, q.topic_id, t.name, n.id, n.name,
           q.text, q.answer,
           (select count(*)::integer from question_flags o
             where o.question_id = f.question_id and o.id <> f.id and o.status = 'open')
    from question_flags f
    left join auth.users u on u.id = f.user_id
    left join questions q on q.id = f.question_id and q.deleted_at is null
    left join topics t on t.id = q.topic_id
    left join units n on n.id = t.unit_id
    where (not only_open or f.status = 'open')
    order by f.created_at desc
    limit least(greatest(max_rows, 1), 1000);
end $$;
revoke execute on function public.admin_list_flags(boolean, integer) from public, anon;
grant execute on function public.admin_list_flags(boolean, integer) to authenticated;

-- ADMINS. Marks a flag (and, if asked, every open flag on that question)
-- as dealt with, or opens it again.
create function public.admin_resolve_flag(flag uuid, resolved boolean default true, whole_question boolean default false)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  changed integer;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = 'insufficient_privilege';
  end if;
  update question_flags f set
      status = case when resolved then 'resolved' else 'open' end,
      resolved_at = case when resolved then now() end,
      resolved_by = case when resolved then auth.uid() end
    where f.id = flag
       or (whole_question and f.status = 'open'
           and f.question_id = (select x.question_id from question_flags x where x.id = flag));
  get diagnostics changed = row_count;
  return changed;
end $$;
revoke execute on function public.admin_resolve_flag(uuid, boolean, boolean) from public, anon;
grant execute on function public.admin_resolve_flag(uuid, boolean, boolean) to authenticated;
