-- Rejected or withdrawn re-applications must return the club to the
-- re-apply pool for the current school year. A leftover ACTIVE/PENDING
-- annual row (or a missing year row) was hiding clubs such as Photography.

create or replace function public.restore_club_reapplication_eligibility(
  p_club_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_year text;
  v_club public.clubs%rowtype;
  v_now timestamptz := now();
begin
  if p_club_id is null then
    return;
  end if;

  v_year := public.get_current_club_school_year();

  select *
  into v_club
  from public.clubs
  where id = p_club_id
  for update;

  if not found then
    return;
  end if;

  if v_club.deleted_at is not null then
    return;
  end if;

  if exists (
    select 1
    from public.club_reapplication_requests r
    where r.club_id = p_club_id
      and r.school_year = v_year
      and r.status in ('SUBMITTED', 'APPROVED')
  ) then
    return;
  end if;

  insert into public.club_school_years (club_id, school_year, status)
  values (p_club_id, v_year, 'INACTIVE')
  on conflict (club_id, school_year) do nothing;

  update public.club_school_years
  set
    status = 'INACTIVE',
    supervisor_due_at = null,
    activated_at = null
  where club_id = p_club_id
    and school_year = v_year
    and status is distinct from 'INACTIVE';

  update public.club_memberships
  set status = 'INACTIVE'
  where club_id = p_club_id
    and status = 'ACTIVE';

  update public.club_supervisor_requests
  set
    status = 'CANCELLED',
    review_notes = coalesce(
      nullif(btrim(coalesce(review_notes, '')), ''),
      'Cancelled because the club returned to the re-application pool.'
    ),
    reviewed_by = coalesce((select auth.uid()), reviewed_by),
    reviewed_at = coalesce(reviewed_at, v_now)
  where club_id = p_club_id
    and school_year = v_year
    and status in ('SUBMITTED', 'UNDER_REVIEW', 'CHANGES_REQUESTED');

  update public.club_advisors
  set status = 'INACTIVE'
  where club_id = p_club_id
    and school_year = v_year
    and status = 'ACTIVE';

  update public.clubs
  set eligible_for_reapplication = true
  where id = p_club_id
    and eligible_for_reapplication is distinct from true;
end;
$$;

revoke all on function public.restore_club_reapplication_eligibility(uuid)
from public, anon, authenticated;

create or replace function public.tg_restore_reapplication_eligibility()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('REJECTED', 'WITHDRAWN')
     and old.status is distinct from new.status then
    perform public.restore_club_reapplication_eligibility(new.club_id);
  end if;
  return new;
end;
$$;

revoke all on function public.tg_restore_reapplication_eligibility()
from public, anon, authenticated;

drop trigger if exists tg_restore_reapplication_eligibility
on public.club_reapplication_requests;

create trigger tg_restore_reapplication_eligibility
after update of status
on public.club_reapplication_requests
for each row
execute function public.tg_restore_reapplication_eligibility();

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

  perform public.restore_club_reapplication_eligibility(v_req.club_id);

  return p_request_id;
end;
$$;

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
  v_pattern text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();
  v_q := nullif(lower(btrim(coalesce(p_search, ''))), '');
  v_pattern := case
    when v_q is null then null
    else public.like_contains_pattern(v_q)
  end;

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
  left join public.club_school_years csy
    on csy.club_id = c.id
   and csy.school_year = v_year
  where c.deleted_at is null
    and c.eligible_for_reapplication = true
    and coalesce(csy.status, 'INACTIVE') = 'INACTIVE'
    and not exists (
      select 1
      from public.club_reapplication_requests r
      where r.club_id = c.id
        and r.school_year = v_year
        and r.status in ('SUBMITTED', 'APPROVED')
    )
    and (
      v_pattern is null
      or lower(c.name) like v_pattern escape '\'
      or lower(c.slug) like v_pattern escape '\'
      or exists (
        select 1
        from public.club_aliases a
        where a.club_id = c.id
          and lower(a.alias) like v_pattern escape '\'
      )
      or exists (
        select 1
        from unnest(c.source_names) as sn
        where lower(sn) like v_pattern escape '\'
      )
    )
  order by c.name;
end;
$$;

revoke all on function public.list_eligible_clubs_for_reapplication(text)
from public, anon;

grant execute on function public.list_eligible_clubs_for_reapplication(text)
to authenticated;

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

  select * into v_club
  from public.clubs
  where id = p_club_id
  for update;

  if not found then
    raise exception 'Club not found';
  end if;

  if v_club.deleted_at is not null then
    raise exception 'This club is not eligible for re-application';
  end if;

  if v_club.eligible_for_reapplication is not true then
    raise exception 'This club is not eligible for re-application';
  end if;

  insert into public.club_school_years (club_id, school_year, status)
  values (p_club_id, v_year, 'INACTIVE')
  on conflict (club_id, school_year) do nothing;

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
      and r.status in ('SUBMITTED', 'APPROVED')
  ) then
    raise exception
      'A re-application for this club is already in progress'
      using errcode = '23505';
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
      raise exception
        'Provide one to three teacher supervisors, or mark that you are still searching';
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

  return v_request_id;
end;
$$;

revoke all on function public.submit_club_reapplication(
  uuid, uuid, text, text, text, text, text, text[], text, text, text,
  boolean, boolean, jsonb, jsonb
) from public, anon;

grant execute on function public.submit_club_reapplication(
  uuid, uuid, text, text, text, text, text, text[], text, text, text,
  boolean, boolean, jsonb, jsonb
) to authenticated;

-- Existing closed re-applications should be selectable again this year.
do $$
declare
  r record;
  v_year text := public.get_current_club_school_year();
begin
  for r in
    select distinct request.club_id
    from public.club_reapplication_requests as request
    where request.school_year = v_year
      and request.status in ('REJECTED', 'WITHDRAWN')
      and not exists (
        select 1
        from public.club_reapplication_requests as open_request
        where open_request.club_id = request.club_id
          and open_request.school_year = v_year
          and open_request.status in ('SUBMITTED', 'APPROVED')
      )
  loop
    perform public.restore_club_reapplication_eligibility(r.club_id);
  end loop;

  for r in
    select c.id
    from public.clubs c
    where c.deleted_at is null
      and (
        c.id = 'bb7ff7ba-198d-4ea7-a3e3-d2a904205891'
        or c.slug = 'jfss-photography-club'
        or lower(btrim(c.name)) = 'jfss photography club'
      )
  loop
    perform public.restore_club_reapplication_eligibility(r.id);
  end loop;
end;
$$;

insert into public.club_aliases (club_id, alias)
select c.id, 'Photography Club'
from public.clubs c
where c.deleted_at is null
  and (
    c.id = 'bb7ff7ba-198d-4ea7-a3e3-d2a904205891'
    or c.slug = 'jfss-photography-club'
    or lower(btrim(c.name)) = 'jfss photography club'
  )
on conflict do nothing;

update public.clubs c
set source_names = (
  select coalesce(array_agg(distinct name_value), '{}'::text[])
  from unnest(
    coalesce(c.source_names, '{}'::text[])
    || array['JFSS Photography Club', 'Photography Club']::text[]
  ) as name_value
  where nullif(btrim(name_value), '') is not null
)
where c.deleted_at is null
  and (
    c.id = 'bb7ff7ba-198d-4ea7-a3e3-d2a904205891'
    or c.slug = 'jfss-photography-club'
    or lower(btrim(c.name)) = 'jfss photography club'
  );
