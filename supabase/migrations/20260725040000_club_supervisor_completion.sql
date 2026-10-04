-- =========================================================
-- Supervisor completion workflow + club_advisors
-- =========================================================

create table if not exists public.club_advisors (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null
    references public.clubs(id)
    on delete cascade,
  school_year text not null,
  supervisor_name text not null,
  supervisor_email text not null,
  status text not null default 'ACTIVE',
  approved_from_request_id uuid,
  approved_by uuid
    references public.profiles(id)
    on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_advisors_name_valid
    check (
      supervisor_name = btrim(supervisor_name)
      and char_length(supervisor_name) between 2 and 120
    ),

  constraint club_advisors_email_pdsb
    check (
      supervisor_email = lower(btrim(supervisor_email))
      and supervisor_email ~ '^[^[:space:]@]+@pdsb[.]net$'
    ),

  constraint club_advisors_status_valid
    check (status in ('ACTIVE', 'INACTIVE'))
);

create unique index if not exists club_advisors_active_email_uidx
  on public.club_advisors (club_id, school_year, supervisor_email)
  where status = 'ACTIVE';

create index if not exists club_advisors_club_year_idx
  on public.club_advisors (club_id, school_year);

drop trigger if exists set_club_advisors_updated_at on public.club_advisors;
create trigger set_club_advisors_updated_at
before update on public.club_advisors
for each row
execute function public.set_updated_at();

alter table public.club_advisors enable row level security;

revoke all on table public.club_advisors from public, anon;
grant select on table public.club_advisors to authenticated;

drop policy if exists "club_advisors_select_members" on public.club_advisors;
create policy "club_advisors_select_members"
on public.club_advisors
for select
to authenticated
using (
  public.has_club_role(club_id, array['OWNER', 'EXEC', 'MEMBER'])
  or public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);


create table if not exists public.club_supervisor_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null
    references public.clubs(id)
    on delete cascade,
  school_year text not null,
  submitted_by uuid not null
    references public.profiles(id)
    on delete cascade,
  status text not null default 'SUBMITTED',
  review_notes text,
  reviewed_by uuid
    references public.profiles(id)
    on delete set null,
  reviewed_at timestamptz,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_sup_req_status_valid
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

create index if not exists club_sup_req_club_year_idx
  on public.club_supervisor_requests (club_id, school_year, status);

create index if not exists club_sup_req_submitted_by_idx
  on public.club_supervisor_requests (submitted_by);

drop trigger if exists set_club_supervisor_requests_updated_at
on public.club_supervisor_requests;
create trigger set_club_supervisor_requests_updated_at
before update on public.club_supervisor_requests
for each row
execute function public.set_updated_at();

alter table public.club_supervisor_requests enable row level security;

revoke all on table public.club_supervisor_requests from public, anon;
grant select on table public.club_supervisor_requests to authenticated;

create policy "club_sup_req_select_owners"
on public.club_supervisor_requests
for select
to authenticated
using (
  public.has_club_role(club_id, array['OWNER'])
  or public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SAC_EXEC')
);


create table if not exists public.club_supervisor_request_supervisors (
  id uuid primary key default gen_random_uuid(),
  supervisor_request_id uuid not null
    references public.club_supervisor_requests(id)
    on delete cascade,
  supervisor_name text not null,
  supervisor_email text not null,
  created_at timestamptz not null default now(),

  constraint club_sup_req_sup_name_valid
    check (
      supervisor_name = btrim(supervisor_name)
      and char_length(supervisor_name) between 2 and 120
    ),

  constraint club_sup_req_sup_email_pdsb
    check (
      supervisor_email = lower(btrim(supervisor_email))
      and supervisor_email ~ '^[^[:space:]@]+@pdsb[.]net$'
    )
);

create index if not exists club_sup_req_sup_parent_idx
  on public.club_supervisor_request_supervisors (supervisor_request_id);

alter table public.club_supervisor_request_supervisors enable row level security;
revoke all on table public.club_supervisor_request_supervisors from public, anon;
grant select on table public.club_supervisor_request_supervisors to authenticated;

create policy "club_sup_req_sup_select"
on public.club_supervisor_request_supervisors
for select
to authenticated
using (
  exists (
    select 1
    from public.club_supervisor_requests r
    where r.id = supervisor_request_id
      and (
        public.has_club_role(r.club_id, array['OWNER'])
        or public.has_system_role('SAC_ADMIN')
        or public.has_system_role('SAC_EXEC')
      )
  )
);


