-- Club funding requests with private signature uploads and SAC-admin review.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'club-funding-signatures',
  'club-funding-signatures',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "funding_signatures_insert_own" on storage.objects;
create policy "funding_signatures_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-funding-signatures'
  and (storage.foldername(name))[1] = 'funding-signatures'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists "funding_signatures_select_allowed" on storage.objects;
create policy "funding_signatures_select_allowed"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-funding-signatures'
  and (
    (storage.foldername(name))[2] = (select auth.uid())::text
    or public.has_system_role('SAC_ADMIN')
  )
);

drop policy if exists "funding_signatures_delete_allowed" on storage.objects;
create policy "funding_signatures_delete_allowed"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-funding-signatures'
  and (
    (storage.foldername(name))[2] = (select auth.uid())::text
    or public.has_system_role('SAC_ADMIN')
  )
);

create table if not exists public.club_funding_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete restrict,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  applicant_email text not null,
  school_year text not null,
  usage_of_funding text not null,
  cost_breakdown jsonb not null,
  total_amount numeric(12, 2) not null,
  requires_principal_review boolean not null default false,
  supervisor_signature_path text not null,
  applicant_signature_path text not null,
  status text not null default 'SUBMITTED',
  review_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint club_funding_school_year_not_blank
    check (length(btrim(school_year)) > 0),
  constraint club_funding_usage_not_blank
    check (length(btrim(usage_of_funding)) > 0),
  constraint club_funding_cost_breakdown_array
    check (jsonb_typeof(cost_breakdown) = 'array'),
  constraint club_funding_total_positive
    check (total_amount > 0),
  constraint club_funding_signature_paths_not_blank
    check (
      length(btrim(supervisor_signature_path)) > 0
      and length(btrim(applicant_signature_path)) > 0
    ),
  constraint club_funding_status_valid
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

create index if not exists club_funding_requested_by_idx
  on public.club_funding_requests (requested_by, created_at desc);

create index if not exists club_funding_status_idx
  on public.club_funding_requests (status, requires_principal_review, submitted_at desc);

create index if not exists club_funding_club_idx
  on public.club_funding_requests (club_id, school_year, created_at desc);

drop trigger if exists set_club_funding_requests_updated_at
on public.club_funding_requests;
create trigger set_club_funding_requests_updated_at
before update on public.club_funding_requests
for each row
execute function public.set_updated_at();

alter table public.club_funding_requests enable row level security;

revoke all on table public.club_funding_requests from public, anon;
grant select on table public.club_funding_requests to authenticated;

drop policy if exists "club_funding_select_own" on public.club_funding_requests;
create policy "club_funding_select_own"
on public.club_funding_requests
for select
to authenticated
using (
  requested_by = (select auth.uid())
  or public.has_system_role('SAC_ADMIN')
);

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

  if not exists (
    select 1
    from public.clubs
    where id = p_club_id
      and status = 'APPROVED'
      and deleted_at is null
  ) then
    raise exception 'Funding is only available for active clubs';
  end if;

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

revoke all on function public.submit_club_funding_request(
  uuid, uuid, text, jsonb, text, text, text
) from public, anon;
grant execute on function public.submit_club_funding_request(
  uuid, uuid, text, jsonb, text, text, text
) to authenticated;

create or replace function public.review_club_funding_request(
  p_request_id uuid,
  p_action text,
  p_review_notes text default null
)
returns public.club_funding_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid;
  v_action text;
  v_row public.club_funding_requests;
begin
  v_admin_id := (select auth.uid());
  if v_admin_id is null or not public.has_system_role('SAC_ADMIN') then
    raise exception 'SAC admin access is required' using errcode = '42501';
  end if;

  v_action := upper(btrim(coalesce(p_action, '')));
  if v_action not in (
    'UNDER_REVIEW',
    'CHANGES_REQUESTED',
    'APPROVED',
    'REJECTED'
  ) then
    raise exception 'Invalid funding request review action';
  end if;

  if v_action in ('CHANGES_REQUESTED', 'REJECTED')
     and nullif(btrim(coalesce(p_review_notes, '')), '') is null then
    raise exception 'Review notes are required for this action';
  end if;

  update public.club_funding_requests
  set
    status = v_action,
    review_notes = nullif(btrim(coalesce(p_review_notes, '')), ''),
    reviewed_by = v_admin_id,
    reviewed_at = now()
  where id = p_request_id
    and status in (
      'SUBMITTED',
      'UNDER_REVIEW',
      'CHANGES_REQUESTED'
    )
  returning * into v_row;

  if not found then
    raise exception 'Funding request was not found or is no longer reviewable';
  end if;

  return v_row;
end;
$$;

revoke all on function public.review_club_funding_request(
  uuid, text, text
) from public, anon;
grant execute on function public.review_club_funding_request(
  uuid, text, text
) to authenticated;

