-- BrainWake database: AI providers.
--
-- Instead of one Gemini key, the owner keeps a list of providers (Gemini,
-- Groq, OpenAI, OpenRouter, Anthropic, anything OpenAI-compatible...).
-- The server takes them in turn (round robin), so the load and each
-- provider's free allowance are shared out. A provider with weight 2 gets
-- twice as many calls as one with weight 1.
--
-- API keys are write-only: they can be saved, replaced or removed through
-- the admin_* functions, but nothing lets the website or the app read
-- one back. Only the server (service key) reads them, via
-- pick_ai_provider().

create table public.ai_providers (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(trim(name)) > 0),
  -- The request format: 'openai' also covers Groq, OpenRouter, Together,
  -- DeepSeek and any other OpenAI-compatible service.
  type       text not null check (type in ('openai', 'gemini', 'anthropic')),
  api_key    text not null check (length(trim(api_key)) > 0),
  -- Base address, e.g. https://api.groq.com/openai/v1. Empty = the usual
  -- address for the type.
  endpoint   text not null default '',
  -- Empty = the server's default model for the type.
  model      text not null default '',
  weight     integer not null default 1 check (weight between 1 and 100),
  enabled    boolean not null default true,
  -- Round-robin bookkeeping and the last problem seen, for the admin page.
  uses          bigint not null default 0,
  last_used_at  timestamptz,
  last_error    text not null default '',
  last_error_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger ai_providers_touch before update on public.ai_providers
  for each row execute function public.touch_updated_at();

-- No rule lets anyone read this table directly.
alter table public.ai_providers enable row level security;
revoke all on public.ai_providers from anon, authenticated;

-- The list for the admin page: everything except the key itself.
create function public.admin_list_ai_providers()
returns table (
  id uuid, name text, type text, key_ending text, endpoint text, model text,
  weight integer, enabled boolean, uses bigint, last_used_at timestamptz,
  last_error text, last_error_at timestamptz, created_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  return query
    select p.id, p.name, p.type, right(p.api_key, 4), p.endpoint, p.model,
           p.weight, p.enabled, p.uses, p.last_used_at, p.last_error,
           p.last_error_at, p.created_at
    from public.ai_providers p
    order by p.created_at;
end;
$$;

-- Adds a provider (provider_id null) or changes one. When changing, an
-- empty new_key keeps the saved key.
create function public.admin_save_ai_provider(
  provider_id uuid, new_name text, new_type text, new_key text,
  new_endpoint text default '', new_model text default '',
  new_weight integer default 1, new_enabled boolean default true
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  result uuid;
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  if provider_id is null then
    if length(trim(coalesce(new_key, ''))) = 0 then
      raise exception 'An API key is required';
    end if;
    insert into public.ai_providers (name, type, api_key, endpoint, model, weight, enabled)
    values (trim(new_name), new_type, trim(new_key), trim(coalesce(new_endpoint, '')),
            trim(coalesce(new_model, '')), new_weight, new_enabled)
    returning id into result;
  else
    update public.ai_providers set
      name = trim(new_name),
      type = new_type,
      api_key = case when length(trim(coalesce(new_key, ''))) = 0
                     then api_key else trim(new_key) end,
      endpoint = trim(coalesce(new_endpoint, '')),
      model = trim(coalesce(new_model, '')),
      weight = new_weight,
      enabled = new_enabled,
      -- A changed provider gets a clean slate.
      last_error = '', last_error_at = null
    where id = provider_id
    returning id into result;
    if result is null then raise exception 'That provider no longer exists'; end if;
  end if;
  return result;
end;
$$;

create function public.admin_set_ai_provider_enabled(provider_id uuid, is_enabled boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  update public.ai_providers set enabled = is_enabled where id = provider_id;
end;
$$;

create function public.admin_delete_ai_provider(provider_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Owner only'; end if;
  delete from public.ai_providers where id = provider_id;
end;
$$;

-- SERVER ONLY. Hands out the next provider in weighted round-robin order:
-- the enabled one that has had the fewest calls for its weight. Providers
-- listed in "skip" (ones that just failed) are passed over, so the server
-- can fall through to the next.
create function public.pick_ai_provider(skip uuid[] default '{}')
returns table (id uuid, name text, type text, api_key text, endpoint text, model text)
language plpgsql security definer set search_path = public as $$
declare
  chosen uuid;
begin
  select p.id into chosen
  from public.ai_providers p
  where p.enabled and not (p.id = any (skip))
  order by (p.uses::numeric / p.weight), p.last_used_at nulls first, p.created_at
  limit 1
  for update skip locked;
  if chosen is null then return; end if;
  update public.ai_providers p
    set uses = p.uses + 1, last_used_at = now()
    where p.id = chosen;
  return query
    select p.id, p.name, p.type, p.api_key, p.endpoint, p.model
    from public.ai_providers p where p.id = chosen;
end;
$$;

-- SERVER ONLY. Records that a provider failed (empty text clears it).
create function public.report_ai_provider_error(provider_id uuid, error_text text)
returns void
language sql security definer set search_path = public as $$
  update public.ai_providers
    set last_error = left(coalesce(error_text, ''), 500),
        last_error_at = case when coalesce(error_text, '') = '' then null else now() end
    where id = provider_id;
$$;

revoke execute on function
  public.admin_list_ai_providers(),
  public.admin_save_ai_provider(uuid, text, text, text, text, text, integer, boolean),
  public.admin_set_ai_provider_enabled(uuid, boolean),
  public.admin_delete_ai_provider(uuid),
  public.pick_ai_provider(uuid[]),
  public.report_ai_provider_error(uuid, text)
  from public, anon, authenticated;
grant execute on function
  public.admin_list_ai_providers(),
  public.admin_save_ai_provider(uuid, text, text, text, text, text, integer, boolean),
  public.admin_set_ai_provider_enabled(uuid, boolean),
  public.admin_delete_ai_provider(uuid)
  to authenticated;
grant execute on function
  public.pick_ai_provider(uuid[]),
  public.report_ai_provider_error(uuid, text)
  to service_role;

-- The single-model setting is replaced by a model per provider.
delete from public.app_config where key = 'ai_model';
