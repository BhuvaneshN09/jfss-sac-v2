-- =========================================================
-- Storage buckets + block PENDING_SUPERVISOR operations
-- =========================================================

-- Extend application documents bucket for reapp attachments + PDF
update storage.buckets
set
  file_size_limit = 10485760,
  allowed_mime_types = array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ]
where id = 'club-application-documents';

-- Private supervisor documents
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'club-supervisor-documents',
  'club-supervisor-documents',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public club logos (approved logos may be read publicly)
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'club-logos',
  'club-logos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;


-- Refresh application-document path policies for reapplications/
drop policy if exists "club_docs_select_own" on storage.objects;
drop policy if exists "club_docs_insert_own" on storage.objects;
drop policy if exists "club_docs_update_own" on storage.objects;
drop policy if exists "club_docs_delete_own" on storage.objects;
drop policy if exists "club_docs_select_sac_admin" on storage.objects;
drop policy if exists "club_docs_select_sac_exec" on storage.objects;

create policy "club_docs_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications',
    'reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_docs_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications',
    'reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_docs_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications',
    'reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
)
with check (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications',
    'reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_docs_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-application-documents'
  and (storage.foldername(name))[1] in (
    'new-club-applications',
    'club-reapplications',
    'reapplications'
  )
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_docs_select_sac_admin"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-application-documents'
  and public.has_system_role('SAC_ADMIN')
);

create policy "club_docs_select_sac_exec"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-application-documents'
  and public.has_system_role('SAC_EXEC')
);


-- Supervisor documents policies
drop policy if exists "club_sup_docs_select_own" on storage.objects;
drop policy if exists "club_sup_docs_insert_own" on storage.objects;
drop policy if exists "club_sup_docs_delete_own" on storage.objects;
drop policy if exists "club_sup_docs_select_sac" on storage.objects;

create policy "club_sup_docs_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-supervisor-documents'
  and (storage.foldername(name))[1] = 'supervisor-requests'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_sup_docs_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-supervisor-documents'
  and (storage.foldername(name))[1] = 'supervisor-requests'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_sup_docs_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-supervisor-documents'
  and (storage.foldername(name))[1] = 'supervisor-requests'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_sup_docs_select_sac"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-supervisor-documents'
  and (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  )
);


-- Logo upload: applicants under reapplication-logos/{uid}/...
drop policy if exists "club_logos_select_public" on storage.objects;
drop policy if exists "club_logos_insert_own" on storage.objects;
drop policy if exists "club_logos_update_own" on storage.objects;
drop policy if exists "club_logos_delete_own" on storage.objects;
drop policy if exists "club_logos_select_sac" on storage.objects;

create policy "club_logos_select_public"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'club-logos');

create policy "club_logos_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'reapplication-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_logos_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'reapplication-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
)
with check (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'reapplication-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_logos_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'club-logos'
  and (storage.foldername(name))[1] = 'reapplication-logos'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

create policy "club_logos_select_sac"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'club-logos'
  and (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  )
);


