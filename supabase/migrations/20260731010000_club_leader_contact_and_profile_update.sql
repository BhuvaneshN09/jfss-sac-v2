-- =========================================================
-- Public club leader contact + owner profile update RPC
-- =========================================================
-- leader_contact_information is intentionally public (like contact_email).
-- Individual EXEC/MEMBER profile emails remain membership-scoped and are
-- not exposed on public club pages.
-- Club UUID and slug stay stable when owners edit the display name.

alter table public.clubs
  add column if not exists leader_contact_information text;

comment on column public.clubs.leader_contact_information is
  'Public club-leader contact shown on the club page and Explore.';


-- Recreate the view so the new public column can be appended safely.
drop view if exists public.public_active_clubs;

create view public.public_active_clubs
with (security_invoker = true)
as
select
  c.id,
  c.name,
  c.slug,
  c.short_description,
  c.description,
  c.logo_url,
  c.banner_url,
  c.contact_email,
  c.instagram_handle,
  c.meeting_location,
  c.meeting_schedule,
  c.meeting_frequency,
  c.meeting_days,
  c.meeting_time_details,
  c.leader_contact_information,
  c.status as club_record_status,
  csy.school_year,
  csy.status as annual_status,
  csy.activated_at,
  c.created_at,
  c.updated_at
from public.clubs c
join public.club_school_years csy
  on csy.club_id = c.id
where csy.school_year = public.get_current_club_school_year()
  and csy.status = 'ACTIVE'
  and c.status = 'APPROVED';

grant select on public.public_active_clubs to anon, authenticated;


create or replace function public.update_owned_club_profile(
  p_club_id uuid,
  p_name text,
  p_description text,
  p_contact_email text default null,
  p_leader_contact_information text default null,
  p_short_description text default null
)
returns public.clubs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_name text;
  v_description text;
  v_contact text;
  v_leader text;
  v_short text;
  v_annual text;
  v_row public.clubs%rowtype;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club is required';
  end if;

  if not (
    public.has_club_role(p_club_id, array['OWNER'])
    or public.has_system_role('SAC_ADMIN')
  ) then
    raise exception 'Only an active club owner may update club details'
      using errcode = '42501';
  end if;

  v_annual := public.get_club_current_annual_status(p_club_id);
  if v_annual is distinct from 'PENDING_SUPERVISOR'
     and v_annual is distinct from 'ACTIVE'
     and not public.has_system_role('SAC_ADMIN') then
    raise exception
      'Club details can only be edited while the club is ACTIVE or PENDING_SUPERVISOR';
  end if;

  v_name := btrim(coalesce(p_name, ''));
  v_description := btrim(coalesce(p_description, ''));
  v_contact := nullif(lower(btrim(coalesce(p_contact_email, ''))), '');
  v_leader := nullif(btrim(coalesce(p_leader_contact_information, '')), '');
  v_short := nullif(btrim(coalesce(p_short_description, '')), '');

  if char_length(v_name) < 2 or char_length(v_name) > 100 then
    raise exception 'Club name must be between 2 and 100 characters';
  end if;

  if char_length(v_description) < 10 or char_length(v_description) > 10000 then
    raise exception 'Description must be between 10 and 10,000 characters';
  end if;

  if v_short is not null and char_length(v_short) > 280 then
    raise exception 'Short description must be 280 characters or fewer';
  end if;

  if v_contact is not null
     and v_contact !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Enter a valid club contact email';
  end if;

  if v_leader is not null and char_length(v_leader) > 500 then
    raise exception 'Leader contact must be 500 characters or fewer';
  end if;

  update public.clubs
  set
    name = v_name,
    description = v_description,
    short_description = coalesce(v_short, short_description),
    contact_email = v_contact,
    leader_contact_information = v_leader,
    updated_at = now()
  where id = p_club_id
  returning * into v_row;

  if not found then
    raise exception 'Club not found';
  end if;

  -- UUID and slug are intentionally not updated.
  return v_row;
end;
$$;

revoke all on function public.update_owned_club_profile(
  uuid, text, text, text, text, text
) from public, anon;

grant execute on function public.update_owned_club_profile(
  uuid, text, text, text, text, text
) to authenticated;
