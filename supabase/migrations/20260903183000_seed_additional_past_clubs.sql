-- =========================================================
-- Sanitized Past Clubs seed (generated; do not hand-edit)
-- Additional past clubs from 2025-2026 reapplication form (9 clubs)
-- School year: 2026-2027
-- Generated: 2026-09-03T18:46:34.407Z
-- =========================================================

-- Normalizations applied:
-- - Ceative Writing Club → Creative Writing Club
-- - Fraser chefs → Fraser Chefs
-- - Fraser ESports → Fraser Esports
-- - John Fraser's Law CLub → John Fraser's Law Club
-- - John Fraser Secondary School's Badminton Club → Badminton Club
-- - MERGE F.A.C.E. (Fraser Ambassadors of Community Engagement) + Fraser Aces → Fraser Aces (F.A.C.E.)

do $$
declare
  v_year text := public.get_current_club_school_year();
begin
  if v_year is distinct from '2026-2027' then
    raise notice 'Seeding annual rows for setting year % (expected 2026-2027)', v_year;
  end if;
end $$;

-- Badminton Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'aef4fb29-ab6f-41ae-8a81-405dd584ca8c'
    or lower(name) = lower('Badminton Club')
    or slug = 'badminton-club'
  order by (id = 'aef4fb29-ab6f-41ae-8a81-405dd584ca8c') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'aef4fb29-ab6f-41ae-8a81-405dd584ca8c',
      'Badminton Club',
      'badminton-club',
      'The Badminton Club provides students with a fun and active way to spend their lunch break. By setting up courts, we create an inclusive space where anyone can play, regardless of skill level. The club encourages physical',
      'The Badminton Club provides students with a fun and active way to spend their lunch break. By setting up courts, we create an inclusive space where anyone can play, regardless of skill level. The club encourages physical activity, teamwork, and stress relief while giving students a chance to socialize in a positive environment. It also helps those interested in badminton get more involved, improve their skills, and enjoy the sport as part of the school community.',
      null,
      'jfss_badminton',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['John Fraser Secondary School''s Badminton Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Badminton Club',
      slug = 'badminton-club',
      short_description = 'The Badminton Club provides students with a fun and active way to spend their lunch break. By setting up courts, we create an inclusive space where anyone can play, regardless of skill level. The club encourages physical',
      description = 'The Badminton Club provides students with a fun and active way to spend their lunch break. By setting up courts, we create an inclusive space where anyone can play, regardless of skill level. The club encourages physical activity, teamwork, and stress relief while giving students a chance to socialize in a positive environment. It also helps those interested in badminton get more involved, improve their skills, and enjoy the sport as part of the school community.',
      contact_email = null,
      instagram_handle = 'jfss_badminton',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['John Fraser Secondary School''s Badminton Club']::text[]
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
  values (v_club_id, 'John Fraser Secondary School''s Badminton Club')
  on conflict do nothing;

end
$club_seed$;

-- Computer Science Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'aeaa3871-8433-4581-a7e9-75acfa404cd2'
    or lower(name) = lower('Computer Science Club')
    or slug = 'computer-science-club'
  order by (id = 'aeaa3871-8433-4581-a7e9-75acfa404cd2') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'aeaa3871-8433-4581-a7e9-75acfa404cd2',
      'Computer Science Club',
      'computer-science-club',
      'To foster interest in computer science and technology by building a collaborative community of like-minded peers. The club provides opportunities to stay informed about current events in the field, while also developing ',
      'To foster interest in computer science and technology by building a collaborative community of like-minded peers. The club provides opportunities to stay informed about current events in the field, while also developing competition and project-related skills.',
      null,
      'jfss_cs',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Computer Science Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Computer Science Club',
      slug = 'computer-science-club',
      short_description = 'To foster interest in computer science and technology by building a collaborative community of like-minded peers. The club provides opportunities to stay informed about current events in the field, while also developing ',
      description = 'To foster interest in computer science and technology by building a collaborative community of like-minded peers. The club provides opportunities to stay informed about current events in the field, while also developing competition and project-related skills.',
      contact_email = null,
      instagram_handle = 'jfss_cs',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Computer Science Club']::text[]
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

end
$club_seed$;

-- Fraser Dance Crew
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '0de51109-3410-4a4f-b4e3-0397fed507e0'
    or lower(name) = lower('Fraser Dance Crew')
    or slug = 'fraser-dance-crew'
  order by (id = '0de51109-3410-4a4f-b4e3-0397fed507e0') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '0de51109-3410-4a4f-b4e3-0397fed507e0',
      'Fraser Dance Crew',
      'fraser-dance-crew',
      'Fraser Dance Crew''s purpose is to make dance fun and accessible to everyone at Fraser.',
      'Fraser Dance Crew''s purpose is to make dance fun and accessible to everyone at Fraser.',
      'thefraserdancecrew@gmail.com',
      'fraserdancecrew_',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Fraser Dance Crew']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Fraser Dance Crew',
      slug = 'fraser-dance-crew',
      short_description = 'Fraser Dance Crew''s purpose is to make dance fun and accessible to everyone at Fraser.',
      description = 'Fraser Dance Crew''s purpose is to make dance fun and accessible to everyone at Fraser.',
      contact_email = 'thefraserdancecrew@gmail.com',
      instagram_handle = 'fraserdancecrew_',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Fraser Dance Crew']::text[]
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

end
$club_seed$;

-- FraserHacks
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '68a0d80f-3e84-4866-a35c-d0f35aa27364'
    or lower(name) = lower('FraserHacks')
    or slug = 'fraserhacks'
  order by (id = '68a0d80f-3e84-4866-a35c-d0f35aa27364') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '68a0d80f-3e84-4866-a35c-d0f35aa27364',
      'FraserHacks',
      'fraserhacks',
      'To host a hackathon in the school.',
      'To host a hackathon in the school.',
      'fraserhacks24@gmail.com',
      'fraser.hacks',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['FraserHacks']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'FraserHacks',
      slug = 'fraserhacks',
      short_description = 'To host a hackathon in the school.',
      description = 'To host a hackathon in the school.',
      contact_email = 'fraserhacks24@gmail.com',
      instagram_handle = 'fraser.hacks',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['FraserHacks']::text[]
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

end
$club_seed$;

-- JFAS - John Fraser Advocacy Society
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '391463fc-7d77-4411-b201-d194b2770794'
    or lower(name) = lower('JFAS - John Fraser Advocacy Society')
    or slug = 'jfas-john-fraser-advocacy-society'
  order by (id = '391463fc-7d77-4411-b201-d194b2770794') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '391463fc-7d77-4411-b201-d194b2770794',
      'JFAS - John Fraser Advocacy Society',
      'jfas-john-fraser-advocacy-society',
      'JFAS strives to build a space where all students feel represented and heard in our school community.',
      'JFAS strives to build a space where all students feel represented and heard in our school community.',
      'johnfraseradvocacysociety@gmail.com',
      'johnfraseradvocacysociety',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFAS - John Fraser Advocacy Society']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFAS - John Fraser Advocacy Society',
      slug = 'jfas-john-fraser-advocacy-society',
      short_description = 'JFAS strives to build a space where all students feel represented and heard in our school community.',
      description = 'JFAS strives to build a space where all students feel represented and heard in our school community.',
      contact_email = 'johnfraseradvocacysociety@gmail.com',
      instagram_handle = 'johnfraseradvocacysociety',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFAS - John Fraser Advocacy Society']::text[]
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

end
$club_seed$;

-- JFSS Physics Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '4420f2b2-4552-4cfe-81d3-fc31a0e5d706'
    or lower(name) = lower('JFSS Physics Club')
    or slug = 'jfss-physics-club'
  order by (id = '4420f2b2-4552-4cfe-81d3-fc31a0e5d706') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '4420f2b2-4552-4cfe-81d3-fc31a0e5d706',
      'JFSS Physics Club',
      'jfss-physics-club',
      'Conduct fun experiments about physics and teach related concepts.',
      'Conduct fun experiments about physics and teach related concepts.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFSS Physics Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS Physics Club',
      slug = 'jfss-physics-club',
      short_description = 'Conduct fun experiments about physics and teach related concepts.',
      description = 'Conduct fun experiments about physics and teach related concepts.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFSS Physics Club']::text[]
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

