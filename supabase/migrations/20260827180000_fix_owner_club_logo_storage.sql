-- Fix club profile logo storage policies if an earlier revision used
-- has_club_role() inside storage RLS (often fails for owners).
-- Path must be: club-profile-logos/{auth.uid()}/{club_id}/...

drop policy if exists "club_logos_insert_profile_owner" on storage.objects;
drop policy if exists "club_logos_update_profile_owner" on storage.objects;
drop policy if exists "club_logos_delete_profile_owner" on storage.objects;

create policy "club_logos_insert_profile_owner"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'club-profile-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_logos_update_profile_owner"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'club-profile-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
)
with check (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'club-profile-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_logos_delete_profile_owner"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'club-profile-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

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
  v_short text;
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
  v_contact := nullif(lower(btrim(coalesce(p_contact_email, ''))), '');
  v_leader := nullif(btrim(coalesce(p_leader_contact_information, '')), '');
  v_short := nullif(btrim(coalesce(p_short_description, '')), '');
  v_logo := nullif(btrim(coalesce(p_logo_url, '')), '');

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
    short_description = coalesce(v_short, short_description),
    contact_email = v_contact,
    leader_contact_information = v_leader,
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
