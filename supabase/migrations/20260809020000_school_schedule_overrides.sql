-- =========================================================
-- School day period schedule (defaults + today-only override)
--
-- Default bells (America/Toronto):
--   08:25–09:40, 09:43–10:58, 10:58–12:13, 12:13–13:28, 13:31–14:46
-- Day 1 labels: Period 1, Period 2, Lunch, Period 3, Period 4
-- Day 2 labels: Period 2, Period 1, Lunch, Period 4, Period 3
-- =========================================================

create table if not exists public.school_schedule_overrides (
  override_date date primary key,
  period_slots jsonb not null,
  created_by uuid not null
    references public.profiles(id)
    on delete restrict,
  updated_by uuid not null
    references public.profiles(id)
    on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint school_schedule_overrides_slots_is_array
    check (jsonb_typeof(period_slots) = 'array'),
  constraint school_schedule_overrides_slots_length
    check (jsonb_array_length(period_slots) = 5)
);

drop trigger if exists set_school_schedule_overrides_updated_at
on public.school_schedule_overrides;
create trigger set_school_schedule_overrides_updated_at
before update on public.school_schedule_overrides
for each row
execute function public.set_updated_at();

alter table public.school_schedule_overrides enable row level security;

revoke all on table public.school_schedule_overrides
from public, anon, authenticated;

grant select on table public.school_schedule_overrides to authenticated;

drop policy if exists "school_schedule_overrides_exec_select_today"
on public.school_schedule_overrides;

create policy "school_schedule_overrides_exec_select_today"
on public.school_schedule_overrides
for select
to authenticated
using (
  override_date = public.toronto_local_date()
  and (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  )
);

create or replace function public.default_school_period_slots()
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_array(
    jsonb_build_object('start', '08:25', 'end', '09:40'),
    jsonb_build_object('start', '09:43', 'end', '10:58'),
    jsonb_build_object('start', '10:58', 'end', '12:13'),
    jsonb_build_object('start', '12:13', 'end', '13:28'),
    jsonb_build_object('start', '13:31', 'end', '14:46')
  );
$$;

revoke all on function public.default_school_period_slots() from public;
grant execute on function public.default_school_period_slots()
to anon, authenticated;

create or replace function public.assert_school_period_slots(p_slots jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_item jsonb;
  v_start text;
  v_end text;
  v_start_minutes integer;
  v_end_minutes integer;
  v_prev_end integer := null;
  v_index integer := 0;
  v_normalized jsonb := '[]'::jsonb;
begin
  if p_slots is null or jsonb_typeof(p_slots) <> 'array' then
    raise exception 'Period schedule must be an array of 5 time blocks';
  end if;

  if jsonb_array_length(p_slots) <> 5 then
    raise exception 'Period schedule must include exactly 5 time blocks';
  end if;

  for v_item in select value from jsonb_array_elements(p_slots)
  loop
    v_start := nullif(btrim(coalesce(v_item ->> 'start', '')), '');
    v_end := nullif(btrim(coalesce(v_item ->> 'end', '')), '');

    if v_start is null or v_start !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise exception 'Invalid start time for schedule block %', v_index + 1;
    end if;

    if v_end is null or v_end !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
      raise exception 'Invalid end time for schedule block %', v_index + 1;
    end if;

    v_start_minutes :=
      (split_part(v_start, ':', 1)::integer * 60)
      + split_part(v_start, ':', 2)::integer;
    v_end_minutes :=
      (split_part(v_end, ':', 1)::integer * 60)
      + split_part(v_end, ':', 2)::integer;

    if v_end_minutes <= v_start_minutes then
      raise exception
        'End time must be after start time for schedule block %',
        v_index + 1;
    end if;

    if v_prev_end is not null and v_start_minutes < v_prev_end then
      raise exception
        'Schedule blocks must stay in chronological order (block %)',
        v_index + 1;
    end if;

    v_prev_end := v_end_minutes;
    v_normalized := v_normalized || jsonb_build_array(
      jsonb_build_object('start', v_start, 'end', v_end)
    );
    v_index := v_index + 1;
  end loop;

  return v_normalized;
end;
$$;

revoke all on function public.assert_school_period_slots(jsonb)
from public;
grant execute on function public.assert_school_period_slots(jsonb)
to authenticated;

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
  v_slots jsonb;
begin
  select *
  into v_override
  from public.school_day_overrides
  where override_date = v_today;

  select *
  into v_schedule
  from public.school_schedule_overrides
  where override_date = v_today;

  v_slots := coalesce(
    v_schedule.period_slots,
    public.default_school_period_slots()
  );

  return jsonb_build_object(
    'toronto_date', v_today,
    'automatic_day', v_automatic,
    'effective_day', coalesce(v_override.day_value, v_automatic),
    'override_active', v_override.override_date is not null,
    'override_day', v_override.day_value,
    'updated_by', case when v_can_see_audit then v_override.updated_by else null end,
    'updated_at', case when v_can_see_audit then v_override.updated_at else null end,
    'created_at', case when v_can_see_audit then v_override.created_at else null end,
    'period_slots', v_slots,
    'default_period_slots', public.default_school_period_slots(),
    'schedule_override_active', v_schedule.override_date is not null,
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

create or replace function public.set_school_schedule_override(p_slots jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_today date := public.toronto_local_date();
  v_slots jsonb;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.can_mutate_school_day() then
    raise exception
      'Only SAC administrators and SAC executives may override the school schedule'
      using errcode = '42501';
  end if;

  v_slots := public.assert_school_period_slots(p_slots);

  insert into public.school_schedule_overrides (
    override_date,
    period_slots,
    created_by,
    updated_by
  )
  values (
    v_today,
    v_slots,
    v_user_id,
    v_user_id
  )
  on conflict (override_date) do update
  set
    period_slots = excluded.period_slots,
    updated_by = excluded.updated_by,
    updated_at = now();

  return public.get_effective_school_day();
end;
$$;

revoke all on function public.set_school_schedule_override(jsonb)
from public, anon;
grant execute on function public.set_school_schedule_override(jsonb)
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
      'Only SAC administrators and SAC executives may clear the school schedule override'
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
