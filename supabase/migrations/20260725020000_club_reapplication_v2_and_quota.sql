-- =========================================================
-- Club re-application v2 + shared daily submission quota
-- Replaces the leader-centric reapplication model.
-- =========================================================

-- ---------------------------------------------------------
-- 0. Drop old reapplication RPCs (incompatible signatures)
-- ---------------------------------------------------------

drop function if exists public.submit_club_reapplication_request(
  uuid, uuid, text, text, text, text, text, text, text, text[], boolean, text, text
);
drop function if exists public.review_club_reapplication_request(uuid, text, text, uuid);

drop table if exists public.club_reapplication_attachments cascade;
drop table if exists public.club_reapplication_supervisors cascade;
drop table if exists public.club_reapplication_requests cascade;


-- ---------------------------------------------------------
-- 1. Shared daily quota ledger (Toronto calendar day)
-- ---------------------------------------------------------

create table public.club_application_submission_days (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null
    references public.profiles(id)
    on delete cascade,
  local_submission_date date not null,
  request_type text not null,
  request_id uuid not null,
  created_at timestamptz not null default now(),

  constraint club_app_submission_days_type_valid
    check (request_type in ('NEW_CLUB', 'REAPPLICATION')),

  constraint club_app_submission_days_user_date_unique
    unique (user_id, local_submission_date)
);

create index club_app_submission_days_request_idx
  on public.club_application_submission_days (request_id);

alter table public.club_application_submission_days enable row level security;

revoke all on table public.club_application_submission_days from public, anon;
grant select on table public.club_application_submission_days to authenticated;

drop policy if exists "club_app_submission_days_select_own"
on public.club_application_submission_days;
create policy "club_app_submission_days_select_own"
on public.club_application_submission_days
for select
to authenticated
using (
  user_id = (select auth.uid())
  or public.has_system_role('SAC_ADMIN')
);

create or replace function public.toronto_local_date(p_ts timestamptz default now())
returns date
language sql
immutable
set search_path = ''
as $$
  select (p_ts at time zone 'America/Toronto')::date;
$$;

revoke all on function public.toronto_local_date(timestamptz) from public;
grant execute on function public.toronto_local_date(timestamptz)
to authenticated;


-- ---------------------------------------------------------
-- 2. Re-application requests
-- ---------------------------------------------------------

create table public.club_reapplication_requests (
  id uuid primary key default gen_random_uuid(),

  club_id uuid not null
    references public.clubs(id)
    on delete restrict,

  school_year text not null,

  requested_by uuid not null
    references public.profiles(id)
    on delete cascade,

  applicant_email text not null,

  short_description text not null,
  description text not null,

  public_email text not null,
  instagram_handle text,

  meeting_frequency text not null,
  meeting_days text[] not null default '{}'::text[],
  meeting_time_details text,
  meeting_location text,

  proposed_logo_storage_path text,

  is_seeking_teacher_supervisor boolean not null default false,
  declaration_accepted boolean not null default false,

  status text not null default 'SUBMITTED',
  review_notes text,
  reviewed_by uuid
    references public.profiles(id)
    on delete set null,
  reviewed_at timestamptz,
  submitted_at timestamptz not null default now(),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_reapp_v2_school_year_not_blank
    check (length(btrim(school_year)) > 0),

  constraint club_reapp_v2_short_description_valid
    check (char_length(btrim(short_description)) between 10 and 500),

  constraint club_reapp_v2_description_valid
    check (char_length(btrim(description)) between 10 and 10000),

  constraint club_reapp_v2_public_email_lower
    check (public_email = lower(btrim(public_email))),

  constraint club_reapp_v2_meeting_frequency_valid
    check (
      meeting_frequency in (
        'Weekly',
        'Biweekly',
        'Monthly',
        'Event-Based',
        'Irregular',
        'Other'
      )
    ),

  constraint club_reapp_v2_meeting_days_valid
    check (
      meeting_days <@ array[
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday'
      ]::text[]
    ),

  constraint club_reapp_v2_meeting_days_required
    check (
      meeting_frequency not in ('Weekly', 'Biweekly')
      or cardinality(meeting_days) >= 1
    ),

  constraint club_reapp_v2_declaration_required
    check (declaration_accepted = true),

  constraint club_reapp_v2_status_valid
    check (
      status in (
        'SUBMITTED',
        'UNDER_REVIEW',
        'CHANGES_REQUESTED',
        'APPROVED',
        'REJECTED'
      )
    )
);

