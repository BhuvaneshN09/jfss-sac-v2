-- Official, currently active clubs may submit event/funding/promo-lunch/announcement
-- requests. Archived clubs and clubs still pending supervisor cannot.

create or replace function public.assert_club_operations_allowed(p_club_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_club_status text;
  v_deleted_at timestamptz;
  v_annual_status text;
begin
  select status, deleted_at
  into v_club_status, v_deleted_at
  from public.clubs
  where id = p_club_id;

  if v_club_status is null or v_deleted_at is not null then
    raise exception 'The selected club is not available';
  end if;

  if v_club_status = 'ARCHIVED' then
    raise exception 'Archived clubs cannot submit requests'
      using errcode = '42501';
  end if;

  if v_club_status is distinct from 'APPROVED' then
    raise exception 'The selected club is not available';
  end if;

  v_annual_status := public.get_club_current_annual_status(p_club_id);
  if v_annual_status is distinct from 'ACTIVE' then
    raise exception
      'Requests are available only after the club is officially active. Current status: %',
      coalesce(v_annual_status, 'NONE')
      using errcode = '42501';
  end if;
end;
$$;

create or replace function public.submit_club_event_request(
  p_request_id uuid,
  p_club_id uuid,
  p_event_name text,
  p_event_description text,
  p_event_start_date date,
  p_event_end_date date,
  p_requested_materials text,
  p_photo_storage_path text default null,
  p_school_year text default '2026-2027',
  p_is_charitable_event boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_applicant_email text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select lower(email)
  into v_applicant_email
  from public.profiles
  where id = v_user_id;

  if v_applicant_email is null then
    raise exception 'Profile email is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception
      'Only an active club owner may submit an event proposal'
      using errcode = '42501';
  end if;

  perform public.assert_club_operations_allowed(p_club_id);

  if p_event_start_date < (timezone('America/Toronto', now()))::date then
    raise exception 'The event start date cannot be in the past';
  end if;

  if p_event_end_date < p_event_start_date then
    raise exception 'The event end date cannot be before the start date';
  end if;

  if p_photo_storage_path is not null
     and btrim(p_photo_storage_path) <> ''
     and btrim(p_photo_storage_path) not like (
       'event-photos/' || v_user_id::text || '/' || p_request_id::text || '/%'
     ) then
    raise exception 'Invalid event photo storage path' using errcode = '42501';
  end if;

  insert into public.club_event_requests (
    id,
    club_id,
    submitted_by,
    applicant_email,
    school_year,
    event_name,
    event_description,
    event_date,
    event_end_date,
    requested_materials,
    photo_storage_path,
    is_charitable_event,
    status,
    submitted_at
  )
  values (
    p_request_id,
    p_club_id,
    v_user_id,
    v_applicant_email,
    coalesce(nullif(btrim(p_school_year), ''), '2026-2027'),
    btrim(p_event_name),
    btrim(p_event_description),
    p_event_start_date,
    p_event_end_date,
    btrim(p_requested_materials),
    nullif(btrim(coalesce(p_photo_storage_path, '')), ''),
    coalesce(p_is_charitable_event, false),
    'SUBMITTED',
    now()
  );

  return p_request_id;
end;
$$;

create or replace function public.submit_club_funding_request(
  p_request_id uuid,
  p_club_id uuid,
  p_usage_of_funding text,
  p_cost_breakdown jsonb,
  p_supervisor_signature_path text,
  p_applicant_signature_path text,
  p_school_year text default '2026-2027'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_applicant_email text;
  v_usage text;
  v_total numeric(12, 2);
  v_requires_principal boolean;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_request_id is null or p_club_id is null then
    raise exception 'Funding request and club are required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception 'Only an active club owner may submit funding requests'
      using errcode = '42501';
  end if;

  perform public.assert_club_operations_allowed(p_club_id);

  v_usage := btrim(coalesce(p_usage_of_funding, ''));
  if v_usage = '' then
    raise exception 'Explain how the school or students will benefit';
  end if;

  if cardinality(regexp_split_to_array(v_usage, '\s+')) > 300 then
    raise exception 'Funding usage must be 300 words or fewer';
  end if;

  if jsonb_typeof(p_cost_breakdown) <> 'array'
     or jsonb_array_length(p_cost_breakdown) < 1
     or jsonb_array_length(p_cost_breakdown) > 100 then
    raise exception 'Add at least one valid funding cost item';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_cost_breakdown) as item(
      item text,
      unit_price numeric,
      quantity integer
    )
    where nullif(btrim(item.item), '') is null
      or item.unit_price is null
      or item.unit_price <= 0
      or item.quantity is null
      or item.quantity < 1
  ) then
    raise exception 'Each funding item needs a positive price and quantity';
  end if;

  select round(sum(item.unit_price * item.quantity), 2)
  into v_total
  from jsonb_to_recordset(p_cost_breakdown) as item(
    item text,
    unit_price numeric,
    quantity integer
  );

  if v_total is null or v_total <= 0 then
    raise exception 'Funding total must be greater than $0';
  end if;

  v_requires_principal := v_total > 500;

  if nullif(btrim(p_supervisor_signature_path), '') is null
     or p_supervisor_signature_path not like (
       'funding-signatures/' || v_user_id::text || '/' || p_request_id::text || '/%'
     ) then
    raise exception 'Invalid supervisor signature storage path'
      using errcode = '42501';
  end if;

  if nullif(btrim(p_applicant_signature_path), '') is null
     or p_applicant_signature_path not like (
       'funding-signatures/' || v_user_id::text || '/' || p_request_id::text || '/%'
     ) then
    raise exception 'Invalid applicant signature storage path'
      using errcode = '42501';
  end if;

  select lower(p.email)
  into v_applicant_email
  from public.profiles as p
  where p.id = v_user_id;

  if v_applicant_email is null then
    raise exception 'Applicant email is required';
  end if;

  insert into public.club_funding_requests (
    id,
    club_id,
    requested_by,
    applicant_email,
    school_year,
    usage_of_funding,
    cost_breakdown,
    total_amount,
    requires_principal_review,
    supervisor_signature_path,
    applicant_signature_path
  )
  values (
    p_request_id,
    p_club_id,
    v_user_id,
    v_applicant_email,
    coalesce(nullif(btrim(p_school_year), ''), '2026-2027'),
    v_usage,
    p_cost_breakdown,
    v_total,
    v_requires_principal,
    btrim(p_supervisor_signature_path),
    btrim(p_applicant_signature_path)
  );

  return p_request_id;
end;
$$;

create or replace function public.submit_club_promo_lunch_request(
  p_request_id uuid,
  p_club_id uuid,
  p_booth_days text,
  p_approval_email_received boolean,
  p_representatives text,
  p_school_year text default '2026-2027'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_applicant_email text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select lower(email)
  into v_applicant_email
  from public.profiles
  where id = v_user_id;

  if v_applicant_email is null then
    raise exception 'Profile email is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER']) then
    raise exception 'Only an active club owner may submit this sign-up'
      using errcode = '42501';
  end if;

  perform public.assert_club_operations_allowed(p_club_id);

  insert into public.club_promo_lunch_requests (
    id,
    club_id,
    submitted_by,
    applicant_email,
    school_year,
    booth_days,
    approval_email_received,
    representatives,
    status,
    submitted_at
  )
  values (
    p_request_id,
    p_club_id,
    v_user_id,
    v_applicant_email,
    coalesce(nullif(btrim(p_school_year), ''), '2026-2027'),
    upper(btrim(p_booth_days)),
    p_approval_email_received,
    btrim(p_representatives),
    'SUBMITTED',
    now()
  );

  return p_request_id;
end;
$$;

revoke all on function public.submit_club_event_request(
  uuid, uuid, text, text, date, date, text, text, text, boolean
) from public, anon;
grant execute on function public.submit_club_event_request(
  uuid, uuid, text, text, date, date, text, text, text, boolean
) to authenticated;

revoke all on function public.submit_club_funding_request(
  uuid, uuid, text, jsonb, text, text, text
) from public, anon;
grant execute on function public.submit_club_funding_request(
  uuid, uuid, text, jsonb, text, text, text
) to authenticated;

revoke all on function public.submit_club_promo_lunch_request(
  uuid, uuid, text, boolean, text, text
) from public, anon;
grant execute on function public.submit_club_promo_lunch_request(
  uuid, uuid, text, boolean, text, text
) to authenticated;