create table if not exists public.club_supervisor_request_attachments (
  id uuid primary key default gen_random_uuid(),
  supervisor_request_id uuid not null
    references public.club_supervisor_requests(id)
    on delete cascade,
  storage_path text not null,
  original_filename text not null,
  mime_type text not null,
  size_bytes bigint not null,
  uploaded_by uuid not null
    references public.profiles(id)
    on delete cascade,
  created_at timestamptz not null default now(),

  constraint club_sup_req_att_mime_valid
    check (
      mime_type in (
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf'
      )
    ),

  constraint club_sup_req_att_size_valid
    check (size_bytes > 0 and size_bytes <= 10485760)
);

create index if not exists club_sup_req_att_parent_idx
  on public.club_supervisor_request_attachments (supervisor_request_id);

alter table public.club_supervisor_request_attachments enable row level security;
revoke all on table public.club_supervisor_request_attachments from public, anon;
grant select on table public.club_supervisor_request_attachments to authenticated;

create policy "club_sup_req_att_select"
on public.club_supervisor_request_attachments
for select
to authenticated
using (
  exists (
    select 1
    from public.club_supervisor_requests r
    where r.id = supervisor_request_id
      and (
        public.has_club_role(r.club_id, array['OWNER'])
        or public.has_system_role('SAC_ADMIN')
        or public.has_system_role('SAC_EXEC')
      )
  )
);

-- Link advisors to supervisor requests when approved from that flow
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'club_advisors_from_request_fk'
  ) then
    alter table public.club_advisors
      add constraint club_advisors_from_request_fk
      foreign key (approved_from_request_id)
      references public.club_supervisor_requests(id)
      on delete set null;
  end if;
end $$;


-- ---------------------------------------------------------
-- submit_club_supervisor_request
-- ---------------------------------------------------------

