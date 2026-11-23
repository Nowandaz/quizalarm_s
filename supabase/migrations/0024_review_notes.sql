-- BrainWake database, part 24: a note for whoever checks a question.
--
-- Questions brought in from past papers carry where they came from
-- ("mcq p.004 Q1, CAT 1 2022/2023") and, when they were held back as
-- drafts, why ("two options could be defended"). The admin site shows it;
-- the app does not use it.

alter table public.questions add column review_note text not null default '' check (length(review_note) <= 600);
