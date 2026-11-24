-- BrainWake database, part 25: an admin's phone is a phone too.
--
-- Long answer questions are only handed to apps that say they understand
-- them (part 23). An admin, though, was shown every question whatever the
-- app said, so an owner signed in on an OLD version of the app received
-- long answer questions and had them asked in alarms. Now nobody's phone
-- gets them without saying so; the check is only skipped when the
-- request does not come from the phone app (the admin site runs in a
-- browser).

-- True when the request comes from the phone app (which is written in
-- Dart) rather than from a browser.
create function public.from_phone_app() returns boolean
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.headers', true), '')::json ->> 'user-agent', ''
  ) ilike 'dart/%';
$$;
grant execute on function public.from_phone_app() to anon, authenticated;

-- A restrictive policy narrows every other one, including the one that
-- lets admins manage questions.
create policy "phones that do not know long answers never get them" on public.questions
  as restrictive for select to anon, authenticated
  using (not long_answer or public.app_knows_long_answers() or not public.from_phone_app());
