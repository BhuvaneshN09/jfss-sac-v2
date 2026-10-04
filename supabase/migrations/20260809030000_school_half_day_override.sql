-- =========================================================
-- Simplify schedule override to half-day only (today)
-- Row present for Toronto today => half-day bell schedule
-- =========================================================

alter table public.school_schedule_overrides
  drop constraint if exists school_schedule_overrides_slots_length;

alter table public.school_schedule_overrides
  drop constraint if exists school_schedule_overrides_slots_is_array;

alter table public.school_schedule_overrides
  alter column period_slots drop not null;

-- Existing custom slot rows become half-day markers.
update public.school_schedule_overrides
set period_slots = null
where period_slots is not null;

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
  v_schedule public.school_schedule_overrides%rowtype;
  v_can_see_audit boolean := public.can_mutate_school_day();
  v_is_half_day boolean;
begin
  select *
  into v_override
  from public.school_day_overrides
  where override_date = v_today;

  select *
  into v_schedule
  from public.school_schedule_overrides
  where override_date = v_today;

  v_is_half_day := v_schedule.override_date is not null;

  return jsonb_build_object(
    'toronto_date', v_today,
    'automatic_day', v_automatic,
    'effective_day', coalesce(v_override.day_value, v_automatic),
    'override_active', v_override.override_date is not null,
    'override_day', v_override.day_value,
    'updated_by', case when v_can_see_audit then v_override.updated_by else null end,
    'updated_at', case when v_can_see_audit then v_override.updated_at else null end,
    'created_at', case when v_can_see_audit then v_override.created_at else null end,
    'is_half_day', v_is_half_day,
    'schedule_override_active', v_is_half_day,
    'schedule_updated_by',
      case when v_can_see_audit then v_schedule.updated_by else null end,
    'schedule_updated_at',
      case when v_can_see_audit then v_schedule.updated_at else null end
  );
end;
$$;

revoke all on function public.get_effective_school_day()
from public;
grant execute on function public.get_effective_school_day()
to anon, authenticated;

create or replace function public.set_half_day_override()
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
      'Only SAC administrators and SAC executives may set a half-day schedule'
      using errcode = '42501';
  end if;

  insert into public.school_schedule_overrides (
    override_date,
    period_slots,
    created_by,
    updated_by
  )
  values (
    v_today,
    null,
    v_user_id,
    v_user_id
  )
  on conflict (override_date) do update
  set
    period_slots = null,
    updated_by = excluded.updated_by,
    updated_at = now();

  return public.get_effective_school_day();
end;
$$;

revoke all on function public.set_half_day_override()
from public, anon;
grant execute on function public.set_half_day_override()
to authenticated;

create or replace function public.clear_school_schedule_override()
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
      'Only SAC administrators and SAC executives may clear the half-day schedule'
      using errcode = '42501';
  end if;

  delete from public.school_schedule_overrides
  where override_date = v_today;

  return public.get_effective_school_day();
end;
$$;

revoke all on function public.clear_school_schedule_override()
from public, anon;
grant execute on function public.clear_school_schedule_override()
to authenticated;

-- Keep old slot RPC name as an alias so older clients do not hard-fail;
-- it now always applies the fixed half-day schedule.
create or replace function public.set_school_schedule_override(p_slots jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- p_slots ignored: only half-day mode is supported.
  return public.set_half_day_override();
end;
$$;

revoke all on function public.set_school_schedule_override(jsonb)
from public, anon;
grant execute on function public.set_school_schedule_override(jsonb)
to authenticated;