end
$club_seed$;

-- JFSS Pre-Vet Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'eb93150f-c540-4cb1-a603-ef779c1b4ec2'
    or lower(name) = lower('JFSS Pre-Vet Club')
    or slug = 'jfss-pre-vet-club'
  order by (id = 'eb93150f-c540-4cb1-a603-ef779c1b4ec2') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'eb93150f-c540-4cb1-a603-ef779c1b4ec2',
      'JFSS Pre-Vet Club',
      'jfss-pre-vet-club',
      'JFSS Pre-vet is a student led club created for students with a strong interest in animals and veterinary medicine. It serves as a supportive community for members who are exploring future careers in animal health and rel',
      'JFSS Pre-vet is a student led club created for students with a strong interest in animals and veterinary medicine. It serves as a supportive community for members who are exploring future careers in animal health and related sciences. The club provides educational opportunities that allow students to learn more about veterinary pathways, animal care, and real-world applications of veterinary science.',
      null,
      'jfssprevetclub',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFSS Pre-Vet Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS Pre-Vet Club',
      slug = 'jfss-pre-vet-club',
      short_description = 'JFSS Pre-vet is a student led club created for students with a strong interest in animals and veterinary medicine. It serves as a supportive community for members who are exploring future careers in animal health and rel',
      description = 'JFSS Pre-vet is a student led club created for students with a strong interest in animals and veterinary medicine. It serves as a supportive community for members who are exploring future careers in animal health and related sciences. The club provides educational opportunities that allow students to learn more about veterinary pathways, animal care, and real-world applications of veterinary science.',
      contact_email = null,
      instagram_handle = 'jfssprevetclub',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFSS Pre-Vet Club']::text[]
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

