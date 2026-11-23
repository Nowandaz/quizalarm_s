-- BrainWake database, part 23: marks, and questions with a longer answer.
--
-- Exam short-answer questions often want several things ("List 4 aims of
-- pre-anaesthetic medication (4 marks)"). Those cannot stop an alarm: a
-- sleepy person cannot type four items to switch it off. So a typed
-- question can now be a LONG ANSWER question:
--   marks       how many marks it carries (1 for ordinary questions);
--   key_points  what earns the marks: a list of points, each a list of
--               wordings that count for it, e.g.
--               [["atropine","hyoscine"],["midazolam","diazepam"]]
--               The app counts how many points the typed answer has.
--   answer      the model answer shown afterwards.
-- Long answer questions are for practice only; the app never asks them
-- when an alarm rings.
--
-- Older versions of the app do not know about them and would ask them in
-- an alarm as ordinary typed questions. So they are only handed to apps
-- that say they understand them (a request header the newer app sends).

alter table public.questions
  add column marks integer not null default 1 check (marks between 1 and 20),
  add column long_answer boolean not null default false,
  add column key_points jsonb not null default '[]'::jsonb check (jsonb_typeof(key_points) = 'array'),
  add constraint questions_long_answer_shape check (not long_answer or type = 'saq');

-- True when the app asking has said it understands long answer questions.
create function public.app_knows_long_answers() returns boolean
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.headers', true), '')::json ->> 'x-app-features', ''
  ) like '%long-answers%';
$$;
grant execute on function public.app_knows_long_answers() to anon, authenticated;

drop policy "read published questions by plan" on public.questions;
create policy "read published questions by plan" on public.questions
  for select to anon, authenticated
  using (
    public.is_admin()
    or (
      status = 'published'
      and (not long_answer or public.app_knows_long_answers())
      and (public.has_premium() or public.can_sample(id, topic_id))
    )
  );

-- The home page's demo never asks long answer questions either.
create or replace function public.homepage_questions(how_many integer default 12) returns jsonb
language sql stable security definer set search_path = public as $$
  with picked as (
    select q.type, q.text, q.options, q.answer, q.alt_answers, q.explanation, q.image_path, t.name as topic
    from questions q join topics t on t.id = q.topic_id
    where q.on_homepage and q.status = 'published' and q.deleted_at is null and t.deleted_at is null
      and not q.long_answer
  ),
  fallback as (
    select q.type, q.text, q.options, q.answer, q.alt_answers, q.explanation, q.image_path, t.name as topic
    from questions q join topics t on t.id = q.topic_id
    where not exists (select 1 from picked)
      and t.access = 'guest' and t.deleted_at is null
      and q.status = 'published' and q.deleted_at is null and q.image_path = '' and not q.long_answer
  ),
  pool as (select * from picked union all select * from fallback)
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  from (select * from pool order by random() limit least(greatest(how_many, 1), 30)) x;
$$;
