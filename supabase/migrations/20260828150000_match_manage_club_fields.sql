-- Make Manage Club use the same public club fields as Re-register a club.

-- The forms have no description upper limit.
alter table public.clubs
  drop constraint if exists clubs_description_valid;

alter table public.club_registration_requests
  drop constraint if exists club_requests_description_valid;

alter table public.club_reapplication_requests
  drop constraint if exists club_reapp_v2_description_valid;

drop function if exists public.update_owned_club_profile(
  uuid, text, text, text, text, text, text
);

create or replace function public.update_owned_club_profile(
  p_club_id uuid,
  p_name text,
  p_description text,
  p_contact_email text default null,
  p_leader_contact_information text default null,
  p_short_description text default null,
  p_logo_url text default null,
  p_instagram_handle text default null,
  p_meeting_days text[] default '{}'::text[],
  p_meeting_time_details text default null,
  p_meeting_location text default null
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
  v_instagram text;
  v_days text[];
  v_time text;
  v_location text;
  v_logo text;
  v_schedule text;
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
  v_contact := lower(nullif(btrim(coalesce(p_contact_email, '')), ''));
  v_instagram := nullif(
    regexp_replace(btrim(coalesce(p_instagram_handle, '')), '^@+', ''),
    ''
  );
  v_days := coalesce(p_meeting_days, '{}'::text[]);
  v_time := nullif(btrim(coalesce(p_meeting_time_details, '')), '');
  v_location := nullif(btrim(coalesce(p_meeting_location, '')), '');
  v_logo := nullif(btrim(coalesce(p_logo_url, '')), '');

  if char_length(v_name) < 2 or char_length(v_name) > 100 then
    raise exception 'Enter your club name.';
  end if;

  if char_length(v_description) < 10 then
    raise exception
      'Provide a detailed club description (at least 10 characters).';
  end if;

  if v_contact is null
     or v_contact !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Enter a valid public club email.';
  end if;

  if v_instagram is null then
    raise exception 'Enter the club Instagram handle.';
  end if;

  if exists (
    select 1
    from unnest(v_days) as day_name
    where day_name not in (
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday'
    )
  ) then
    raise exception 'Meeting days contain an invalid day';
  end if;

  if v_logo is not null
     and v_logo not like (
       'club-profile-logos/' || v_user_id::text || '/' || p_club_id::text || '/%'
     )
     and not (
       public.has_system_role('SAC_ADMIN')
       and v_logo like ('club-profile-logos/%/' || p_club_id::text || '/%')
     ) then
    raise exception 'Invalid club logo storage path';
  end if;

  v_schedule := nullif(
    concat_ws(
      ' · ',
      nullif(array_to_string(v_days, ', '), ''),
      v_time,
      v_location
    ),
    ''
  );

  update public.clubs
  set
    name = v_name,
    description = v_description,
    contact_email = v_contact,
    instagram_handle = v_instagram,
    meeting_frequency = case
      when cardinality(v_days) > 0 then 'Weekly'
      else 'Other'
    end,
    meeting_days = v_days,
    meeting_time_details = v_time,
    meeting_location = v_location,
    meeting_schedule = v_schedule,
    logo_url = coalesce(v_logo, logo_url),
    updated_at = now()
  where id = p_club_id
  returning * into v_row;

  if not found then
    raise exception 'Club not found';
  end if;

  return v_row;
end;
$$;

revoke all on function public.update_owned_club_profile(
  uuid, text, text, text, text, text, text, text, text[], text, text
) from public, anon;

grant execute on function public.update_owned_club_profile(
  uuid, text, text, text, text, text, text, text, text[], text, text
) to authenticated;
