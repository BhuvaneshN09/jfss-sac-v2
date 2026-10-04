-- =========================================================
-- School day Day 1 / Day 2 overrides (Toronto calendar date)
--
-- Automatic rule: odd day-of-month → DAY_1, even → DAY_2
-- Manual override: SAC_ADMIN or SAC_EXEC may set/clear for *today only*
-- =========================================================

create table if not exists public.school_day_overrides (
  override_date date primary key,
  day_value text not null,
  created_by uuid not null
    references public.profiles(id)
    on delete restrict,
  updated_by uuid not null
    references public.profiles(id)
    on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint school_day_overrides_day_value_valid
    check (day_value in ('DAY_1', 'DAY_2'))
);

drop trigger if exists set_school_day_overrides_updated_at
on public.school_day_overrides;
create trigger set_school_day_overrides_updated_at
before update on public.school_day_overrides
for each row
execute function public.set_updated_at();

alter table public.school_day_overrides enable row level security;

revoke all on table public.school_day_overrides from public, anon, authenticated;

-- No direct table grants for writes. SELECT is limited to today's row for
-- SAC_ADMIN / SAC_EXEC so the dashboard can read audit fields if needed.
grant select on table public.school_day_overrides to authenticated;

drop policy if exists "school_day_overrides_exec_select_today"
on public.school_day_overrides;

create policy "school_day_overrides_exec_select_today"
on public.school_day_overrides
for select
to authenticated
using (
  override_date = public.toronto_local_date()
  and (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  )
);

create or replace function public.can_mutate_school_day()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC');
$$;

revoke all on function public.can_mutate_school_day() from public, anon;
grant execute on function public.can_mutate_school_day() to authenticated;

create or replace function public.automatic_school_day(p_date date)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when extract(day from p_date)::integer % 2 = 1 then 'DAY_1'
    else 'DAY_2'
  end;
$$;

revoke all on function public.automatic_school_day(date) from public;
grant execute on function public.automatic_school_day(date)
to anon, authenticated;

create or replace function public.get_effective_school_day()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := public.toronto_local_date();
  v_automatic text := public.automatic_school_day(v_today);
  v_override public.school_day_overrides%rowtype;
  v_can_see_audit boolean := public.can_mutate_school_day();
begin
  select *
  into v_override
  from public.school_day_overrides
  where override_date = v_today;

  return jsonb_build_object(
    'toronto_date', v_today,
    'automatic_day', v_automatic,
    'effective_day', coalesce(v_override.day_value, v_automatic),
    'override_active', v_override.override_date is not null,
    'override_day', v_override.day_value,
    'updated_by', case when v_can_see_audit then v_override.updated_by else null end,
    'updated_at', case when v_can_see_audit then v_override.updated_at else null end,
    'created_at', case when v_can_see_audit then v_override.created_at else null end
  );
end;
$$;

revoke all on function public.get_effective_school_day()
from public;
grant execute on function public.get_effective_school_day()
to anon, authenticated;

create or replace function public.set_school_day_override(p_day text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_today date := public.toronto_local_date();
  v_day text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.can_mutate_school_day() then
    raise exception
      'Only SAC administrators and SAC executives may override the school day'
      using errcode = '42501';
  end if;

  v_day := upper(btrim(coalesce(p_day, '')));
  if v_day not in ('DAY_1', 'DAY_2') then
    raise exception 'Day value must be DAY_1 or DAY_2';
  end if;

  insert into public.school_day_overrides (
    override_date,
    day_value,
    created_by,
    updated_by
  )
  values (
    v_today,
    v_day,
    v_user_id,
    v_user_id
  )
  on conflict (override_date) do update
  set
    day_value = excluded.day_value,
    updated_by = excluded.updated_by,
    updated_at = now();

  return public.get_effective_school_day();
end;
$$;

revoke all on function public.set_school_day_override(text)
from public, anon;
grant execute on function public.set_school_day_override(text)
to authenticated;

create or replace function public.clear_school_day_override()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_today date := public.toronto_local_date();
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.can_mutate_school_day() then
    raise exception
      'Only SAC administrators and SAC executives may clear the school day override'
      using errcode = '42501';
  end if;

  delete from public.school_day_overrides
  where override_date = v_today;

  return public.get_effective_school_day();
end;
$$;

revoke all on function public.clear_school_day_override()
from public, anon;
grant execute on function public.clear_school_day_override()
to authenticated;
