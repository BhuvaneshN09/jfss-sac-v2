-- =========================================================
-- Archive branching by immutable creation origin
-- =========================================================
-- NEW_APPLICATION clubs → terminal soft-delete (deleted_at), never reapply
-- HISTORICAL_IMPORT / UNKNOWN → existing soft-archive + reapply-eligible
-- Origin is NOT inferred from current status or open reapplications.

-- ---------------------------------------------------------
-- 1. Schema
-- ---------------------------------------------------------

alter table public.clubs
  add column if not exists creation_origin text,
  add column if not exists deleted_at timestamptz;

update public.clubs
set creation_origin = 'UNKNOWN'
where creation_origin is null;

alter table public.clubs
  alter column creation_origin set default 'UNKNOWN',
  alter column creation_origin set not null;

alter table public.clubs
  drop constraint if exists clubs_creation_origin_valid;

alter table public.clubs
  add constraint clubs_creation_origin_valid
  check (
    creation_origin in (
      'NEW_APPLICATION',
      'HISTORICAL_IMPORT',
      'UNKNOWN'
    )
  );

alter table public.clubs
  drop constraint if exists clubs_deleted_requires_archived;

alter table public.clubs
  add constraint clubs_deleted_requires_archived
  check (
    deleted_at is null
    or (
      status = 'ARCHIVED'
      and eligible_for_reapplication = false
    )
  );

create index if not exists clubs_deleted_at_idx
  on public.clubs (deleted_at)
  where deleted_at is not null;

create index if not exists clubs_creation_origin_idx
  on public.clubs (creation_origin);


-- ---------------------------------------------------------
-- 2. Authoritative backfill (no guessing)
-- ---------------------------------------------------------

-- Seed / import flag is authoritative for historical clubs.
update public.clubs
set creation_origin = 'HISTORICAL_IMPORT'
where is_imported_seed = true;

-- Clubs born from approved new-club applications.
update public.clubs c
set creation_origin = 'NEW_APPLICATION'
where c.creation_origin = 'UNKNOWN'
  and exists (
    select 1
    from public.club_registration_requests r
    where r.created_club_id = c.id
  );

-- Previously owner-archived new-application clubs become terminal.
update public.clubs
set
  deleted_at = coalesce(archived_at, updated_at, now()),
  eligible_for_reapplication = false,
  status = 'ARCHIVED'
where creation_origin = 'NEW_APPLICATION'
  and status = 'ARCHIVED'
  and deleted_at is null;


-- ---------------------------------------------------------
-- 3. Immutable origin + terminal deleted_at
-- ---------------------------------------------------------

create or replace function public.clubs_enforce_origin_and_deletion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.creation_origin is null or new.creation_origin = 'UNKNOWN' then
      if coalesce(new.is_imported_seed, false) then
        new.creation_origin := 'HISTORICAL_IMPORT';
      elsif new.created_by is not null then
        new.creation_origin := 'NEW_APPLICATION';
      else
        new.creation_origin := 'UNKNOWN';
      end if;
    end if;
    return new;
  end if;

  if new.creation_origin is distinct from old.creation_origin then
    raise exception 'creation_origin is immutable'
      using errcode = 'P0001';
  end if;

  if old.deleted_at is not null then
    if new.deleted_at is distinct from old.deleted_at then
      raise exception 'deleted_at cannot be changed once set'
        using errcode = 'P0001';
    end if;
    if new.eligible_for_reapplication is distinct from false then
      raise exception
        'Permanently removed clubs cannot become reapplication-eligible'
        using errcode = 'P0001';
    end if;
    if new.status is distinct from 'ARCHIVED' then
      raise exception
        'Permanently removed clubs cannot change status'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists clubs_enforce_origin_and_deletion_trigger
  on public.clubs;
create trigger clubs_enforce_origin_and_deletion_trigger
before insert or update on public.clubs
for each row
execute function public.clubs_enforce_origin_and_deletion();


create or replace function public.prevent_club_direct_reactivation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.deleted_at is not null then
    raise exception
      'This club was permanently removed and cannot be reactivated or re-applied for.'
      using errcode = 'P0001';
  end if;

  if old.status = 'ARCHIVED'
     and new.status is distinct from 'ARCHIVED'
     and coalesce(
       nullif(current_setting('app.allow_club_unarchive', true), ''),
       'off'
     ) <> 'on' then
    raise exception
      'Archived clubs cannot be reactivated directly. Submit a re-application for SAC approval.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;


