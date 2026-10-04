-- Restore Fraser Chefs as an inactive historical club identity (no duplicate).
-- Does not create active memberships or restore personal contact data.

do $restore$
declare
  v_club_id uuid;
  v_count int;
begin
  select count(*)::int into v_count
  from public.clubs
  where
    id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
    or lower(name) = lower('Fraser Chefs')
    or slug = 'fraser-chefs';

  if v_count > 1 then
    raise exception
      'Multiple Fraser Chefs club rows exist (%). Resolve duplicates before restore.',
      v_count;
  end if;

  select id into v_club_id
  from public.clubs
  where
    id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
    or lower(name) = lower('Fraser Chefs')
    or slug = 'fraser-chefs'
  order by (id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd') desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id,
      name,
      slug,
      short_description,
      description,
      contact_email,
      instagram_handle,
      meeting_location,
      meeting_schedule,
      status,
      created_by,
      source_label,
      eligible_for_reapplication,
      is_imported_seed,
      source_names
    )
    values (
      'adbff931-c030-4ac5-9ed6-78b9105a3dbd',
      'Fraser Chefs',
      'fraser-chefs',
      'Foster love for the culinary arts and explore cooking together.',
      'The purpose of Fraser Chefs is to foster love for the culinary arts and provide students with a platform to explore their passion for cooking. Our club aims to create an environment where students can develop essential culinary skills, discover diverse cuisines, and work together to create healthy eating habits.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Fraser chefs']::text[]
    )
    returning id into v_club_id;
  else
    perform set_config('app.allow_club_unarchive', 'on', true);

    update public.clubs
    set
      name = 'Fraser Chefs',
      slug = 'fraser-chefs',
      short_description = 'Foster love for the culinary arts and explore cooking together.',
      description = 'The purpose of Fraser Chefs is to foster love for the culinary arts and provide students with a platform to explore their passion for cooking. Our club aims to create an environment where students can develop essential culinary skills, discover diverse cuisines, and work together to create healthy eating habits.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      status = 'APPROVED',
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      is_imported_seed = true,
      source_names = array['Fraser chefs']::text[],
      archived_at = null,
      archived_by = null,
      last_active_school_year = null
    where id = v_club_id;
  end if;

  insert into public.club_school_years (club_id, school_year, status)
  values (v_club_id, '2026-2027', 'INACTIVE')
  on conflict (club_id, school_year) do update
  set
    status = 'INACTIVE',
    supervisor_due_at = null,
    activated_at = null;

  update public.club_memberships
  set status = 'INACTIVE'
  where club_id = v_club_id
    and status = 'ACTIVE';

  -- Current-year APPROVED reapps block the selector; preserve history as REJECTED.
  update public.club_reapplication_requests
  set
    status = 'REJECTED',
    review_notes = coalesce(
      nullif(btrim(coalesce(review_notes, '')), ''),
      'Closed when restoring Fraser Chefs as an inactive historical club for future reapplication.'
    ),
    reviewed_at = coalesce(reviewed_at, now())
  where club_id = v_club_id
    and school_year = '2026-2027'
    and status in (
      'SUBMITTED',
      'UNDER_REVIEW',
      'CHANGES_REQUESTED',
      'APPROVED'
    );

  insert into public.club_aliases (club_id, alias)
  values (v_club_id, 'Fraser chefs')
  on conflict do nothing;
end
$restore$;
