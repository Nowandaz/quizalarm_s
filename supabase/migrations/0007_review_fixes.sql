-- BrainWake database, part 7: fixes from a review.
--
-- 1. AI providers: a new or re-enabled provider used to take EVERY call
--    until its counter caught up with the others. It now starts level
--    with them.
-- 2. AI providers: a saved key could be redirected by changing only the
--    provider's address. Changing the address or type now needs the key
--    typed again.
-- 3. Question bank: phones could not learn that a question was unpublished
--    (they are not allowed to read drafts), so it stayed on them for days.
--    question_tombstones lists the ids of withdrawn questions.

-- The counter a provider should start from so that it takes its fair
-- share from now on: level with the least-used enabled provider.
create function public.ai_provider_fair_start(for_weight integer, except_id uuid default null)
returns bigint
language sql stable security definer set search_path = public as $$
  select coalesce(ceil(min(p.uses::numeric / p.weight) * for_weight), 0)::bigint
  from public.ai_providers p
  where p.enabled and (except_id is null or p.id <> except_id);
$$;
revoke execute on function public.ai_provider_fair_start(integer, uuid) from public, anon, authenticated;

create or replace function public.admin_save_ai_provider(
  provider_id uuid, new_name text, new_type text, new_key text,
  new_endpoint text default '', new_model text default '',
  new_weight integer default 1, new_enabled boolean default true
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  result uuid;
  old public.ai_providers%rowtype;
  no_key boolean := length(trim(coalesce(new_key, ''))) = 0;
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  if provider_id is null then
    if no_key then raise exception 'An API key is required'; end if;
    insert into public.ai_providers (name, type, api_key, endpoint, model, weight, enabled, uses)
    values (trim(new_name), new_type, trim(new_key), trim(coalesce(new_endpoint, '')),
            trim(coalesce(new_model, '')), new_weight, new_enabled,
            public.ai_provider_fair_start(new_weight))
    returning id into result;
  else
    select * into old from public.ai_providers where id = provider_id;
    if not found then raise exception 'That provider no longer exists'; end if;
    -- The saved key must never be sent anywhere new without being re-typed.
    if no_key and (old.type <> new_type
                   or old.endpoint <> trim(coalesce(new_endpoint, ''))) then
      raise exception 'Type the API key again to change the type or the address';
    end if;
    update public.ai_providers set
      name = trim(new_name),
      type = new_type,
      api_key = case when no_key then api_key else trim(new_key) end,
      endpoint = trim(coalesce(new_endpoint, '')),
      model = trim(coalesce(new_model, '')),
      weight = new_weight,
      enabled = new_enabled,
      uses = case when new_enabled and not old.enabled
                  then public.ai_provider_fair_start(new_weight, provider_id)
                  else uses end,
      -- A changed provider gets a clean slate.
      last_error = '', last_error_at = null
    where id = provider_id
    returning id into result;
  end if;
  return result;
end;
$$;

create or replace function public.admin_set_ai_provider_enabled(provider_id uuid, is_enabled boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  update public.ai_providers set
    uses = case when is_enabled and not enabled
                then public.ai_provider_fair_start(weight, provider_id)
                else uses end,
    enabled = is_enabled
  where id = provider_id;
end;
$$;

-- Ids of questions that were deleted or unpublished since a moment, for
-- phones to remove. Gives away nothing but ids.
create function public.question_tombstones(since timestamptz)
returns table (id text)
language sql stable security definer set search_path = public as $$
  select q.id from public.questions q
  where q.updated_at >= since
    and (q.deleted_at is not null or q.status <> 'published')
  limit 5000;
$$;
revoke execute on function public.question_tombstones(timestamptz) from public;
grant execute on function public.question_tombstones(timestamptz) to anon, authenticated;