-- Block reapplication rows targeting terminal clubs (server-side).
create or replace function public.enforce_reapplication_target_eligibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club public.clubs%rowtype;
begin
  select * into v_club
  from public.clubs
  where id = new.club_id;

  if not found then
    raise exception 'Club not found';
  end if;

  if v_club.deleted_at is not null then
    raise exception
      'This club was permanently removed and cannot be re-applied for.'
      using errcode = 'P0001';
  end if;

  if v_club.creation_origin = 'NEW_APPLICATION'
     and v_club.status = 'ARCHIVED' then
    raise exception
      'Clubs created through a new-club application cannot be re-applied for after archive.'
      using errcode = 'P0001';
  end if;

  if v_club.eligible_for_reapplication is not true then
    raise exception 'This club is not eligible for re-application';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_reapplication_target_eligibility_trigger
  on public.club_reapplication_requests;
create trigger enforce_reapplication_target_eligibility_trigger
before insert on public.club_reapplication_requests
for each row
execute function public.enforce_reapplication_target_eligibility();


-- ---------------------------------------------------------
-- 4. RLS: hide terminally deleted clubs from product access
-- ---------------------------------------------------------

drop policy if exists "clubs_select_approved" on public.clubs;
create policy "clubs_select_approved"
on public.clubs
for select
to anon, authenticated
using (
  deleted_at is null
  and status = 'APPROVED'
  and public.club_is_publicly_active(id)
);

drop policy if exists "clubs_select_members" on public.clubs;
create policy "clubs_select_members"
on public.clubs
for select
to authenticated
using (
  deleted_at is null
  and public.has_club_role(id, array['OWNER', 'EXEC', 'MEMBER'])
);

drop policy if exists "clubs_select_past_members" on public.clubs;
create policy "clubs_select_past_members"
on public.clubs
for select
to authenticated
using (
  deleted_at is null
  and exists (
    select 1
    from public.club_memberships m
    where m.club_id = clubs.id
      and m.user_id = (select auth.uid())
  )
);

drop policy if exists "clubs_admin_select_all" on public.clubs;
create policy "clubs_admin_select_all"
on public.clubs
for select
to authenticated
using (
  deleted_at is null
  and (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  )
);


-- ---------------------------------------------------------
-- 5. Branched archive RPC (idempotent, owner-only)
-- ---------------------------------------------------------

