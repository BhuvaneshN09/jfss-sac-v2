-- =========================================================
-- Club schema
-- =========================================================

create extension if not exists pgcrypto;


-- =========================================================
-- 1. CLUBS
--
-- Contains approved, suspended, or archived clubs.
-- A club registration request is stored separately.
-- =========================================================

create table public.clubs (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  slug text not null unique,

  short_description text,
  description text not null,

  logo_url text,
  banner_url text,
  contact_email text,

  meeting_location text,
  meeting_schedule text,

  status text not null default 'APPROVED',

  created_by uuid not null
    references public.profiles(id)
    on delete restrict,

  approved_by uuid
    references public.profiles(id)
    on delete set null,

  approved_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint clubs_name_valid
    check (
      name = btrim(name)
      and char_length(name) between 2 and 100
    ),

  constraint clubs_slug_valid
    check (
      slug = lower(slug)
      and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
      and char_length(slug) between 2 and 100
    ),

  constraint clubs_description_valid
    check (
      char_length(description) between 10 and 10000
    ),

  constraint clubs_status_valid
    check (
      status in (
        'APPROVED',
        'SUSPENDED',
        'ARCHIVED'
      )
    ),

  constraint clubs_contact_email_lowercase
    check (
      contact_email is null
      or contact_email = lower(contact_email)
    )
);


-- Prevent names that differ only by capitalization.
-- For example, "Chess Club" and "chess club".

create unique index clubs_name_lower_unique_idx
  on public.clubs (lower(name));

create index clubs_status_idx
  on public.clubs(status);

create index clubs_created_by_idx
  on public.clubs(created_by);


-- =========================================================
-- 2. CLUB REGISTRATION REQUESTS
--
-- Stores a student's application before a club exists.
-- =========================================================

create table public.club_registration_requests (
  id uuid primary key default gen_random_uuid(),

  requested_by uuid not null
    references public.profiles(id)
    on delete cascade,

  proposed_name text not null,

  short_description text,
  description text not null,
  purpose text not null,

  faculty_advisor_name text,
  faculty_advisor_email text,

  expected_member_count smallint,
  meeting_plan text,

  constitution_url text,

  status text not null default 'DRAFT',

  review_notes text,

  reviewed_by uuid
    references public.profiles(id)
    on delete set null,

  reviewed_at timestamptz,

  created_club_id uuid
    references public.clubs(id)
    on delete set null,

  submitted_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_requests_name_valid
    check (
      proposed_name = btrim(proposed_name)
      and char_length(proposed_name) between 2 and 100
    ),

  constraint club_requests_description_valid
    check (
      char_length(description) between 10 and 10000
    ),

  constraint club_requests_purpose_valid
    check (
      char_length(purpose) between 10 and 5000
    ),

  constraint club_requests_member_count_valid
    check (
      expected_member_count is null
      or expected_member_count between 1 and 2000
    ),

  constraint club_requests_status_valid
    check (
      status in (
        'DRAFT',
        'SUBMITTED',
        'UNDER_REVIEW',
        'CHANGES_REQUESTED',
        'APPROVED',
        'REJECTED',
        'WITHDRAWN'
      )
    ),

  constraint club_requests_advisor_email_lowercase
    check (
      faculty_advisor_email is null
      or faculty_advisor_email = lower(faculty_advisor_email)
    )
);

create index club_requests_requested_by_idx
  on public.club_registration_requests(requested_by);

create index club_requests_status_idx
  on public.club_registration_requests(status);

create index club_requests_created_club_idx
  on public.club_registration_requests(created_club_id);

create index club_requests_created_at_idx
  on public.club_registration_requests(created_at desc);


-- =========================================================
-- 3. CLUB MEMBERSHIPS
--
-- Club-specific roles belong here, not in system_roles.
-- =========================================================

