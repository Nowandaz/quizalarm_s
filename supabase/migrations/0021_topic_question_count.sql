-- BrainWake database, part 21: how many questions a topic has.
--
-- The outline of a unit can be written before its questions. The app must
-- not show those empty topics (to someone without a paid plan they would
-- look like locked topics with something behind them). A phone cannot
-- count the questions of a topic it may not read, so the topic row itself
-- carries the number of its published questions, kept up to date here.

alter table public.topics add column question_count integer not null default 0;

create function public.count_topic_questions(topic text) returns void
language sql security definer set search_path = public as $$
  update topics t set question_count = (
      select count(*) from questions q
      where q.topic_id = t.id and q.status = 'published' and q.deleted_at is null)
    where t.id = topic
      and t.question_count is distinct from (
        select count(*) from questions q
        where q.topic_id = t.id and q.status = 'published' and q.deleted_at is null);
$$;
revoke execute on function public.count_topic_questions(text) from public, anon, authenticated;

create function public.questions_recount() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op <> 'INSERT' then perform count_topic_questions(old.topic_id); end if;
  if tg_op <> 'DELETE' then perform count_topic_questions(new.topic_id); end if;
  return null;
end $$;
create trigger questions_recount after insert or delete or update of topic_id, status, deleted_at on public.questions
  for each row execute function public.questions_recount();

update public.topics t set question_count = (
  select count(*) from public.questions q
  where q.topic_id = t.id and q.status = 'published' and q.deleted_at is null);
