-- Align update_owned_club_profile validation with the create-club form:
-- - description: min 10 chars, no upper length limit
-- - no short_description updates
-- - club contact is free text (email or Instagram), required min 3
-- - leader contact optional, no arbitrary 500 cap

create or replace function public.update_owned_club_profile(
  p_club_id uuid,
  p_name text,
  p_description text,
  p_contact_email text default null,
  p_leader_contact_information text default null,
  p_short_description text default null,
  p_logo_url text default null
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
  v_logo text;
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
  -- Stored in contact_email (must be lowercase per table constraint).
  -- Free text like create-form club contact (email or Instagram).
  v_contact := nullif(lower(btrim(coalesce(p_contact_email, ''))), '');
  v_leader := nullif(btrim(coalesce(p_leader_contact_information, '')), '');
  v_logo := nullif(btrim(coalesce(p_logo_url, '')), '');

  if char_length(v_name) < 2 then
    raise exception 'Enter your club name.';
  end if;

  if char_length(v_description) < 10 then
    raise exception
      'Provide a detailed club description (at least 10 characters).';
  end if;

  if v_contact is null or char_length(v_contact) < 3 then
    raise exception
      'Provide club contact information such as email or Instagram.';
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

  update public.clubs
  set
    name = v_name,
    description = v_description,
    contact_email = v_contact,
    leader_contact_information = v_leader,
    logo_url = coalesce(v_logo, logo_url),
    updated_at = now()
  where id = p_club_id
  returning * into v_row;

  if not found then
    raise exception 'Club not found';
  end if;

  -- UUID, slug, and short_description are intentionally not updated.
  return v_row;
end;
$$;
