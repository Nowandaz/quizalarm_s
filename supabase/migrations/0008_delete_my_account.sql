-- BrainWake database, part 8: a user can delete their own account.
--
-- Everything stored for the account goes with it (answers, sessions, AI
-- questions, backups, alarm diary and reports, AI usage, profile): those
-- tables all point at the account and are removed with it.
--
-- The last owner cannot delete themselves: the system would be left with
-- nobody in charge, and the next person to sign in could claim it.

create function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'Sign in first'; end if;
  if exists (select 1 from public.profiles where id = me and role = 'owner')
     and not exists (select 1 from public.profiles where id <> me and role = 'owner') then
    raise exception 'You are the only owner. Make someone else an owner first.';
  end if;
  delete from auth.users where id = me;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