create or replace function public.archive_owned_club(p_club_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_club public.clubs%rowtype;
  v_year text;
  v_annual public.club_school_years%rowtype;
  v_now timestamptz := now();
  v_terminal boolean := false;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club ID is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception 'Only an active club OWNER may archive this club'
      using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();

  select *
  into v_club
  from public.clubs
  where id = p_club_id
  for update;

  if not found then
    raise exception 'Club not found';
  end if;

  -- Idempotent terminal / soft-archive outcomes.
  if v_club.deleted_at is not null then
    return p_club_id;
  end if;

  if v_club.status = 'ARCHIVED'
     and v_club.creation_origin is distinct from 'NEW_APPLICATION' then
    return p_club_id;
  end if;

  v_terminal := (v_club.creation_origin = 'NEW_APPLICATION');

  -- Upgrade legacy soft-archived new-application clubs to terminal.
  if v_club.status = 'ARCHIVED' and v_terminal then
    update public.clubs
    set
      deleted_at = coalesce(archived_at, v_now),
      eligible_for_reapplication = false,
      archived_by = coalesce(archived_by, v_user_id),
      archived_at = coalesce(archived_at, v_now),
      last_active_school_year = coalesce(last_active_school_year, v_year)
    where id = p_club_id;
    return p_club_id;
  end if;

  insert into public.club_school_years (club_id, school_year, status)
  values (p_club_id, v_year, 'INACTIVE')
  on conflict (club_id, school_year) do nothing;

  select *
  into v_annual
  from public.club_school_years
  where club_id = p_club_id
    and school_year = v_year
  for update;

  if not found then
    raise exception 'Could not load the current club school year record';
  end if;

  if v_annual.status = 'INACTIVE' and v_club.status <> 'ARCHIVED' then
    -- Continue into club-row archive for consistency when annual already inactive.
    null;
  elsif v_annual.status not in ('ACTIVE', 'PENDING_SUPERVISOR', 'INACTIVE') then
    raise exception
      'Club annual status % cannot be archived',
      v_annual.status;
  end if;

  if v_annual.status in ('ACTIVE', 'PENDING_SUPERVISOR') then
    update public.club_school_years
    set
      status = 'INACTIVE',
      supervisor_due_at = null,
      activated_at = null
    where club_id = p_club_id
      and school_year = v_year;
  end if;

  update public.club_memberships
  set status = 'INACTIVE'
  where club_id = p_club_id
    and status = 'ACTIVE';

  update public.club_supervisor_requests
  set
    status = 'CANCELLED',
    review_notes = coalesce(
      nullif(btrim(coalesce(review_notes, '')), ''),
      case
        when v_terminal then
          'Cancelled because the club was permanently archived by an owner.'
        else
          'Cancelled because the club was archived by an owner.'
      end
    ),
    reviewed_by = v_user_id,
    reviewed_at = v_now
  where club_id = p_club_id
    and school_year = v_year
    and status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED');

  update public.club_advisors
  set status = 'INACTIVE'
  where club_id = p_club_id
    and school_year = v_year
    and status = 'ACTIVE';

  if v_terminal then
    update public.clubs
    set
      status = 'ARCHIVED',
      eligible_for_reapplication = false,
      deleted_at = v_now,
      archived_at = v_now,
      archived_by = v_user_id,
      last_active_school_year = v_year
    where id = p_club_id;
  else
    update public.clubs
    set
      status = 'ARCHIVED',
      eligible_for_reapplication = true,
      deleted_at = null,
      archived_at = v_now,
      archived_by = v_user_id,
      last_active_school_year = v_year
    where id = p_club_id;
  end if;

  return p_club_id;
end;
$$;

revoke all on function public.archive_owned_club(uuid)
from public, anon;
grant execute on function public.archive_owned_club(uuid)
to authenticated;


-- ---------------------------------------------------------
-- 6. Query updates
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
  where c.deleted_at is null
    and c.creation_origin is distinct from 'NEW_APPLICATION'
    and c.eligible_for_reapplication = true
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


drop function if exists public.list_archived_clubs(text);

create or replace function public.list_archived_clubs(
  p_search text default null
)
returns table (
  club_id uuid,
  name text,
  slug text,
  last_active_school_year text,
  archived_at timestamptz,
  archived_by uuid,
  archived_by_email text,
  archived_by_name text,
  eligible_for_reapplication boolean,
  creation_origin text,
  registration_request_count bigint,
  reapplication_request_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  ) then
    raise exception 'SAC_ADMIN or SAC_EXEC required' using errcode = '42501';
  end if;

  v_q := nullif(lower(btrim(coalesce(p_search, ''))), '');

  return query
  select
    c.id,
    c.name,
    c.slug,
    c.last_active_school_year,
    c.archived_at,
    c.archived_by,
    p.email,
    p.full_name,
    c.eligible_for_reapplication,
    c.creation_origin,
    (
      select count(*)::bigint
      from public.club_registration_requests r
      where r.created_club_id = c.id
    ),
    (
      select count(*)::bigint
      from public.club_reapplication_requests r
      where r.club_id = c.id
    )
  from public.clubs c
  left join public.profiles p on p.id = c.archived_by
  where c.status = 'ARCHIVED'
    and c.deleted_at is null
    and (
      v_q is null
      or lower(c.name) like '%' || v_q || '%'
      or lower(c.slug) like '%' || v_q || '%'
    )
  order by c.archived_at desc nulls last, c.name;
end;
$$;

revoke all on function public.list_archived_clubs(text)
from public, anon;
grant execute on function public.list_archived_clubs(text)
to authenticated;


create or replace function public.list_clubs_by_annual_status(
  p_status text
)
returns table (
  club_id uuid,
  name text,
  slug text,
  annual_status text,
  school_year text,
  supervisor_due_at timestamptz,
  is_overdue boolean,
  eligible_for_reapplication boolean,
  aliases text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_year text;
  v_status text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  ) then
    raise exception 'SAC_ADMIN or SAC_EXEC required' using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();
  v_status := upper(btrim(coalesce(p_status, '')));

  return query
  select
    c.id,
    c.name,
    c.slug,
    csy.status,
    csy.school_year,
    csy.supervisor_due_at,
    (
      csy.status = 'PENDING_SUPERVISOR'
      and csy.supervisor_due_at is not null
      and csy.supervisor_due_at < now()
    ) as is_overdue,
    c.eligible_for_reapplication,
    coalesce(
      (
        select array_agg(a.alias order by a.alias)
        from public.club_aliases a
        where a.club_id = c.id
      ),
      '{}'::text[]
    )
  from public.clubs c
  join public.club_school_years csy
    on csy.club_id = c.id
   and csy.school_year = v_year
  where c.deleted_at is null
    and c.status <> 'ARCHIVED'
    and (
      (
        v_status = 'OVERDUE'
        and csy.status = 'PENDING_SUPERVISOR'
        and csy.supervisor_due_at is not null
        and csy.supervisor_due_at < now()
      )
      or (
        v_status <> 'OVERDUE'
        and csy.status = v_status
      )
    )
  order by c.name;
end;
$$;

revoke all on function public.list_clubs_by_annual_status(text)
from public, anon;
grant execute on function public.list_clubs_by_annual_status(text)
to authenticated;


-- Explicit origin on new-club approval inserts.
create or replace function public.approve_club_registration_request(
  p_request_id uuid,
  p_slug text,
  p_review_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid;
  v_request public.club_registration_requests%rowtype;
  v_club_id uuid;
  v_year text;
  v_approved_at timestamptz;
  v_emails text[];
  v_email text;
  v_supervisor_name text;
begin
  v_admin_id := (select auth.uid());

  if v_admin_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not public.can_mutate_reviews() then
    raise exception
      'Only SAC administrators and faculty advisors may approve clubs'
      using errcode = '42501';
  end if;

  select *
  into v_request
  from public.club_registration_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Club registration request not found';
  end if;

  if v_request.status not in ('SUBMITTED', 'UNDER_REVIEW') then
    raise exception
      'Only submitted or under-review requests may be approved';
  end if;

  v_year := public.get_current_club_school_year();
  v_approved_at := now();

  insert into public.clubs (
    name,
    slug,
    short_description,
    description,
    contact_email,
    meeting_schedule,
    status,
    created_by,
    approved_by,
    approved_at,
    creation_origin,
    is_imported_seed,
    eligible_for_reapplication
  )
  values (
    v_request.proposed_name,
    lower(trim(p_slug)),
    v_request.short_description,
    v_request.description,
    v_request.faculty_advisor_email,
    v_request.meeting_plan,
    'APPROVED',
    v_request.requested_by,
    v_admin_id,
    v_approved_at,
    'NEW_APPLICATION',
    false,
    false
  )
  returning id into v_club_id;

  insert into public.club_memberships (
    club_id,
    user_id,
    role,
    status,
    added_by
  )
  values (
    v_club_id,
    v_request.requested_by,
    'OWNER',
    'ACTIVE',
    v_admin_id
  );

  insert into public.club_school_years (
    club_id,
    school_year,
    status,
    activated_at
  )
  values (
    v_club_id,
    v_year,
    'ACTIVE',
    v_approved_at
  )
  on conflict (club_id, school_year) do update
  set
    status = 'ACTIVE',
    supervisor_due_at = null,
    activated_at = excluded.activated_at;

  v_emails := coalesce(
    (
      select array_agg(distinct lower(btrim(email_value)))
      from unnest(coalesce(v_request.teacher_supervisor_emails, '{}'::text[]))
        as email_value
      where nullif(btrim(email_value), '') is not null
        and lower(btrim(email_value)) ~ '^[^[:space:]@]+@pdsb[.]net$'
    ),
    '{}'::text[]
  );

  if cardinality(v_emails) = 0
     and nullif(lower(btrim(coalesce(v_request.faculty_advisor_email, ''))), '')
         is not null
     and lower(btrim(v_request.faculty_advisor_email))
         ~ '^[^[:space:]@]+@pdsb[.]net$' then
    v_emails := array[lower(btrim(v_request.faculty_advisor_email))];
  end if;

  foreach v_email in array v_emails
  loop
    v_supervisor_name := initcap(
      replace(split_part(v_email, '@', 1), '.', ' ')
    );
    if char_length(btrim(v_supervisor_name)) < 2 then
      v_supervisor_name := 'Teacher Supervisor';
    end if;

    insert into public.club_advisors (
      club_id,
      school_year,
      supervisor_name,
      supervisor_email,
      status,
      approved_by,
      approved_at
    )
    values (
      v_club_id,
      v_year,
      left(btrim(v_supervisor_name), 120),
      v_email,
      'ACTIVE',
      v_admin_id,
      v_approved_at
    )
    on conflict (club_id, school_year, supervisor_email)
      where (status = 'ACTIVE')
      do nothing;
  end loop;

  update public.club_registration_requests
  set
    status = 'APPROVED',
    review_notes = p_review_notes,
    reviewed_by = v_admin_id,
    reviewed_at = v_approved_at,
    created_club_id = v_club_id
  where id = p_request_id;

  return v_club_id;
end;
$$;

revoke all
on function public.approve_club_registration_request(uuid, text, text)
from public, anon, authenticated;

grant execute
on function public.approve_club_registration_request(uuid, text, text)
to authenticated;


-- Helper for ops: list clubs that still need manual origin classification.
create or replace function public.list_unclassified_club_origins()
returns table (
  club_id uuid,
  name text,
  slug text,
  status text,
  is_imported_seed boolean,
  created_by uuid,
  has_registration_link boolean,
  has_reapplication_history boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required' using errcode = '42501';
  end if;

  return query
  select
    c.id,
    c.name,
    c.slug,
    c.status,
    c.is_imported_seed,
    c.created_by,
    exists (
      select 1
      from public.club_registration_requests r
      where r.created_club_id = c.id
    ),
    exists (
      select 1
      from public.club_reapplication_requests r
      where r.club_id = c.id
    )
  from public.clubs c
  where c.creation_origin = 'UNKNOWN'
    and c.deleted_at is null
  order by c.name;
end;
$$;

revoke all on function public.list_unclassified_club_origins()
from public, anon;
grant execute on function public.list_unclassified_club_origins()
to authenticated;
