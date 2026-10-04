-- Club Promo Lunch sign-up workflow.

create table public.club_promo_lunch_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  submitted_by uuid not null references public.profiles(id) on delete cascade,
  applicant_email text not null,
  school_year text not null default '2026-2027',
  booth_days text not null,
  approval_email_received boolean not null,
  representatives text not null,
  status text not null default 'SUBMITTED',
  review_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint promo_lunch_booth_days_valid
    check (booth_days in ('OCTOBER_1', 'OCTOBER_2', 'BOTH')),
  constraint promo_lunch_status_valid
    check (status in ('SUBMITTED', 'APPROVED', 'REJECTED')),
  constraint promo_lunch_representatives_valid
    check (char_length(btrim(representatives)) between 2 and 5000)
);

create unique index club_promo_lunch_blocking_year_uidx
  on public.club_promo_lunch_requests (club_id, school_year)
  where status in ('SUBMITTED', 'APPROVED');

create index club_promo_lunch_status_idx
  on public.club_promo_lunch_requests (status, submitted_at);

create trigger set_club_promo_lunch_requests_updated_at
before update on public.club_promo_lunch_requests
for each row
execute function public.set_updated_at();

alter table public.club_promo_lunch_requests enable row level security;

revoke all on table public.club_promo_lunch_requests from public, anon;
grant select on table public.club_promo_lunch_requests to anon, authenticated;

create policy "club_promo_lunch_select_own"
on public.club_promo_lunch_requests
for select
to authenticated
using (submitted_by = (select auth.uid()));

create policy "club_promo_lunch_select_club_managers"
on public.club_promo_lunch_requests
for select
to authenticated
using (public.has_club_role(club_id, array['OWNER', 'EXEC']));

create policy "club_promo_lunch_select_reviewers"
on public.club_promo_lunch_requests
for select
to authenticated
using (public.can_read_review_queues());

create policy "club_promo_lunch_select_approved_public"
on public.club_promo_lunch_requests
for select
to anon, authenticated
using (status = 'APPROVED');

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

  if not exists (
    select 1
    from public.clubs
    where id = p_club_id
      and status = 'APPROVED'
  ) then
    raise exception 'The selected club is not available';
  end if;

  if public.get_club_current_annual_status(p_club_id)
     is distinct from 'ACTIVE' then
    raise exception 'This sign-up is available only for active clubs';
  end if;

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

revoke all on function public.submit_club_promo_lunch_request(
  uuid, uuid, text, boolean, text, text
) from public, anon;

grant execute on function public.submit_club_promo_lunch_request(
  uuid, uuid, text, boolean, text, text
) to authenticated;

create or replace function public.review_club_promo_lunch_request(
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
  v_action text;
  v_notes text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null or not public.can_mutate_reviews() then
    raise exception 'Only authorized reviewers may review this sign-up'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));
  v_notes := nullif(btrim(coalesce(p_review_notes, '')), '');

  if v_action not in ('APPROVED', 'REJECTED') then
    raise exception 'This sign-up can only be approved or rejected';
  end if;

  if v_action = 'REJECTED' and v_notes is null then
    raise exception 'Review notes are required when rejecting';
  end if;

  update public.club_promo_lunch_requests
  set
    status = v_action,
    review_notes = v_notes,
    reviewed_by = v_user_id,
    reviewed_at = now()
  where id = p_request_id
    and status = 'SUBMITTED';

  if not found then
    raise exception 'This sign-up was not found or is no longer reviewable';
  end if;

  return p_request_id;
end;
$$;

revoke all on function public.review_club_promo_lunch_request(
  uuid, text, text
) from public, anon;

grant execute on function public.review_club_promo_lunch_request(
  uuid, text, text
) to authenticated;