-- Block announcements / events / funding while not ACTIVE
create or replace function public.assert_club_operations_allowed(p_club_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  v_status := public.get_club_current_annual_status(p_club_id);

  if v_status is distinct from 'ACTIVE' then
    raise exception
      'Club operations (announcements, events, funding) require ACTIVE annual status. Current status: %',
      coalesce(v_status, 'NONE')
      using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.assert_club_operations_allowed(uuid) from public;
grant execute on function public.assert_club_operations_allowed(uuid)
to authenticated;


create or replace function public.submit_club_event_request(
  p_club_id uuid,
  p_club_email text,
  p_event_name text,
  p_event_details text,
  p_requested_materials text,
  p_school_year text default '2026-2027'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_email text;
  v_request_id uuid;
  v_club_email text;
begin
  v_user_id := (select auth.uid());
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_club_id is null then
    raise exception 'Club ID is required';
  end if;

  if not public.has_club_role(p_club_id, array['OWNER', 'EXEC']) then
    raise exception
      'Only active club owners and executives may submit event requests'
      using errcode = '42501';
  end if;

  perform public.assert_club_operations_allowed(p_club_id);

  if not exists (
    select 1
    from public.clubs
    where id = p_club_id
      and status = 'APPROVED'
  ) then
    raise exception 'Club not found or unavailable';
  end if;

  select lower(btrim(email))
  into v_email
  from public.profiles
  where id = v_user_id;

  if v_email is null then
    raise exception 'Profile email is required';
  end if;

  v_club_email := lower(btrim(p_club_email));
  if v_club_email is null or v_club_email = '' then
    raise exception 'Club email is required';
  end if;

  if nullif(btrim(p_event_name), '') is null then
    raise exception 'Event name is required';
  end if;

  if nullif(btrim(p_event_details), '') is null then
    raise exception 'Event details are required';
  end if;

  if nullif(btrim(p_requested_materials), '') is null then
    raise exception 'Requested materials are required';
  end if;

  insert into public.club_event_requests (
    club_id,
    submitted_by,
    respondent_email,
    school_year,
    club_email,
    event_name,
    event_details,
    requested_materials,
    status,
    submitted_at
  )
  values (
    p_club_id,
    v_user_id,
    v_email,
    coalesce(nullif(btrim(p_school_year), ''), public.get_current_club_school_year()),
    v_club_email,
    btrim(p_event_name),
    btrim(p_event_details),
    btrim(p_requested_materials),
    'SUBMITTED',
    now()
  )
  returning id into v_request_id;

  return v_request_id;
end;
$$;


-- Guard announcement inserts for club-scoped announcements
create or replace function public.guard_announcement_club_active()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.club_id is not null then
    perform public.assert_club_operations_allowed(new.club_id);
  end if;
  return new;
end;
$$;

drop trigger if exists guard_announcement_club_active
on public.announcements;
create trigger guard_announcement_club_active
before insert
on public.announcements
for each row
when (new.club_id is not null)
execute function public.guard_announcement_club_active();


-- Admin listing helpers for annual categories
create or replace function public.list_clubs_by_annual_status(
  p_status text
)
returns table (
  club_id uuid,
  name text,
  slug text,
  annual_status text,
  school_year text,
  supervisor_due_at timestamptz,
  is_overdue boolean,
  eligible_for_reapplication boolean,
  aliases text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_year text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not (
    public.has_system_role('SAC_ADMIN')
    or public.has_system_role('SAC_EXEC')
  ) then
    raise exception 'SAC_ADMIN or SAC_EXEC required' using errcode = '42501';
  end if;

  v_year := public.get_current_club_school_year();

  return query
  select
    c.id,
    c.name,
    c.slug,
    csy.status,
    csy.school_year,
    csy.supervisor_due_at,
    (
      csy.status = 'PENDING_SUPERVISOR'
      and csy.supervisor_due_at is not null
      and csy.supervisor_due_at < now()
    ) as is_overdue,
    c.eligible_for_reapplication,
    coalesce(
      (
        select array_agg(a.alias order by a.alias)
        from public.club_aliases a
        where a.club_id = c.id
      ),
      '{}'::text[]
    )
  from public.clubs c
  join public.club_school_years csy
    on csy.club_id = c.id
   and csy.school_year = v_year
  where csy.status = upper(btrim(p_status))
  order by c.name;
end;
$$;

revoke all on function public.list_clubs_by_annual_status(text)
from public, anon;
grant execute on function public.list_clubs_by_annual_status(text)
to authenticated;


-- Patch create_announcement to require ACTIVE annual status for club posts
create or replace function public.create_announcement(
  p_title text,
  p_body text,
  p_summary text default null,
  p_image_url text default null,
  p_club_id uuid default null,
  p_action text default 'DRAFT',
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_action text;
  v_status text;
  v_announcement_id uuid;

  v_is_admin boolean;
  v_is_advisor boolean;
  v_is_club_owner boolean;
begin
  v_user_id := (select auth.uid());

  if v_user_id is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  v_action := upper(btrim(p_action));

  v_is_admin := public.has_system_role('SAC_ADMIN');

  v_is_advisor := public.has_system_role('FACULTY_ADVISOR');

  v_is_club_owner :=
    p_club_id is not null
    and public.has_club_role(
      p_club_id,
      array['OWNER']
    );

  if p_club_id is not null then
    perform public.assert_club_operations_allowed(p_club_id);
  end if;

  if p_club_id is not null
     and not exists (
       select 1
       from public.clubs
       where id = p_club_id
         and status = 'APPROVED'
     ) then
    raise exception 'The selected club is not available';
  end if;

  if v_is_admin or v_is_advisor then
    if v_action = 'DRAFT' then
      v_status := 'DRAFT';
    elsif v_action = 'PUBLISH' then
      v_status := 'PUBLISHED';
    else
      raise exception
        'Staff announcements must be saved as DRAFT or PUBLISH';
    end if;
  else
    if not v_is_club_owner then
      raise exception
        'Only a club owner may create an announcement for this club'
        using errcode = '42501';
    end if;

    if v_action = 'DRAFT' then
      v_status := 'DRAFT';
    elsif v_action = 'SUBMIT' then
      v_status := 'SUBMITTED';
    else
      raise exception
        'Club-owner announcements must be DRAFT or SUBMIT';
    end if;
  end if;

  insert into public.announcements (
    club_id,
    title,
    summary,
    body,
    image_url,
    status,
    created_by,
    submitted_at,
    published_at,
    expires_at
  )
  values (
    p_club_id,
    btrim(p_title),
    nullif(btrim(coalesce(p_summary, '')), ''),
    btrim(p_body),
    nullif(btrim(coalesce(p_image_url, '')), ''),
    v_status,
    v_user_id,
    case when v_status = 'SUBMITTED' then now() else null end,
    case when v_status = 'PUBLISHED' then now() else null end,
    p_expires_at
  )
  returning id into v_announcement_id;

  return v_announcement_id;
end;
$$;