create or replace function public.submit_club_supervisor_request(
  p_request_id uuid,
  p_club_id uuid,
  p_supervisors jsonb,
  p_attachments jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_year text;
  v_annual_status text;
  v_sup jsonb;
  v_count int;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_request_id is null or p_club_id is null then
    raise exception 'Request ID and club ID are required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception 'Only active club OWNERs may submit supervisor information'
      using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();
  v_annual_status := public.get_club_current_annual_status(p_club_id);

  if v_annual_status is distinct from 'PENDING_SUPERVISOR'
     and v_annual_status is distinct from 'ACTIVE' then
    raise exception 'Supervisor submissions are only allowed for pending or active clubs';
  end if;

  v_sup := coalesce(p_supervisors, '[]'::jsonb);
  if jsonb_typeof(v_sup) <> 'array' then
    raise exception 'Supervisors must be an array';
  end if;
  v_count := jsonb_array_length(v_sup);
  if v_count < 1 or v_count > 3 then
    raise exception 'Provide one to three supervisors';
  end if;

  insert into public.club_supervisor_requests (
    id, club_id, school_year, submitted_by, status, submitted_at
  )
  values (
    p_request_id, p_club_id, v_year, v_user_id, 'SUBMITTED', now()
  );

  insert into public.club_supervisor_request_supervisors (
    supervisor_request_id, supervisor_name, supervisor_email
  )
  select
    p_request_id,
    btrim(s->>'name'),
    lower(btrim(s->>'email'))
  from jsonb_array_elements(v_sup) as s;

  if p_attachments is not null
     and jsonb_typeof(p_attachments) = 'array'
     and jsonb_array_length(p_attachments) > 0 then
    insert into public.club_supervisor_request_attachments (
      supervisor_request_id,
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
    where btrim(coalesce(a->>'storage_path', ''))
          like ('supervisor-requests/' || v_user_id::text || '/%');
  end if;

  return p_request_id;
end;
$$;

revoke all on function public.submit_club_supervisor_request(uuid, uuid, jsonb, jsonb)
from public, anon;
grant execute on function public.submit_club_supervisor_request(uuid, uuid, jsonb, jsonb)
to authenticated;


-- ---------------------------------------------------------
-- review_club_supervisor_request
-- ---------------------------------------------------------

create or replace function public.review_club_supervisor_request(
  p_request_id uuid,
  p_action text,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_req public.club_supervisor_requests%rowtype;
  v_action text;
  v_notes text;
  v_year text;
  v_active_count int;
  v_now timestamptz := now();
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));
  v_notes := nullif(btrim(coalesce(p_review_notes, '')), '');
  v_year := public.get_current_club_school_year();

  select * into v_req
  from public.club_supervisor_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Supervisor request not found';
  end if;

  if v_action = 'UNDER_REVIEW' then
    update public.club_supervisor_requests
    set status = 'UNDER_REVIEW',
        reviewed_by = v_user_id,
        reviewed_at = v_now,
        review_notes = coalesce(v_notes, review_notes)
    where id = p_request_id;

  elsif v_action = 'CHANGES_REQUESTED' then
    if v_notes is null then
      raise exception 'Review notes are required when requesting changes';
    end if;
    update public.club_supervisor_requests
    set status = 'CHANGES_REQUESTED',
        review_notes = v_notes,
        reviewed_by = v_user_id,
        reviewed_at = v_now
    where id = p_request_id;

  elsif v_action = 'REJECTED' then
    if v_notes is null then
      raise exception 'Review notes are required when rejecting';
    end if;
    update public.club_supervisor_requests
    set status = 'REJECTED',
        review_notes = v_notes,
        reviewed_by = v_user_id,
        reviewed_at = v_now
    where id = p_request_id;

  elsif v_action = 'APPROVED' then
    update public.club_supervisor_requests
    set status = 'APPROVED',
        review_notes = coalesce(v_notes, review_notes),
        reviewed_by = v_user_id,
        reviewed_at = v_now
    where id = p_request_id;

    insert into public.club_advisors (
      club_id,
      school_year,
      supervisor_name,
      supervisor_email,
      status,
      approved_from_request_id,
      approved_by,
      approved_at
    )
    select
      v_req.club_id,
      v_year,
      s.supervisor_name,
      s.supervisor_email,
      'ACTIVE',
      v_req.id,
      v_user_id,
      v_now
    from public.club_supervisor_request_supervisors s
    where s.supervisor_request_id = v_req.id
    on conflict (club_id, school_year, supervisor_email)
      where status = 'ACTIVE'
      do nothing;

    -- Cap at 3 active advisors: deactivate extras beyond 3 (oldest kept)
    with ranked as (
      select id,
             row_number() over (
               partition by club_id, school_year
               order by approved_at nulls last, created_at
             ) as rn
      from public.club_advisors
      where club_id = v_req.club_id
        and school_year = v_year
        and status = 'ACTIVE'
    )
    update public.club_advisors a
    set status = 'INACTIVE'
    from ranked r
    where a.id = r.id
      and r.rn > 3;

    select count(*) into v_active_count
    from public.club_advisors
    where club_id = v_req.club_id
      and school_year = v_year
      and status = 'ACTIVE';

    if v_active_count >= 1 then
      update public.club_school_years
      set status = 'ACTIVE',
          supervisor_due_at = null,
          activated_at = coalesce(activated_at, v_now)
      where club_id = v_req.club_id
        and school_year = v_year
        and status = 'PENDING_SUPERVISOR';
    end if;

  else
    raise exception 'Unsupported action: %', v_action;
  end if;

  return p_request_id;
end;
$$;

revoke all on function public.review_club_supervisor_request(uuid, text, text)
from public, anon;
grant execute on function public.review_club_supervisor_request(uuid, text, text)
to authenticated;


-- ---------------------------------------------------------
-- extend_club_supervisor_deadline
-- ---------------------------------------------------------

create or replace function public.extend_club_supervisor_deadline(
  p_club_id uuid,
  p_new_due_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_year text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  if p_new_due_at is null or p_new_due_at <= now() then
    raise exception 'New deadline must be in the future';
  end if;

  v_year := public.get_current_club_school_year();

  update public.club_school_years
  set supervisor_due_at = p_new_due_at
  where club_id = p_club_id
    and school_year = v_year
    and status = 'PENDING_SUPERVISOR';

  if not found then
    raise exception 'No PENDING_SUPERVISOR annual record found for this club';
  end if;

  return p_club_id;
end;
$$;

revoke all on function public.extend_club_supervisor_deadline(uuid, timestamptz)
from public, anon;
grant execute on function public.extend_club_supervisor_deadline(uuid, timestamptz)
to authenticated;


-- ---------------------------------------------------------
-- admin_deactivate_club_advisor
-- ---------------------------------------------------------

create or replace function public.admin_deactivate_club_advisor(
  p_advisor_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_adv public.club_advisors%rowtype;
  v_remaining int;
  v_year text;
  v_now timestamptz := now();
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  select * into v_adv
  from public.club_advisors
  where id = p_advisor_id
  for update;

  if not found then
    raise exception 'Advisor not found';
  end if;

  update public.club_advisors
  set status = 'INACTIVE'
  where id = p_advisor_id;

  v_year := v_adv.school_year;

  select count(*) into v_remaining
  from public.club_advisors
  where club_id = v_adv.club_id
    and school_year = v_year
    and status = 'ACTIVE';

  if v_remaining = 0 then
    update public.club_school_years
    set status = 'PENDING_SUPERVISOR',
        supervisor_due_at = v_now + interval '7 days',
        activated_at = null
    where club_id = v_adv.club_id
      and school_year = v_year
      and status = 'ACTIVE';
  end if;

  return p_advisor_id;
end;
$$;

revoke all on function public.admin_deactivate_club_advisor(uuid)
from public, anon;
grant execute on function public.admin_deactivate_club_advisor(uuid)
to authenticated;