-- Blocking duplicate re-applications for the same club/year
create unique index club_reapp_v2_blocking_club_year_uidx
on public.club_reapplication_requests (club_id, school_year)
where status in (
  'SUBMITTED',
  'UNDER_REVIEW',
  'CHANGES_REQUESTED',
  'APPROVED'
);

create index club_reapp_v2_requested_by_idx
  on public.club_reapplication_requests (requested_by);

create index club_reapp_v2_status_idx
  on public.club_reapplication_requests (status, submitted_at desc);

create index club_reapp_v2_school_year_idx
  on public.club_reapplication_requests (school_year);

drop trigger if exists set_club_reapplication_requests_updated_at
on public.club_reapplication_requests;
create trigger set_club_reapplication_requests_updated_at
before update on public.club_reapplication_requests
for each row
execute function public.set_updated_at();


create table public.club_reapplication_supervisors (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null
    references public.club_reapplication_requests(id)
    on delete cascade,
  supervisor_name text not null,
  supervisor_email text not null,
  created_at timestamptz not null default now(),

  constraint club_reapp_sup_name_valid
    check (
      supervisor_name = btrim(supervisor_name)
      and char_length(supervisor_name) between 2 and 120
    ),

  constraint club_reapp_sup_email_pdsb
    check (
      supervisor_email = lower(btrim(supervisor_email))
      and supervisor_email ~ '^[^[:space:]@]+@pdsb[.]net$'
    )
);

create index club_reapp_sup_request_idx
  on public.club_reapplication_supervisors (request_id);


create table public.club_reapplication_attachments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null
    references public.club_reapplication_requests(id)
    on delete cascade,
  storage_path text not null,
  original_filename text not null,
  mime_type text not null,
  size_bytes bigint not null,
  uploaded_by uuid not null
    references public.profiles(id)
    on delete cascade,
  created_at timestamptz not null default now(),

  constraint club_reapp_att_path_not_blank
    check (length(btrim(storage_path)) > 0),

  constraint club_reapp_att_mime_valid
    check (
      mime_type in (
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf'
      )
    ),

  constraint club_reapp_att_size_valid
    check (size_bytes > 0 and size_bytes <= 10485760)
);

create index club_reapp_att_request_idx
  on public.club_reapplication_attachments (request_id);


-- ---------------------------------------------------------
-- 3. RLS
-- ---------------------------------------------------------

alter table public.club_reapplication_requests enable row level security;
alter table public.club_reapplication_supervisors enable row level security;
alter table public.club_reapplication_attachments enable row level security;

revoke all on table public.club_reapplication_requests from public, anon;
revoke all on table public.club_reapplication_supervisors from public, anon;
revoke all on table public.club_reapplication_attachments from public, anon;

grant select on table public.club_reapplication_requests to authenticated;
grant select on table public.club_reapplication_supervisors to authenticated;
grant select on table public.club_reapplication_attachments to authenticated;

-- Direct inserts/updates go through SECURITY DEFINER RPCs only.
-- Keep grants minimal; no INSERT/UPDATE for students on parent table.

create policy "club_reapp_v2_select_own"
on public.club_reapplication_requests
for select
to authenticated
using (requested_by = (select auth.uid()));

create policy "club_reapp_v2_select_sac"
on public.club_reapplication_requests
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);

