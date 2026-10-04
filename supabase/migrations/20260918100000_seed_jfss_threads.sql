-- =========================================================
-- Sanitized Past Clubs seed (insert-only)
-- Add JFSS Threads (source name: Fraser Threads)
-- School year: 2026-2027
-- Does not rewrite existing clubs or reapplications.
-- =========================================================

-- Normalizations applied:
-- - Fraser Threads → JFSS Threads

do $$
declare
  v_year text := public.get_current_club_school_year();
begin
  if v_year is distinct from '2026-2027' then
    raise notice 'Seeding annual rows for setting year % (expected 2026-2027)', v_year;
  end if;
end $$;

-- JFSS Threads
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '59e4a761-9a6b-4a3f-993c-b80c3e2c3c43'
    or lower(name) = lower('JFSS Threads')
    or lower(name) = lower('Fraser Threads')
    or slug = 'jfss-threads'
    or slug = 'fraser-threads'
  order by (id = '59e4a761-9a6b-4a3f-993c-b80c3e2c3c43') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '59e4a761-9a6b-4a3f-993c-b80c3e2c3c43',
      'JFSS Threads',
      'jfss-threads',
      'Fraser threads is a non-profit merchandising club that connects with other school clubs within Fraser to design and manufacture custom merchandise like hoodies, sweaters and lanyards. every order comes with a two-page se',
      'Fraser threads is a non-profit merchandising club that connects with other school clubs within Fraser to design and manufacture custom merchandise like hoodies, sweaters and lanyards. every order comes with a two-page service agreement so that both sides are clear about responsibilities in the near future we plan to move purchases on to school cash online once everything is set up our goal is to make the process easy and stress free so that clubs can focus on their initiatives while we fill in unlike traditional fundraising the cost is covered by the people ordering the merchandise. This will let clubs focus on their own activities without worrying about the extra work like finding a high quality manufacturer or verifying.',
      null,
      null,
      'School Classroom',
      'Monthly After School',
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Fraser Threads']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS Threads',
      slug = 'jfss-threads',
      short_description = 'Fraser threads is a non-profit merchandising club that connects with other school clubs within Fraser to design and manufacture custom merchandise like hoodies, sweaters and lanyards. every order comes with a two-page se',
      description = 'Fraser threads is a non-profit merchandising club that connects with other school clubs within Fraser to design and manufacture custom merchandise like hoodies, sweaters and lanyards. every order comes with a two-page service agreement so that both sides are clear about responsibilities in the near future we plan to move purchases on to school cash online once everything is set up our goal is to make the process easy and stress free so that clubs can focus on their initiatives while we fill in unlike traditional fundraising the cost is covered by the people ordering the merchandise. This will let clubs focus on their own activities without worrying about the extra work like finding a high quality manufacturer or verifying.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = 'School Classroom',
      meeting_schedule = 'Monthly After School',
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Fraser Threads']::text[]
    where id = v_club_id;
  else
    -- Preserve manually managed profile data; only mark it eligible.
    update public.clubs
    set eligible_for_reapplication = true
    where id = v_club_id;
  end if;

  insert into public.club_school_years (club_id, school_year, status)
  values (v_club_id, '2026-2027', 'INACTIVE')
  on conflict (club_id, school_year) do nothing;

  insert into public.club_aliases (club_id, alias)
  values (v_club_id, 'Fraser Threads')
  on conflict do nothing;

end
$club_seed$;

do $$
declare
  v_resolved_count integer;
begin
  with expected(name, slug) as (
    values
      ('JFSS Threads', 'jfss-threads')
  ), resolved as (
    select distinct c.id
    from expected e
    join public.clubs c
      on lower(c.name) = lower(e.name) or c.slug = e.slug
    join public.club_school_years csy
      on csy.club_id = c.id
     and csy.school_year = '2026-2027'
    where c.eligible_for_reapplication = true
  )
  select count(*) into v_resolved_count from resolved;
  if v_resolved_count < 1 then
    raise exception 'Past clubs seed incomplete: expected 1 resolved canonical club, found %', v_resolved_count;
  end if;
end $$;
