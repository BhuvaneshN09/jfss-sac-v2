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
begin
  v_admin_id := (select auth.uid());

  if v_admin_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  if not (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SITE_ADMIN')
  ) then
    raise exception 'Only SAC or site administrators may approve clubs'
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
    approved_at
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
    now()
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

  update public.club_registration_requests
  set
    status = 'APPROVED',
    review_notes = p_review_notes,
    reviewed_by = v_admin_id,
    reviewed_at = now(),
    created_club_id = v_club_id
  where id = p_request_id;

  return v_club_id;
end;
$$;

revoke all
on function public.approve_club_registration_request(
  uuid,
  text,
  text
)
from public, anon, authenticated;

grant execute
on function public.approve_club_registration_request(
  uuid,
  text,
  text
)
to authenticated;