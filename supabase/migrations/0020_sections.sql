-- BrainWake database, part 20: units get sub units and sections.
--
-- The question bank was Unit > Topic > Questions. It is now
--   Unit > (Sub unit, optional) > Section > Topic > Questions
-- e.g. Pharmacology > Autonomic nervous system > Cholinergic drugs, or
-- Pathology > Haematology > Red cells > Sickle cell disease.
--
-- One table, "sections", holds both kinds:
--   a SUB UNIT sits directly under a unit and contains sections;
--   a SECTION sits under a unit or under a sub unit and contains topics.
-- A topic says which section it is in (empty = not filed yet).

create table public.sections (
  id          text primary key,
  unit_id     text not null references public.units (id) on delete cascade,
  -- Only for a section inside a sub unit: that sub unit.
  parent_id   text references public.sections (id) on delete set null,
  kind        text not null default 'section' check (kind in ('subunit', 'section')),
  name        text not null check (length(trim(name)) > 0),
  description text not null default '',
  sort_order  integer not null default 0,
  deleted_at  timestamptz,
  updated_at  timestamptz not null default now(),
  check (kind = 'section' or parent_id is null)
);
create index sections_unit_idx on public.sections (unit_id);
create trigger sections_touch before update on public.sections
  for each row execute function public.touch_updated_at();

alter table public.topics add column section_id text references public.sections (id) on delete set null;
create index topics_section_idx on public.topics (section_id);

-- Keeps the tree sound: a section's parent is a sub unit of the same
-- unit, and a topic's section is a section (not a sub unit) of its unit.
create function public.check_section_place() returns trigger
language plpgsql set search_path = public as $$
declare
  p sections%rowtype;
begin
  if new.parent_id is not null then
    select * into p from sections where id = new.parent_id;
    if p.kind <> 'subunit' or p.unit_id <> new.unit_id then
      raise exception 'A section can only be placed in a sub unit of the same unit' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;
create trigger sections_place before insert or update on public.sections
  for each row execute function public.check_section_place();

create function public.check_topic_section() returns trigger
language plpgsql set search_path = public as $$
declare
  s sections%rowtype;
begin
  if new.section_id is not null then
    select * into s from sections where id = new.section_id;
    if s.kind <> 'section' or s.unit_id <> new.unit_id then
      raise exception 'A topic can only be filed in a section of its own unit' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end $$;
create trigger topics_section before insert or update of section_id, unit_id on public.topics
  for each row execute function public.check_topic_section();

alter table public.sections enable row level security;
create policy "anyone reads sections" on public.sections
  for select to anon, authenticated using (true);
create policy "admins manage sections" on public.sections
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.sections to anon;
grant select, insert, update, delete on public.sections to authenticated;

-- ADMINS. Moves a section (with its topics and their questions) or a
-- whole sub unit (with its sections) to another unit and/or sub unit.
create function public.admin_move_section(section text, to_unit text, to_parent text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  s sections%rowtype;
  kids text[];
  filed jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admins only' using errcode = 'insufficient_privilege';
  end if;
  select * into s from sections where id = section;
  if not found then raise exception 'No such section'; end if;
  if not exists (select 1 from units where id = to_unit) then raise exception 'No such unit'; end if;

  if s.kind = 'subunit' then
    if to_parent is not null then
      raise exception 'A sub unit cannot be put inside another sub unit' using errcode = 'check_violation';
    end if;
    kids := array(select id from sections where parent_id = s.id);
  else
    kids := array[s.id];
  end if;
  -- Which topic is in which section, to put them back after the move.
  select coalesce(jsonb_object_agg(t.id, t.section_id), '{}'::jsonb) into filed
    from topics t where t.section_id = any(kids);

  update topics set section_id = null where id in (select jsonb_object_keys(filed));
  update sections set parent_id = null where id = any(kids);
  update sections set unit_id = to_unit where id = s.id or id = any(kids);
  if s.kind = 'subunit' then
    update sections set parent_id = s.id where id = any(kids);
  else
    update sections set parent_id = to_parent where id = s.id;
  end if;
  update topics t set unit_id = to_unit, section_id = filed ->> t.id
    where t.id in (select jsonb_object_keys(filed));
end $$;
revoke execute on function public.admin_move_section(text, text, text) from public, anon;
grant execute on function public.admin_move_section(text, text, text) to authenticated;

-- ----------------------------------------------- the bank as it stands
-- Every existing topic gets a section of its own name, so nothing is
-- left loose and the app keeps showing everything. Rearrange on the
-- admin site afterwards (rename sections, add topics, group sections
-- into sub units).
create function pg_temp.slug(t text) returns text language sql immutable as $$
  select trim(both '-' from regexp_replace(lower(t), '[^a-z0-9]+', '-', 'g'))
$$;

insert into public.sections (id, unit_id, kind, name, sort_order)
select t.unit_id || '-sec-' || pg_temp.slug(t.name), t.unit_id, 'section', t.name, t.sort_order
from public.topics t
where t.section_id is null and t.deleted_at is null
on conflict (id) do nothing;

update public.topics t set section_id = t.unit_id || '-sec-' || pg_temp.slug(t.name)
where t.section_id is null and t.deleted_at is null
  and exists (select 1 from public.sections s where s.id = t.unit_id || '-sec-' || pg_temp.slug(t.name));

-- The two starter Pathology topics, filed the way the app's own files do.
insert into public.sections (id, unit_id, kind, name, sort_order)
select v.id, 'pathology', 'subunit', v.name, v.n
from (values ('pathology-sub-anatomical-pathology', 'Anatomical pathology', 0), ('pathology-sub-haematology', 'Haematology', 1)) as v(id, name, n)
where exists (select 1 from public.units where id = 'pathology')
on conflict (id) do nothing;
insert into public.sections (id, unit_id, parent_id, kind, name)
select v.id, 'pathology', v.parent, 'section', v.name
from (values ('pathology-sec-blood-film', 'pathology-sub-haematology', 'Blood film'),
             ('pathology-sec-histopathology', 'pathology-sub-anatomical-pathology', 'Histopathology')) as v(id, parent, name)
where exists (select 1 from public.sections where id = v.parent)
on conflict (id) do nothing;
update public.topics set section_id = 'pathology-sec-blood-film'
  where id = 'path-haematology-spotters' and exists (select 1 from public.sections where id = 'pathology-sec-blood-film');
update public.topics set section_id = 'pathology-sec-histopathology'
  where id = 'path-histology-spotters' and exists (select 1 from public.sections where id = 'pathology-sec-histopathology');
-- Their first, same-name sections are now empty: remove them.
delete from public.sections s
  where s.id in ('pathology-sec-haematology-spotters', 'pathology-sec-histopathology-spotters')
    and not exists (select 1 from public.topics t where t.section_id = s.id);
