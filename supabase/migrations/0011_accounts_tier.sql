-- BrainWake database, part 11: the accounts list shows each account's tier,
-- so the owner can see and change it on the Accounts page.

drop function public.admin_list_users(text, integer, integer);
create function public.admin_list_users(
  search text default '', max_rows integer default 100, skip integer default 0
) returns table (
  id uuid, email text, display_name text, role text, plan text, tier text,
  plan_expires_at timestamptz, created_at timestamptz,
  last_sign_in_at timestamptz, answers bigint, ai_calls bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  return query
    select p.id, u.email::text, p.display_name, p.role, p.plan, p.tier,
           p.plan_expires_at, u.created_at, u.last_sign_in_at,
           (select count(*) from public.user_attempts a where a.user_id = p.id),
           (select count(*) from public.ai_usage g where g.user_id = p.id)
    from public.profiles p
    join auth.users u on u.id = p.id
    where search = ''
       or u.email ilike '%' || search || '%'
       or p.display_name ilike '%' || search || '%'
    order by u.created_at desc
    limit greatest(1, least(max_rows, 500)) offset greatest(0, skip);
end;
$$;
revoke execute on function public.admin_list_users(text, integer, integer) from public, anon;
grant execute on function public.admin_list_users(text, integer, integer) to authenticated;
