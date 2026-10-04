-- =========================================================
-- New-club approval must create current-year annual state
-- so approved clubs appear in public_active_clubs / Explore.
-- =========================================================

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
    v_approved_at
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

  -- Explore reads public_active_clubs (APPROVED + current-year ACTIVE).
  -- New applications already require supervisor emails, so activate now.
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


-- Backfill clubs approved before annual state was wired into approval.
insert into public.club_school_years (
  club_id,
  school_year,
  status,
  activated_at
)
select
  c.id,
  public.get_current_club_school_year(),
  'ACTIVE',
  coalesce(c.approved_at, c.created_at, now())
from public.clubs c
where c.status = 'APPROVED'
  and coalesce(c.is_imported_seed, false) = false
  and not exists (
    select 1
    from public.club_school_years csy
    where csy.club_id = c.id
      and csy.school_year = public.get_current_club_school_year()
  )
on conflict (club_id, school_year) do nothing;
