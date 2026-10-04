-- Club applications and re-applications now move directly from SUBMITTED
-- to APPROVED or REJECTED. Existing in-progress intermediate requests remain
-- pending; old drafts are closed so no invalid status is retained.

update public.club_registration_requests
set status = case
  when status = 'DRAFT' then 'WITHDRAWN'
  else 'SUBMITTED'
end
where status in ('DRAFT', 'UNDER_REVIEW', 'CHANGES_REQUESTED');

update public.club_reapplication_requests
set status = 'WITHDRAWN'
where status = 'DRAFT';

update public.club_reapplication_requests
set status = 'SUBMITTED'
where status in ('UNDER_REVIEW', 'CHANGES_REQUESTED');

alter table public.club_registration_requests
  drop constraint if exists club_requests_status_valid;

alter table public.club_registration_requests
  add constraint club_requests_status_valid
  check (
    status in ('SUBMITTED', 'APPROVED', 'REJECTED', 'WITHDRAWN')
  );

alter table public.club_reapplication_requests
  drop constraint if exists club_reapp_v2_status_valid;

alter table public.club_reapplication_requests
  add constraint club_reapp_v2_status_valid
  check (
    status in ('SUBMITTED', 'APPROVED', 'REJECTED', 'WITHDRAWN')
  );

drop index if exists public.club_reapp_v2_blocking_club_year_uidx;

create unique index club_reapp_v2_blocking_club_year_uidx
on public.club_reapplication_requests (club_id, school_year)
where status in ('SUBMITTED', 'APPROVED');

drop policy if exists "club_requests_insert_own"
on public.club_registration_requests;

create policy "club_requests_insert_own"
on public.club_registration_requests
for insert
to authenticated
with check (
  requested_by = (select auth.uid())
  and status = 'SUBMITTED'
);

drop policy if exists "club_requests_update_own"
on public.club_registration_requests;

create policy "club_requests_update_own"
on public.club_registration_requests
for update
to authenticated
using (
  requested_by = (select auth.uid())
  and status = 'SUBMITTED'
)
with check (
  requested_by = (select auth.uid())
  and status in ('SUBMITTED', 'WITHDRAWN')
);

drop policy if exists "club_requests_delete_own_draft"
on public.club_registration_requests;

drop policy if exists "club_reapp_insert_own"
on public.club_reapplication_requests;

create policy "club_reapp_insert_own"
on public.club_reapplication_requests
for insert
to authenticated
with check (
  requested_by = (select auth.uid())
  and status = 'SUBMITTED'
);

drop policy if exists "club_reapp_update_own"
on public.club_reapplication_requests;

create policy "club_reapp_update_own"
on public.club_reapplication_requests
for update
to authenticated
using (
  requested_by = (select auth.uid())
  and status = 'SUBMITTED'
)
with check (
  requested_by = (select auth.uid())
  and status in ('SUBMITTED', 'WITHDRAWN')
);

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

  if tg_op = 'INSERT' then
    if not is_application_admin then
      if new.requested_by is distinct from current_user_id then
        raise exception 'requested_by must be the authenticated user';
      end if;

      if new.status <> 'SUBMITTED' then
        raise exception 'New requests must be SUBMITTED';
      end if;

      if new.review_notes is not null
         or new.reviewed_by is not null
         or new.reviewed_at is not null
         or new.created_club_id is not null then
        raise exception 'Students cannot set administrative review fields';
      end if;
    end if;

    if new.status = 'SUBMITTED' then
      new.submitted_at := coalesce(new.submitted_at, now());
    end if;

    return new;
  end if;

  if current_setting('app.allow_registration_request_details_update', true)
     = 'on' then
    return new;
  end if;

  if not is_application_admin then
    if new.id is distinct from old.id
       or new.requested_by is distinct from old.requested_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Request identity fields cannot be changed';
    end if;

    if new.review_notes is distinct from old.review_notes
       or new.reviewed_by is distinct from old.reviewed_by
       or new.reviewed_at is distinct from old.reviewed_at
       or new.created_club_id is distinct from old.created_club_id then
      raise exception 'Students cannot change administrative review fields';
    end if;

    if old.status <> 'SUBMITTED' then
      raise exception 'This request can no longer be edited';
    end if;

    if new.status not in ('SUBMITTED', 'WITHDRAWN') then
      raise exception 'Invalid student request status change';
    end if;

    if new.submitted_at is distinct from old.submitted_at then
      raise exception 'submitted_at is managed automatically';
    end if;
  end if;

  if new.status = 'SUBMITTED'
     and old.status is distinct from 'SUBMITTED' then
    new.submitted_at := now();
  end if;

  if is_application_admin
     and new.status in ('APPROVED', 'REJECTED')
     and new.status is distinct from old.status then
    new.reviewed_at := coalesce(new.reviewed_at, now());
  end if;

  return new;
end;
$$;

create or replace function public.review_club_registration_request(
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
  v_admin_id uuid;
  v_action text;
  v_request public.club_registration_requests%rowtype;
  v_notes text;
begin
  v_admin_id := (select auth.uid());
  if v_admin_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.can_mutate_reviews() then
    raise exception
      'Only SAC administrators and faculty advisors may review club requests'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));
  v_notes := nullif(btrim(coalesce(p_review_notes, '')), '');

  if v_action <> 'REJECTED' then
    raise exception 'Club requests can only be approved or rejected';
  end if;

  select *
  into v_request
  from public.club_registration_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Club registration request not found';
  end if;

  if v_request.status <> 'SUBMITTED' then
    raise exception 'This request cannot be rejected';
  end if;

  if v_notes is null then
    raise exception 'Review notes are required when rejecting a request';
  end if;

  update public.club_registration_requests
  set
    status = 'REJECTED',
    review_notes = v_notes,
    reviewed_by = v_admin_id,
    reviewed_at = now()
  where id = p_request_id;

  return p_request_id;
end;
$$;

create or replace function public.review_club_reapplication(
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
  v_req public.club_reapplication_requests%rowtype;
  v_action text;
  v_notes text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC_ADMIN role required';
  end if;

  v_action := upper(btrim(p_action));
  v_notes := nullif(btrim(coalesce(p_review_notes, '')), '');

  select *
  into v_req
  from public.club_reapplication_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_action = 'APPROVED' then
    return public.approve_club_reapplication(p_request_id, v_notes);
  end if;

  if v_action <> 'REJECTED' then
    raise exception 'Re-applications can only be approved or rejected';
  end if;

  if v_req.status <> 'SUBMITTED' then
    raise exception 'This re-application cannot be rejected';
  end if;

  if v_notes is null then
    raise exception 'Review notes are required when rejecting';
  end if;

  update public.club_reapplication_requests
  set
    status = 'REJECTED',
    review_notes = v_notes,
    reviewed_by = v_user_id,
    reviewed_at = now()
  where id = p_request_id;

  return p_request_id;
end;
$$;
