-- BrainWake database, part 19: picture ("spotter") questions can be on
-- the home page's demo too. The function now also hands out the picture.

create or replace function public.homepage_questions(how_many integer default 12) returns jsonb
language sql stable security definer set search_path = public as $$
  with picked as (
    select q.type, q.text, q.options, q.answer, q.alt_answers, q.explanation, q.image_path, t.name as topic
    from questions q join topics t on t.id = q.topic_id
    where q.on_homepage and q.status = 'published' and q.deleted_at is null and t.deleted_at is null
  ),
  fallback as (
    select q.type, q.text, q.options, q.answer, q.alt_answers, q.explanation, q.image_path, t.name as topic
    from questions q join topics t on t.id = q.topic_id
    where not exists (select 1 from picked)
      and t.access = 'guest' and t.deleted_at is null
      and q.status = 'published' and q.deleted_at is null and q.image_path = ''
  ),
  pool as (select * from picked union all select * from fallback)
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  from (select * from pool order by random() limit least(greatest(how_many, 1), 30)) x;
$$;