end
$club_seed$;

-- Positive Space
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '57d9b692-68cb-4967-aefb-bdf6f1c1adbe'
    or lower(name) = lower('Positive Space')
    or slug = 'positive-space'
  order by (id = '57d9b692-68cb-4967-aefb-bdf6f1c1adbe') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '57d9b692-68cb-4967-aefb-bdf6f1c1adbe',
      'Positive Space',
      'positive-space',
      'The purpose is to create a safe space for students of all identities, sexualities, and genders. To spread awareness, and to also host social events that everyone is welcome to enjoy and feel comfortable in.',
      'The purpose is to create a safe space for students of all identities, sexualities, and genders. To spread awareness, and to also host social events that everyone is welcome to enjoy and feel comfortable in.',
      null,
      'positivespacejfss',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Positive Space']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Positive Space',
      slug = 'positive-space',
      short_description = 'The purpose is to create a safe space for students of all identities, sexualities, and genders. To spread awareness, and to also host social events that everyone is welcome to enjoy and feel comfortable in.',
      description = 'The purpose is to create a safe space for students of all identities, sexualities, and genders. To spread awareness, and to also host social events that everyone is welcome to enjoy and feel comfortable in.',
      contact_email = null,
      instagram_handle = 'positivespacejfss',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Positive Space']::text[]
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

end
$club_seed$;

-- Project Link
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '71591257-51df-451e-98e7-07fe84541c97'
    or lower(name) = lower('Project Link')
    or slug = 'project-link'
  order by (id = '71591257-51df-451e-98e7-07fe84541c97') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '71591257-51df-451e-98e7-07fe84541c97',
      'Project Link',
      'project-link',
      'Spreading awareness about health care and economical factors on a global scale.',
      'Spreading awareness about health care and economical factors on a global scale.',
      'jfss.project.link@gmail.com',
      'jfss.project.link',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Project Link']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Project Link',
      slug = 'project-link',
      short_description = 'Spreading awareness about health care and economical factors on a global scale.',
      description = 'Spreading awareness about health care and economical factors on a global scale.',
      contact_email = 'jfss.project.link@gmail.com',
      instagram_handle = 'jfss.project.link',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Project Link']::text[]
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

end
$club_seed$;

do $$
declare
  v_resolved_count integer;
begin
  with expected(name, slug) as (
    values
      ('Badminton Club', 'badminton-club'),
      ('Computer Science Club', 'computer-science-club'),
      ('Fraser Dance Crew', 'fraser-dance-crew'),
      ('FraserHacks', 'fraserhacks'),
      ('JFAS - John Fraser Advocacy Society', 'jfas-john-fraser-advocacy-society'),
      ('JFSS Physics Club', 'jfss-physics-club'),
      ('JFSS Pre-Vet Club', 'jfss-pre-vet-club'),
      ('Positive Space', 'positive-space'),
      ('Project Link', 'project-link')
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
  if v_resolved_count < 9 then
    raise exception 'Past clubs seed incomplete: expected 9 resolved canonical clubs, found %', v_resolved_count;
  end if;
end $$;