create policy "club_reapp_sup_select_own"
on public.club_reapplication_supervisors
for select
to authenticated
using (
  exists (
    select 1
    from public.club_reapplication_requests r
    where r.id = request_id
      and r.requested_by = (select auth.uid())
  )
);

create policy "club_reapp_sup_select_sac"
on public.club_reapplication_supervisors
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);

create policy "club_reapp_att_select_own"
on public.club_reapplication_attachments
for select
to authenticated
using (
  exists (
    select 1
    from public.club_reapplication_requests r
    where r.id = request_id
      and r.requested_by = (select auth.uid())
  )
);

create policy "club_reapp_att_select_sac"
on public.club_reapplication_attachments
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);


-- ---------------------------------------------------------
-- 4. list_eligible_clubs_for_reapplication
-- ---------------------------------------------------------

create or replace function public.list_eligible_clubs_for_reapplication(
  p_search text default null
)
returns table (
  id uuid,
  name text,
  aliases text[],
  historical_description text,
  historical_meeting_schedule text,
  historical_meeting_location text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_year text;
  v_q text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();
  v_q := nullif(lower(btrim(coalesce(p_search, ''))), '');

  return query
  select
    c.id,
    c.name,
    coalesce(
      (
        select array_agg(a.alias order by a.alias)
        from public.club_aliases a
        where a.club_id = c.id
      ),
      '{}'::text[]
    ) as aliases,
    c.description as historical_description,
    c.meeting_schedule as historical_meeting_schedule,
    c.meeting_location as historical_meeting_location
  from public.clubs c
  join public.club_school_years csy
    on csy.club_id = c.id
   and csy.school_year = v_year
  where c.eligible_for_reapplication = true
    and csy.status = 'INACTIVE'
    and not exists (
      select 1
      from public.club_reapplication_requests r
      where r.club_id = c.id
        and r.school_year = v_year
        and r.status in (
          'SUBMITTED',
          'UNDER_REVIEW',
          'CHANGES_REQUESTED',
          'APPROVED'
        )
    )
    and (
      v_q is null
      or lower(c.name) like '%' || v_q || '%'
      or exists (
        select 1
        from public.club_aliases a
        where a.club_id = c.id
          and lower(a.alias) like '%' || v_q || '%'
      )
      or exists (
        select 1
        from unnest(c.source_names) as sn
        where lower(sn) like '%' || v_q || '%'
      )
    )
  order by c.name;
end;
$$;

revoke all on function public.list_eligible_clubs_for_reapplication(text)
from public, anon;
grant execute on function public.list_eligible_clubs_for_reapplication(text)
to authenticated;


-- ---------------------------------------------------------
-- 5. submit_club_reapplication
-- ---------------------------------------------------------

create or replace function public.submit_club_reapplication(
  p_request_id uuid,
  p_club_id uuid,
  p_short_description text,
  p_description text,
  p_public_email text,
  p_instagram_handle text,
  p_meeting_frequency text,
  p_meeting_days text[],
  p_meeting_time_details text,
  p_meeting_location text,
  p_proposed_logo_storage_path text,
  p_is_seeking_teacher_supervisor boolean,
  p_declaration_accepted boolean,
  p_supervisors jsonb default '[]'::jsonb,
  p_attachments jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_email text;
  v_year text;
  v_request_id uuid;
  v_club public.clubs%rowtype;
  v_annual public.club_school_years%rowtype;
  v_days text[];
  v_sup jsonb;
  v_att jsonb;
  v_sup_count int;
  v_today date;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_request_id is null then
    raise exception 'Request ID is required';
  end if;

  v_request_id := p_request_id;

  if coalesce(p_declaration_accepted, false) is not true then
    raise exception 'Declaration must be accepted';
  end if;

  select lower(btrim(email)) into v_email
  from public.profiles
  where id = v_user_id;

  if v_email is null then
    raise exception 'Profile email is required';
  end if;

  v_year := public.get_current_club_school_year();
  v_today := public.toronto_local_date(now());

  select * into v_club
  from public.clubs
  where id = p_club_id
  for update;

  if not found then
    raise exception 'Club not found';
  end if;

  if v_club.eligible_for_reapplication is not true then
    raise exception 'This club is not eligible for re-application';
  end if;

  select * into v_annual
  from public.club_school_years
  where club_id = p_club_id
    and school_year = v_year
  for update;

  if not found or v_annual.status <> 'INACTIVE' then
    raise exception
      'This club is not currently available for re-application';
  end if;

  if exists (
    select 1
    from public.club_reapplication_requests r
    where r.club_id = p_club_id
      and r.school_year = v_year
      and r.status in (
        'SUBMITTED',
        'UNDER_REVIEW',
        'CHANGES_REQUESTED',
        'APPROVED'
      )
  ) then
    raise exception
      'A re-application for this club is already in progress'
      using errcode = '23505';
  end if;

  if exists (
    select 1
    from public.club_application_submission_days d
    where d.user_id = v_user_id
      and d.local_submission_date = v_today
  ) then
    raise exception
      'You may submit only one club application per calendar day (America/Toronto)';
  end if;

  v_days := coalesce(
    (
      select array_agg(distinct d order by d)
      from unnest(coalesce(p_meeting_days, '{}'::text[])) as d
      where d in ('Monday','Tuesday','Wednesday','Thursday','Friday')
    ),
    '{}'::text[]
  );

  if p_meeting_frequency in ('Weekly', 'Biweekly')
     and cardinality(v_days) < 1 then
    raise exception 'At least one meeting day is required for Weekly/Biweekly';
  end if;

  if nullif(lower(btrim(p_public_email)), '') is null
     or lower(btrim(p_public_email)) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'A valid public club email is required';
  end if;

  if p_proposed_logo_storage_path is not null
     and btrim(p_proposed_logo_storage_path) <> ''
     and btrim(p_proposed_logo_storage_path)
         not like ('reapplication-logos/' || v_user_id::text || '/%') then
    raise exception 'Invalid logo storage path' using errcode = '42501';
  end if;

  v_sup := coalesce(p_supervisors, '[]'::jsonb);
  if jsonb_typeof(v_sup) <> 'array' then
    raise exception 'Supervisors must be an array';
  end if;
  v_sup_count := jsonb_array_length(v_sup);

  if coalesce(p_is_seeking_teacher_supervisor, false) then
    if v_sup_count > 3 then
      raise exception 'At most three supervisors are allowed';
    end if;
  else
    if v_sup_count < 1 or v_sup_count > 3 then
      raise exception 'Provide one to three teacher supervisors, or mark that you are still searching';
    end if;
  end if;

  insert into public.club_reapplication_requests (
    id,
    club_id,
    school_year,
    requested_by,
    applicant_email,
    short_description,
    description,
    public_email,
    instagram_handle,
    meeting_frequency,
    meeting_days,
    meeting_time_details,
    meeting_location,
    proposed_logo_storage_path,
    is_seeking_teacher_supervisor,
    declaration_accepted,
    status,
    submitted_at
  )
  values (
    v_request_id,
    p_club_id,
    v_year,
    v_user_id,
    v_email,
    btrim(p_short_description),
    btrim(p_description),
    lower(btrim(p_public_email)),
    nullif(btrim(coalesce(p_instagram_handle, '')), ''),
    p_meeting_frequency,
    v_days,
    nullif(btrim(coalesce(p_meeting_time_details, '')), ''),
    nullif(btrim(coalesce(p_meeting_location, '')), ''),
    nullif(btrim(coalesce(p_proposed_logo_storage_path, '')), ''),
    coalesce(p_is_seeking_teacher_supervisor, false),
    true,
    'SUBMITTED',
    now()
  );

  insert into public.club_reapplication_supervisors (
    request_id, supervisor_name, supervisor_email
  )
  select
    v_request_id,
    btrim(s->>'name'),
    lower(btrim(s->>'email'))
  from jsonb_array_elements(v_sup) as s
  where nullif(btrim(coalesce(s->>'name', '')), '') is not null
    and nullif(btrim(coalesce(s->>'email', '')), '') is not null;

  if not coalesce(p_is_seeking_teacher_supervisor, false)
     and not exists (
       select 1 from public.club_reapplication_supervisors
       where request_id = v_request_id
     ) then
    raise exception 'At least one complete supervisor entry is required';
  end if;

  v_att := coalesce(p_attachments, '[]'::jsonb);
  if jsonb_typeof(v_att) = 'array' and jsonb_array_length(v_att) > 0 then
    insert into public.club_reapplication_attachments (
      request_id,
      storage_path,
      original_filename,
      mime_type,
      size_bytes,
      uploaded_by
    )
    select
      v_request_id,
      btrim(a->>'storage_path'),
      btrim(a->>'original_filename'),
      btrim(a->>'mime_type'),
      (a->>'size_bytes')::bigint,
      v_user_id
    from jsonb_array_elements(v_att) as a
    where btrim(coalesce(a->>'storage_path', ''))
          like ('reapplications/' || v_user_id::text || '/' || v_request_id::text || '/%')
       or btrim(coalesce(a->>'storage_path', ''))
          like ('reapplications/' || v_user_id::text || '/%');
  end if;

  insert into public.club_application_submission_days (
    user_id,
    local_submission_date,
    request_type,
    request_id
  )
  values (
    v_user_id,
    v_today,
    'REAPPLICATION',
    v_request_id
  );

  return v_request_id;
exception
  when unique_violation then
    raise exception
      'A re-application for this club is already in progress, or your daily application quota is used'
      using errcode = '23505';
end;
$$;

revoke all on function public.submit_club_reapplication(
  uuid, uuid, text, text, text, text, text, text[], text, text, text, boolean, boolean, jsonb, jsonb
) from public, anon;
grant execute on function public.submit_club_reapplication(
  uuid, uuid, text, text, text, text, text, text[], text, text, text, boolean, boolean, jsonb, jsonb
) to authenticated;


-- ---------------------------------------------------------
-- 6. update + resubmit (CHANGES_REQUESTED only)
-- ---------------------------------------------------------

create or replace function public.update_club_reapplication(
  p_request_id uuid,
  p_short_description text,
  p_description text,
  p_public_email text,
  p_instagram_handle text,
  p_meeting_frequency text,
  p_meeting_days text[],
  p_meeting_time_details text,
  p_meeting_location text,
  p_proposed_logo_storage_path text,
  p_is_seeking_teacher_supervisor boolean,
  p_declaration_accepted boolean,
  p_supervisors jsonb default '[]'::jsonb,
  p_attachments jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_req public.club_reapplication_requests%rowtype;
  v_days text[];
  v_sup jsonb;
  v_sup_count int;
  v_logo text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_req
  from public.club_reapplication_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_req.requested_by <> v_user_id then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  if v_req.status <> 'CHANGES_REQUESTED' then
    raise exception 'Only CHANGES_REQUESTED requests can be edited';
  end if;

  if coalesce(p_declaration_accepted, false) is not true then
    raise exception 'Declaration must be accepted';
  end if;

  v_days := coalesce(
    (
      select array_agg(distinct d order by d)
      from unnest(coalesce(p_meeting_days, '{}'::text[])) as d
      where d in ('Monday','Tuesday','Wednesday','Thursday','Friday')
    ),
    '{}'::text[]
  );

  if p_meeting_frequency in ('Weekly', 'Biweekly')
     and cardinality(v_days) < 1 then
    raise exception 'At least one meeting day is required for Weekly/Biweekly';
  end if;

  v_sup := coalesce(p_supervisors, '[]'::jsonb);
  v_sup_count := jsonb_array_length(v_sup);

  if coalesce(p_is_seeking_teacher_supervisor, false) then
    if v_sup_count > 3 then
      raise exception 'At most three supervisors are allowed';
    end if;
  else
    if v_sup_count < 1 or v_sup_count > 3 then
      raise exception 'Provide one to three teacher supervisors, or mark that you are still searching';
    end if;
  end if;

  v_logo := nullif(btrim(coalesce(p_proposed_logo_storage_path, '')), '');
  if v_logo is null then
    v_logo := v_req.proposed_logo_storage_path;
  elsif v_logo not like ('reapplication-logos/' || v_user_id::text || '/%') then
    raise exception 'Invalid logo storage path' using errcode = '42501';
  end if;

  update public.club_reapplication_requests
  set
    short_description = btrim(p_short_description),
    description = btrim(p_description),
    public_email = lower(btrim(p_public_email)),
    instagram_handle = nullif(btrim(coalesce(p_instagram_handle, '')), ''),
    meeting_frequency = p_meeting_frequency,
    meeting_days = v_days,
    meeting_time_details = nullif(btrim(coalesce(p_meeting_time_details, '')), ''),
    meeting_location = nullif(btrim(coalesce(p_meeting_location, '')), ''),
    proposed_logo_storage_path = v_logo,
    is_seeking_teacher_supervisor = coalesce(p_is_seeking_teacher_supervisor, false),
    declaration_accepted = true
  where id = p_request_id;

  delete from public.club_reapplication_supervisors
  where request_id = p_request_id;

  insert into public.club_reapplication_supervisors (
    request_id, supervisor_name, supervisor_email
  )
  select
    p_request_id,
    btrim(s->>'name'),
    lower(btrim(s->>'email'))
  from jsonb_array_elements(v_sup) as s
  where nullif(btrim(coalesce(s->>'name', '')), '') is not null
    and nullif(btrim(coalesce(s->>'email', '')), '') is not null;

  if p_attachments is not null and jsonb_typeof(p_attachments) = 'array' then
    delete from public.club_reapplication_attachments
    where request_id = p_request_id;

    insert into public.club_reapplication_attachments (
      request_id,
      storage_path,
      original_filename,
      mime_type,
      size_bytes,
      uploaded_by
    )
    select
      p_request_id,
      btrim(a->>'storage_path'),
      btrim(a->>'original_filename'),
      btrim(a->>'mime_type'),
      (a->>'size_bytes')::bigint,
      v_user_id
    from jsonb_array_elements(p_attachments) as a
    where nullif(btrim(coalesce(a->>'storage_path', '')), '') is not null;
  end if;

  return p_request_id;
end;
$$;

revoke all on function public.update_club_reapplication(
  uuid, text, text, text, text, text, text[], text, text, text, boolean, boolean, jsonb, jsonb
) from public, anon;
grant execute on function public.update_club_reapplication(
  uuid, text, text, text, text, text, text[], text, text, text, boolean, boolean, jsonb, jsonb
) to authenticated;


create or replace function public.resubmit_club_reapplication(
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_req public.club_reapplication_requests%rowtype;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_req
  from public.club_reapplication_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_req.requested_by <> v_user_id then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  if v_req.status <> 'CHANGES_REQUESTED' then
    raise exception 'Only CHANGES_REQUESTED requests can be resubmitted';
  end if;

  update public.club_reapplication_requests
  set
    status = 'SUBMITTED',
    submitted_at = now(),
    review_notes = null,
    reviewed_by = null,
    reviewed_at = null
  where id = p_request_id;

  -- Resubmission does not consume another daily quota.
  return p_request_id;
end;
$$;

revoke all on function public.resubmit_club_reapplication(uuid)
from public, anon;
grant execute on function public.resubmit_club_reapplication(uuid)
to authenticated;
