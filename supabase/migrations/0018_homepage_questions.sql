-- BrainWake database, part 18: the questions the home page's demo asks.
--
-- The alarm on the website's front page asks real questions from the
-- bank. An admin picks which ones ("On the home page" on a question).
-- Their answers and explanations become public, so pick ones that are
-- fine to give away.

alter table public.questions add column on_homepage boolean not null default false;

-- ANYONE. The picked questions (published, not deleted, without a
-- picture), in a random order. If none is picked yet, a few sample
-- questions of the starter topics, which are free to read anyway.
create function public.homepage_questions(how_many integer default 12) returns jsonb
language sql stable security definer set search_path = public as $$
  with picked as (
    select q.type, q.text, q.options, q.answer, q.alt_answers, q.explanation, t.name as topic
    from questions q join topics t on t.id = q.topic_id
    where q.on_homepage and q.status = 'published' and q.deleted_at is null and q.image_path = ''
      and t.deleted_at is null
  ),
  fallback as (
    select q.type, q.text, q.options, q.answer, q.alt_answers, q.explanation, t.name as topic
    from questions q join topics t on t.id = q.topic_id
    where not exists (select 1 from picked)
      and t.access = 'guest' and t.deleted_at is null
      and q.status = 'published' and q.deleted_at is null and q.image_path = ''
  ),
  pool as (select * from picked union all select * from fallback)
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  from (select * from pool order by random() limit least(greatest(how_many, 1), 30)) x;
$$;
revoke execute on function public.homepage_questions(integer) from public;
grant execute on function public.homepage_questions(integer) to anon, authenticated;