create table public.club_memberships (
  club_id uuid not null
    references public.clubs(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  role text not null default 'MEMBER',
  status text not null default 'ACTIVE',

  added_by uuid
    references public.profiles(id)
    on delete set null,

  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (club_id, user_id),

  constraint club_memberships_role_valid
    check (
      role in (
        'OWNER',
        'EXEC',
        'MEMBER'
      )
    ),

  constraint club_memberships_status_valid
    check (
      status in (
        'ACTIVE',
        'INACTIVE'
      )
    )
);

-- The primary key already indexes (club_id, user_id).
-- This additional index supports queries by user.

create index club_memberships_user_id_idx
  on public.club_memberships(user_id);

create index club_memberships_club_role_idx
  on public.club_memberships(club_id, role, status);


-- =========================================================
-- 4. SYSTEM-ROLE PERMISSION HELPER
--
-- Lets RLS policies check roles such as SAC_ADMIN.
-- =========================================================

create or replace function public.has_system_role(
  requested_role_code text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_system_roles as assignment
    join public.system_roles as role
      on role.id = assignment.role_id
    where assignment.user_id = (select auth.uid())
      and role.code = requested_role_code
      and (
        assignment.expires_at is null
        or assignment.expires_at > now()
      )
  );
$$;

revoke all
on function public.has_system_role(text)
from public, anon, authenticated;

grant execute
on function public.has_system_role(text)
to authenticated;


-- =========================================================
-- 5. CLUB-ROLE PERMISSION HELPER
--
-- Used by membership RLS policies.
-- SECURITY DEFINER prevents recursive membership-policy checks.
-- =========================================================

create or replace function public.has_club_role(
  requested_club_id uuid,
  accepted_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.club_memberships as membership
    where membership.club_id = requested_club_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'ACTIVE'
      and membership.role = any(accepted_roles)
  );
$$;

revoke all
on function public.has_club_role(uuid, text[])
from public, anon, authenticated;

grant execute
on function public.has_club_role(uuid, text[])
to authenticated;


-- =========================================================
-- 6. PROTECT CLUB-REQUEST REVIEW FIELDS
--
-- Students may edit their application content, but may not
-- set approval data, review notes, or created_club_id.
-- =========================================================

create or replace function public.guard_club_registration_request()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_user_id uuid;
  is_application_admin boolean;
begin
  current_user_id := (select auth.uid());

  is_application_admin :=
    current_user_id is null
    or public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SITE_ADMIN');

  -- -------------------------------------------------------
  -- INSERT
  -- -------------------------------------------------------

  if tg_op = 'INSERT' then
    if not is_application_admin then
      if new.requested_by is distinct from current_user_id then
        raise exception
          'requested_by must be the authenticated user';
      end if;

      if new.status not in ('DRAFT', 'SUBMITTED') then
        raise exception
          'New requests must be DRAFT or SUBMITTED';
      end if;

      if new.review_notes is not null
         or new.reviewed_by is not null
         or new.reviewed_at is not null
         or new.created_club_id is not null then
        raise exception
          'Students cannot set administrative review fields';
      end if;
    end if;

    if new.status = 'SUBMITTED' then
      new.submitted_at := coalesce(new.submitted_at, now());
    else
      new.submitted_at := null;
    end if;

    return new;
  end if;

  -- -------------------------------------------------------
  -- UPDATE
  -- -------------------------------------------------------

  if not is_application_admin then
    if new.id is distinct from old.id
       or new.requested_by is distinct from old.requested_by
       or new.created_at is distinct from old.created_at then
      raise exception
        'Request identity fields cannot be changed';
    end if;

    if new.review_notes is distinct from old.review_notes
       or new.reviewed_by is distinct from old.reviewed_by
       or new.reviewed_at is distinct from old.reviewed_at
       or new.created_club_id is distinct from old.created_club_id then
      raise exception
        'Students cannot change administrative review fields';
    end if;

    if old.status not in ('DRAFT', 'CHANGES_REQUESTED') then
      raise exception
        'This request can no longer be edited';
    end if;

    if new.status not in (
      'DRAFT',
      'SUBMITTED',
      'WITHDRAWN'
    ) then
      raise exception
        'Invalid student request status change';
    end if;

    if new.submitted_at is distinct from old.submitted_at then
      raise exception
        'submitted_at is managed automatically';
    end if;
  end if;

  if new.status = 'SUBMITTED'
     and old.status is distinct from 'SUBMITTED' then
    new.submitted_at := now();
  end if;

  if is_application_admin
     and new.status in (
       'CHANGES_REQUESTED',
       'APPROVED',
       'REJECTED'
     )
     and new.status is distinct from old.status then
    new.reviewed_at := coalesce(new.reviewed_at, now());
  end if;

  return new;
end;
$$;

revoke all
on function public.guard_club_registration_request()
from public, anon, authenticated;

create trigger guard_club_registration_request
before insert or update
on public.club_registration_requests
for each row
execute function public.guard_club_registration_request();


-- =========================================================
-- 7. UPDATED_AT TRIGGERS
--
-- Reuses set_updated_at() from your first migration.
-- =========================================================

create trigger set_clubs_updated_at
before update
on public.clubs
for each row
execute function public.set_updated_at();

create trigger set_club_requests_updated_at
before update
on public.club_registration_requests
for each row
execute function public.set_updated_at();

create trigger set_club_memberships_updated_at
before update
on public.club_memberships
for each row
execute function public.set_updated_at();


-- =========================================================
-- 8. ENABLE ROW LEVEL SECURITY
-- =========================================================

alter table public.clubs
  enable row level security;

alter table public.club_registration_requests
  enable row level security;

alter table public.club_memberships
  enable row level security;


-- =========================================================
-- 9. TABLE GRANTS
--
-- Grants let a role reach a table.
-- RLS policies below determine which rows it can access.
-- =========================================================

grant usage on schema public
to anon, authenticated;

revoke all
on table public.clubs
from anon, authenticated;

revoke all
on table public.club_registration_requests
from anon, authenticated;

revoke all
on table public.club_memberships
from anon, authenticated;


-- Public users may read approved clubs.
-- Authenticated administrators may perform writes through RLS.

grant select
on table public.clubs
to anon, authenticated;

grant insert, update, delete
on table public.clubs
to authenticated;


-- Registration requests are private to signed-in users.

grant select, insert, update, delete
on table public.club_registration_requests
to authenticated;


-- Memberships require authentication.
--
-- Only role and status may be changed through a normal UPDATE.
-- club_id and user_id remain immutable.

grant select, insert, delete
on table public.club_memberships
to authenticated;

grant update (role, status)
on table public.club_memberships
to authenticated;


-- =========================================================
-- 10. CLUB RLS POLICIES
-- =========================================================

-- Anyone may read approved clubs.

create policy "clubs_select_approved"
on public.clubs
for select
to anon, authenticated
using (
  status = 'APPROVED'
);


-- SAC and site administrators may also read suspended
-- and archived clubs.

create policy "clubs_admin_select_all"
on public.clubs
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


create policy "clubs_admin_insert"
on public.clubs
for insert
to authenticated
with check (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


create policy "clubs_admin_update"
on public.clubs
for update
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
)
with check (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


create policy "clubs_admin_delete"
on public.clubs
for delete
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


-- =========================================================
-- 11. CLUB-REQUEST RLS POLICIES
-- =========================================================

-- Students may see their own requests.

create policy "club_requests_select_own"
on public.club_registration_requests
for select
to authenticated
using (
  requested_by = (select auth.uid())
);


-- Administrators may see every request.

create policy "club_requests_admin_select_all"
on public.club_registration_requests
for select
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


-- Students may create only their own draft or submitted request.

create policy "club_requests_insert_own"
on public.club_registration_requests
for insert
to authenticated
with check (
  requested_by = (select auth.uid())
  and status in ('DRAFT', 'SUBMITTED')
);


-- Students may edit their own drafts and requests returned
-- for changes. The trigger provides additional protection.

create policy "club_requests_update_own"
on public.club_registration_requests
for update
to authenticated
using (
  requested_by = (select auth.uid())
  and status in ('DRAFT', 'CHANGES_REQUESTED')
)
with check (
  requested_by = (select auth.uid())
  and status in (
    'DRAFT',
    'SUBMITTED',
    'WITHDRAWN'
  )
);


-- Students may delete only their own unsubmitted drafts.

create policy "club_requests_delete_own_draft"
on public.club_registration_requests
for delete
to authenticated
using (
  requested_by = (select auth.uid())
  and status = 'DRAFT'
);


-- Administrators manage the review process.

create policy "club_requests_admin_insert"
on public.club_registration_requests
for insert
to authenticated
with check (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


create policy "club_requests_admin_update"
on public.club_registration_requests
for update
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
)
with check (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


create policy "club_requests_admin_delete"
on public.club_registration_requests
for delete
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


-- =========================================================
-- 12. CLUB-MEMBERSHIP RLS POLICIES
-- =========================================================

-- Users may read:
-- 1. their own memberships;
-- 2. memberships for clubs they own or manage;
-- 3. all memberships if they are an application admin.

create policy "club_memberships_select_allowed"
on public.club_memberships
for select
to authenticated
using (
  user_id = (select auth.uid())

  or public.has_club_role(
    club_id,
    array['OWNER', 'EXEC']
  )

  or public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


-- Application administrators may create any membership.

create policy "club_memberships_admin_insert"
on public.club_memberships
for insert
to authenticated
with check (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


-- Club owners may add executives or members.
-- Club executives may add ordinary members.

create policy "club_memberships_club_leader_insert"
on public.club_memberships
for insert
to authenticated
with check (
  added_by = (select auth.uid())
  and status = 'ACTIVE'
  and (
    (
      role in ('EXEC', 'MEMBER')
      and public.has_club_role(
        club_id,
        array['OWNER']
      )
    )
    or
    (
      role = 'MEMBER'
      and public.has_club_role(
        club_id,
        array['EXEC']
      )
    )
  )
);


-- Administrators may update any membership.

create policy "club_memberships_admin_update"
on public.club_memberships
for update
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
)
with check (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


-- Owners may update non-owner memberships.

create policy "club_memberships_owner_update"
on public.club_memberships
for update
to authenticated
using (
  role <> 'OWNER'
  and public.has_club_role(
    club_id,
    array['OWNER']
  )
)
with check (
  role in ('EXEC', 'MEMBER')
  and public.has_club_role(
    club_id,
    array['OWNER']
  )
);


-- Executives may update ordinary members only.

create policy "club_memberships_exec_update"
on public.club_memberships
for update
to authenticated
using (
  role = 'MEMBER'
  and public.has_club_role(
    club_id,
    array['EXEC']
  )
)
with check (
  role = 'MEMBER'
  and public.has_club_role(
    club_id,
    array['EXEC']
  )
);


-- Administrators may delete any membership.

create policy "club_memberships_admin_delete"
on public.club_memberships
for delete
to authenticated
using (
  public.has_system_role('SAC_ADMIN')
  or public.has_system_role('SITE_ADMIN')
);


-- Owners may remove non-owner memberships.

create policy "club_memberships_owner_delete"
on public.club_memberships
for delete
to authenticated
using (
  role <> 'OWNER'
  and public.has_club_role(
    club_id,
    array['OWNER']
  )
);


-- Executives may remove ordinary members.

create policy "club_memberships_exec_delete"
on public.club_memberships
for delete
to authenticated
using (
  role = 'MEMBER'
  and public.has_club_role(
    club_id,
    array['EXEC']
  )
);


-- Members and executives may leave a club themselves.
-- Owners must transfer ownership before leaving.

create policy "club_memberships_leave_self"
on public.club_memberships
for delete
to authenticated
using (
  user_id = (select auth.uid())
  and role in ('MEMBER', 'EXEC')
);