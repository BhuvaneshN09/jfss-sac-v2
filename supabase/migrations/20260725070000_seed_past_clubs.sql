-- =========================================================
-- Sanitized Past Clubs seed (generated; do not hand-edit)
-- Source rows: 74 → canonical clubs: 73
-- School year: 2026-2027
-- Generated: 2026-07-25T00:58:27.292Z
-- =========================================================

-- Normalizations applied:
-- - Ceative Writing Club → Creative Writing Club
-- - Fraser chefs → Fraser Chefs
-- - Fraser ESports → Fraser Esports
-- - John Fraser's Law CLub → John Fraser's Law Club
-- - MERGE F.A.C.E. (Fraser Ambassadors of Community Engagement) + Fraser Aces → Fraser Aces (F.A.C.E.)

do $$
declare
  v_year text := public.get_current_club_school_year();
begin
  if v_year is distinct from '2026-2027' then
    raise notice 'Seeding annual rows for setting year % (expected 2026-2027)', v_year;
  end if;
end $$;

-- Fraser Aces (F.A.C.E.)
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '7da1cb39-2076-4872-854b-6c8946ffa949'
    or lower(name) = lower('Fraser Aces (F.A.C.E.)')
    or slug = 'fraser-aces-face'
  order by (id = '7da1cb39-2076-4872-854b-6c8946ffa949') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '7da1cb39-2076-4872-854b-6c8946ffa949',
      'Fraser Aces (F.A.C.E.)',
      'fraser-aces-face',
      'FACE acts as the bridge between the community and JFSS, hosting events such as Parent Teacher Interview Night, Post-Secondary Night, Co-op Fair, and much more.',
      'FACE acts as the bridge between the community and JFSS, hosting events such as Parent Teacher Interview Night, Post-Secondary Night, Co-op Fair, and much more.',
      null,
      'fraseraces',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['F.A.C.E. (Fraser Ambassadors of Community Engagement)', 'Fraser Aces']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Fraser Aces (F.A.C.E.)',
      slug = 'fraser-aces-face',
      short_description = 'FACE acts as the bridge between the community and JFSS, hosting events such as Parent Teacher Interview Night, Post-Secondary Night, Co-op Fair, and much more.',
      description = 'FACE acts as the bridge between the community and JFSS, hosting events such as Parent Teacher Interview Night, Post-Secondary Night, Co-op Fair, and much more.',
      contact_email = null,
      instagram_handle = 'fraseraces',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['F.A.C.E. (Fraser Ambassadors of Community Engagement)', 'Fraser Aces']::text[]
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
  values (v_club_id, 'Fraser Aces')
  on conflict do nothing;

  insert into public.club_aliases (club_id, alias)
  values (v_club_id, 'F.A.C.E. (Fraser Ambassadors of Community Engagement)')
  on conflict do nothing;

  insert into public.club_aliases (club_id, alias)
  values (v_club_id, 'F.A.C.E.')
  on conflict do nothing;

end
$club_seed$;

-- Aid4Need
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'e0cc7d8c-c5f0-4fb5-8d20-b012e8396565'
    or lower(name) = lower('Aid4Need')
    or slug = 'aid4need'
  order by (id = 'e0cc7d8c-c5f0-4fb5-8d20-b012e8396565') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'e0cc7d8c-c5f0-4fb5-8d20-b012e8396565',
      'Aid4Need',
      'aid4need',
      'Aid4Need is a nonprofit organization dedicated to empowering youth through community service. Aid4Need John Fraser hosts monthly workshops, such as creating appreciation cards for hospital staff, veterans, and more. Thes',
      'Aid4Need is a nonprofit organization dedicated to empowering youth through community service. Aid4Need John Fraser hosts monthly workshops, such as creating appreciation cards for hospital staff, veterans, and more. These events feature games, music, and snacks—a perfect way to bring our school community closer while making a positive impact.  Participants can also earn valuable volunteer hours, with every 2 cards they make counting as one hour of service.',
      'aid4need.jfss@gmail.com',
      'aid4need_jfss',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Aid4Need']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Aid4Need',
      slug = 'aid4need',
      short_description = 'Aid4Need is a nonprofit organization dedicated to empowering youth through community service. Aid4Need John Fraser hosts monthly workshops, such as creating appreciation cards for hospital staff, veterans, and more. Thes',
      description = 'Aid4Need is a nonprofit organization dedicated to empowering youth through community service. Aid4Need John Fraser hosts monthly workshops, such as creating appreciation cards for hospital staff, veterans, and more. These events feature games, music, and snacks—a perfect way to bring our school community closer while making a positive impact.  Participants can also earn valuable volunteer hours, with every 2 cards they make counting as one hour of service.',
      contact_email = 'aid4need.jfss@gmail.com',
      instagram_handle = 'aid4need_jfss',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Aid4Need']::text[]
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

-- Announcements Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '57647425-1eec-4709-969a-70c15ed85817'
    or lower(name) = lower('Announcements Club')
    or slug = 'announcements-club'
  order by (id = '57647425-1eec-4709-969a-70c15ed85817') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '57647425-1eec-4709-969a-70c15ed85817',
      'Announcements Club',
      'announcements-club',
      'Our club is responsible for the morning announcements every morning and afternoon! We train our members to use the system to play music, as well as share announcements about upcoming events and dates to our school body! ',
      'Our club is responsible for the morning announcements every morning and afternoon! We train our members to use the system to play music, as well as share announcements about upcoming events and dates to our school body! It''s an open club, so all are welcome to join as long as they can come early to set up :)',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Announcements Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Announcements Club',
      slug = 'announcements-club',
      short_description = 'Our club is responsible for the morning announcements every morning and afternoon! We train our members to use the system to play music, as well as share announcements about upcoming events and dates to our school body! ',
      description = 'Our club is responsible for the morning announcements every morning and afternoon! We train our members to use the system to play music, as well as share announcements about upcoming events and dates to our school body! It''s an open club, so all are welcome to join as long as they can come early to set up :)',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Announcements Club']::text[]
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

-- AP Student Society
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '3274ac9e-19d7-4414-b4ab-d22387d2f3b5'
    or lower(name) = lower('AP Student Society')
    or slug = 'ap-student-society'
  order by (id = '3274ac9e-19d7-4414-b4ab-d22387d2f3b5') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '3274ac9e-19d7-4414-b4ab-d22387d2f3b5',
      'AP Student Society',
      'ap-student-society',
      'Liaise between the AP students in each grade and the AP coordinator',
      'Liaise between the AP students in each grade and the AP coordinator',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['AP Student Society']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'AP Student Society',
      slug = 'ap-student-society',
      short_description = 'Liaise between the AP students in each grade and the AP coordinator',
      description = 'Liaise between the AP students in each grade and the AP coordinator',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['AP Student Society']::text[]
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

-- Arts Council
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '7f2e5c41-5d5b-4af7-b387-76f2983b9897'
    or lower(name) = lower('Arts Council')
    or slug = 'arts-council'
  order by (id = '7f2e5c41-5d5b-4af7-b387-76f2983b9897') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '7f2e5c41-5d5b-4af7-b387-76f2983b9897',
      'Arts Council',
      'arts-council',
      'Arts Council is dedicated to fostering a safe, inclusive, and imaginative environment for all students to explore the Arts! As representatives of the John Fraser''s Art Department, we are committed to represent and promot',
      'Arts Council is dedicated to fostering a safe, inclusive, and imaginative environment for all students to explore the Arts! As representatives of the John Fraser''s Art Department, we are committed to represent and promote all strands of the Arts—Drama, Dance, Music, Visual and Media Arts. Through curating creative spaces and events accessible to all Fraser students, we are able to bring the joy of the Arts to everyone!',
      'jfssarts@gmail.com',
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Arts Council']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Arts Council',
      slug = 'arts-council',
      short_description = 'Arts Council is dedicated to fostering a safe, inclusive, and imaginative environment for all students to explore the Arts! As representatives of the John Fraser''s Art Department, we are committed to represent and promot',
      description = 'Arts Council is dedicated to fostering a safe, inclusive, and imaginative environment for all students to explore the Arts! As representatives of the John Fraser''s Art Department, we are committed to represent and promote all strands of the Arts—Drama, Dance, Music, Visual and Media Arts. Through curating creative spaces and events accessible to all Fraser students, we are able to bring the joy of the Arts to everyone!',
      contact_email = 'jfssarts@gmail.com',
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Arts Council']::text[]
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

-- Aviation Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '038ce12b-08a0-4ffe-adbe-45d55c35484d'
    or lower(name) = lower('Aviation Club')
    or slug = 'aviation-club'
  order by (id = '038ce12b-08a0-4ffe-adbe-45d55c35484d') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '038ce12b-08a0-4ffe-adbe-45d55c35484d',
      'Aviation Club',
      'aviation-club',
      'every meeting we talk about aviation related things like what is g force and what are flaps how can they help with planes taking off etc Club meeting time: we have club meetings bi-weekly during lunch at 11:28',
      'every meeting we talk about aviation related things like what is g force and what are flaps how can they help with planes taking off etc Club meeting time: we have club meetings bi-weekly during lunch at 11:28',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Aviation Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Aviation Club',
      slug = 'aviation-club',
      short_description = 'every meeting we talk about aviation related things like what is g force and what are flaps how can they help with planes taking off etc Club meeting time: we have club meetings bi-weekly during lunch at 11:28',
      description = 'every meeting we talk about aviation related things like what is g force and what are flaps how can they help with planes taking off etc Club meeting time: we have club meetings bi-weekly during lunch at 11:28',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Aviation Club']::text[]
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

-- AV Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'cc6b2064-8f7a-472e-bfec-863830331fc6'
    or lower(name) = lower('AV Club')
    or slug = 'av-club'
  order by (id = 'cc6b2064-8f7a-472e-bfec-863830331fc6') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'cc6b2064-8f7a-472e-bfec-863830331fc6',
      'AV Club',
      'av-club',
      'The John Fraser AV Club is the team behind the scenes that brings school events to life. From assembilies and concerts to guest speakers,we manage the microphones,sound systems and lighting to ensure everything runs smoo',
      'The John Fraser AV Club is the team behind the scenes that brings school events to life. From assembilies and concerts to guest speakers,we manage the microphones,sound systems and lighting to ensure everything runs smoothly. Or goal is to create a professtional and seemless expereice for every event while giving students the chance to learn valuable technical and teamwork skills.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['AV Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'AV Club',
      slug = 'av-club',
      short_description = 'The John Fraser AV Club is the team behind the scenes that brings school events to life. From assembilies and concerts to guest speakers,we manage the microphones,sound systems and lighting to ensure everything runs smoo',
      description = 'The John Fraser AV Club is the team behind the scenes that brings school events to life. From assembilies and concerts to guest speakers,we manage the microphones,sound systems and lighting to ensure everything runs smoothly. Or goal is to create a professtional and seemless expereice for every event while giving students the chance to learn valuable technical and teamwork skills.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['AV Club']::text[]
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

-- Black Student and Allies Association
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '39367973-a671-478f-b1ec-04f6a22d27d3'
    or lower(name) = lower('Black Student and Allies Association')
    or slug = 'black-student-and-allies-association'
  order by (id = '39367973-a671-478f-b1ec-04f6a22d27d3') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '39367973-a671-478f-b1ec-04f6a22d27d3',
      'Black Student and Allies Association',
      'black-student-and-allies-association',
      'The BSAA is a space where students can come together to talk about the issues affecting our communities in a safe and supportive environment. We discuss things like racism, social justice, mental health, and economic ine',
      'The BSAA is a space where students can come together to talk about the issues affecting our communities in a safe and supportive environment. We discuss things like racism, social justice, mental health, and economic inequality, while also learning how to support each other better. The club helps us build understanding across different backgrounds.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Black Student and Allies Association']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Black Student and Allies Association',
      slug = 'black-student-and-allies-association',
      short_description = 'The BSAA is a space where students can come together to talk about the issues affecting our communities in a safe and supportive environment. We discuss things like racism, social justice, mental health, and economic ine',
      description = 'The BSAA is a space where students can come together to talk about the issues affecting our communities in a safe and supportive environment. We discuss things like racism, social justice, mental health, and economic inequality, while also learning how to support each other better. The club helps us build understanding across different backgrounds.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Black Student and Allies Association']::text[]
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

-- Creative Writing Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '51fd639d-cdfc-4447-ab3f-3815e2a5b2fb'
    or lower(name) = lower('Creative Writing Club')
    or slug = 'creative-writing-club'
  order by (id = '51fd639d-cdfc-4447-ab3f-3815e2a5b2fb') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '51fd639d-cdfc-4447-ab3f-3815e2a5b2fb',
      'Creative Writing Club',
      'creative-writing-club',
      'The Creative Writing Club at JFSS is a club where members come together to explore, further develop and improve their writing skills. It provides opportunities for students to practice different forms of writing, whether',
      'The Creative Writing Club at JFSS is a club where members come together to explore, further develop and improve their writing skills. It provides opportunities for students to practice different forms of writing, whether you''re new to it or already enjoy it, including stories, poems, and essays. We plan on hosting activities like writing challenges, and competitions to help members develop their creativity and build confidence in their writing. It’s a supportive environment for students to share ideas, receive feedback, and grow as writers.',
      null,
      'jfsscwc',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Ceative Writing Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Creative Writing Club',
      slug = 'creative-writing-club',
      short_description = 'The Creative Writing Club at JFSS is a club where members come together to explore, further develop and improve their writing skills. It provides opportunities for students to practice different forms of writing, whether',
      description = 'The Creative Writing Club at JFSS is a club where members come together to explore, further develop and improve their writing skills. It provides opportunities for students to practice different forms of writing, whether you''re new to it or already enjoy it, including stories, poems, and essays. We plan on hosting activities like writing challenges, and competitions to help members develop their creativity and build confidence in their writing. It’s a supportive environment for students to share ideas, receive feedback, and grow as writers.',
      contact_email = null,
      instagram_handle = 'jfsscwc',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Ceative Writing Club']::text[]
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
  values (v_club_id, 'Ceative Writing Club')
  on conflict do nothing;

end
$club_seed$;

-- Chapter One
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'd7b97b23-06c4-48e4-82e3-a01d1d8bd1c3'
    or lower(name) = lower('Chapter One')
    or slug = 'chapter-one'
  order by (id = 'd7b97b23-06c4-48e4-82e3-a01d1d8bd1c3') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'd7b97b23-06c4-48e4-82e3-a01d1d8bd1c3',
      'Chapter One',
      'chapter-one',
      'Chapter One is JFSS’s book club, where we read books every month and come together to discuss them.',
      'Chapter One is JFSS’s book club, where we read books every month and come together to discuss them.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Chapter One']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Chapter One',
      slug = 'chapter-one',
      short_description = 'Chapter One is JFSS’s book club, where we read books every month and come together to discuss them.',
      description = 'Chapter One is JFSS’s book club, where we read books every month and come together to discuss them.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Chapter One']::text[]
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

-- Chemistry Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '5b8d3555-ef39-4b10-949d-986671e05611'
    or lower(name) = lower('Chemistry Club')
    or slug = 'chemistry-club'
  order by (id = '5b8d3555-ef39-4b10-949d-986671e05611') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '5b8d3555-ef39-4b10-949d-986671e05611',
      'Chemistry Club',
      'chemistry-club',
      'Chemistry Club is a student-led club, aiming to promote interest in the amazing field of chemistry, simulate scientific curiosity, and provide an atmosphere to discuss anything related to chemistry that members find exci',
      'Chemistry Club is a student-led club, aiming to promote interest in the amazing field of chemistry, simulate scientific curiosity, and provide an atmosphere to discuss anything related to chemistry that members find exciting.',
      null,
      'jfss.chemistryclub',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Chemistry Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Chemistry Club',
      slug = 'chemistry-club',
      short_description = 'Chemistry Club is a student-led club, aiming to promote interest in the amazing field of chemistry, simulate scientific curiosity, and provide an atmosphere to discuss anything related to chemistry that members find exci',
      description = 'Chemistry Club is a student-led club, aiming to promote interest in the amazing field of chemistry, simulate scientific curiosity, and provide an atmosphere to discuss anything related to chemistry that members find exciting.',
      contact_email = null,
      instagram_handle = 'jfss.chemistryclub',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Chemistry Club']::text[]
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

-- Christian Club (Project 153)
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '74341ad9-eded-4eab-b61d-737432d3045a'
    or lower(name) = lower('Christian Club (Project 153)')
    or slug = 'christian-club-project-153'
  order by (id = '74341ad9-eded-4eab-b61d-737432d3045a') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '74341ad9-eded-4eab-b61d-737432d3045a',
      'Christian Club (Project 153)',
      'christian-club-project-153',
      'Our club is dedicated to establishing a community of Christians in our school body. Each week, we do some games, a bible study, and small groups to help learn more about God each week. All are welcome to join, as we are ',
      'Our club is dedicated to establishing a community of Christians in our school body. Each week, we do some games, a bible study, and small groups to help learn more about God each week. All are welcome to join, as we are an open club—you don''t need to be a Christian! We welcome anyone who is interested in learning more about Christianity and building relationships with others. Our goal is to provide a welcoming and inclusive environment for all students to explore their faith or simply enjoy connecting with others.',
      null,
      'jfss.christianclub',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Christian Club (Project 153)']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Christian Club (Project 153)',
      slug = 'christian-club-project-153',
      short_description = 'Our club is dedicated to establishing a community of Christians in our school body. Each week, we do some games, a bible study, and small groups to help learn more about God each week. All are welcome to join, as we are ',
      description = 'Our club is dedicated to establishing a community of Christians in our school body. Each week, we do some games, a bible study, and small groups to help learn more about God each week. All are welcome to join, as we are an open club—you don''t need to be a Christian! We welcome anyone who is interested in learning more about Christianity and building relationships with others. Our goal is to provide a welcoming and inclusive environment for all students to explore their faith or simply enjoy connecting with others.',
      contact_email = null,
      instagram_handle = 'jfss.christianclub',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Christian Club (Project 153)']::text[]
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

-- Commerce Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '06c65235-9c67-4d8a-a562-b3cc2e17df3a'
    or lower(name) = lower('Commerce Club')
    or slug = 'commerce-club'
  order by (id = '06c65235-9c67-4d8a-a562-b3cc2e17df3a') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '06c65235-9c67-4d8a-a562-b3cc2e17df3a',
      'Commerce Club',
      'commerce-club',
      'Commerce Club is dedicated to connect students'' with an interest in the business. Commerce Club provides opportunities for members to expand their knowledge on various business-related topics through our bi-weekly meetin',
      'Commerce Club is dedicated to connect students'' with an interest in the business. Commerce Club provides opportunities for members to expand their knowledge on various business-related topics through our bi-weekly meetings.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Commerce Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Commerce Club',
      slug = 'commerce-club',
      short_description = 'Commerce Club is dedicated to connect students'' with an interest in the business. Commerce Club provides opportunities for members to expand their knowledge on various business-related topics through our bi-weekly meetin',
      description = 'Commerce Club is dedicated to connect students'' with an interest in the business. Commerce Club provides opportunities for members to expand their knowledge on various business-related topics through our bi-weekly meetings.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Commerce Club']::text[]
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

-- Crochet Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '4e9784a8-782a-433c-a4c5-590db853ea76'
    or lower(name) = lower('Crochet Club')
    or slug = 'crochet-club'
  order by (id = '4e9784a8-782a-433c-a4c5-590db853ea76') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '4e9784a8-782a-433c-a4c5-590db853ea76',
      'Crochet Club',
      'crochet-club',
      'Crochet Circle aims to bring the Fraser community together to learn how to crochet.',
      'Crochet Circle aims to bring the Fraser community together to learn how to crochet.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Crochet Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Crochet Club',
      slug = 'crochet-club',
      short_description = 'Crochet Circle aims to bring the Fraser community together to learn how to crochet.',
      description = 'Crochet Circle aims to bring the Fraser community together to learn how to crochet.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Crochet Club']::text[]
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

-- Data Science Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '4455f999-e312-4bca-aa10-57099670c131'
    or lower(name) = lower('Data Science Club')
    or slug = 'data-science-club'
  order by (id = '4455f999-e312-4bca-aa10-57099670c131') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '4455f999-e312-4bca-aa10-57099670c131',
      'Data Science Club',
      'data-science-club',
      'Teach students about the applications and future of data including analysis, visualization, exploration and more. Providing student with hands-on experience and tackle real world problems using data science.',
      'Teach students about the applications and future of data including analysis, visualization, exploration and more. Providing student with hands-on experience and tackle real world problems using data science.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Data Science Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Data Science Club',
      slug = 'data-science-club',
      short_description = 'Teach students about the applications and future of data including analysis, visualization, exploration and more. Providing student with hands-on experience and tackle real world problems using data science.',
      description = 'Teach students about the applications and future of data including analysis, visualization, exploration and more. Providing student with hands-on experience and tackle real world problems using data science.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Data Science Club']::text[]
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

-- DECA
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '0175dc96-b500-45f5-8c92-8b65cf781399'
    or lower(name) = lower('DECA')
    or slug = 'deca'
  order by (id = '0175dc96-b500-45f5-8c92-8b65cf781399') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '0175dc96-b500-45f5-8c92-8b65cf781399',
      'DECA',
      'deca',
      'Through conferences and competitions, DECA instills professionalism and prepares youth to respond to authentic business cases and market demands. At the core of DECA are our competitive events sorted by clusters. There’s',
      'Through conferences and competitions, DECA instills professionalism and prepares youth to respond to authentic business cases and market demands. At the core of DECA are our competitive events sorted by clusters. There’s a cluster perfect for each individual and an event to enhance their skills.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['DECA']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'DECA',
      slug = 'deca',
      short_description = 'Through conferences and competitions, DECA instills professionalism and prepares youth to respond to authentic business cases and market demands. At the core of DECA are our competitive events sorted by clusters. There’s',
      description = 'Through conferences and competitions, DECA instills professionalism and prepares youth to respond to authentic business cases and market demands. At the core of DECA are our competitive events sorted by clusters. There’s a cluster perfect for each individual and an event to enhance their skills.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['DECA']::text[]
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

-- Dental Society
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'acfa1590-6f7a-4589-9320-878e3aff85ba'
    or lower(name) = lower('Dental Society')
    or slug = 'dental-society'
  order by (id = 'acfa1590-6f7a-4589-9320-878e3aff85ba') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'acfa1590-6f7a-4589-9320-878e3aff85ba',
      'Dental Society',
      'dental-society',
      'The Dental Society provides hands-on learning experiences for students interested in dentistry, offering workshops, labs, and guest speakers to explore dental skills, career pathways, and advancements in oral health care',
      'The Dental Society provides hands-on learning experiences for students interested in dentistry, offering workshops, labs, and guest speakers to explore dental skills, career pathways, and advancements in oral health care.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Dental Society']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Dental Society',
      slug = 'dental-society',
      short_description = 'The Dental Society provides hands-on learning experiences for students interested in dentistry, offering workshops, labs, and guest speakers to explore dental skills, career pathways, and advancements in oral health care',
      description = 'The Dental Society provides hands-on learning experiences for students interested in dentistry, offering workshops, labs, and guest speakers to explore dental skills, career pathways, and advancements in oral health care.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Dental Society']::text[]
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

-- Design Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '60b9d817-bba2-49db-b7c7-362fdd1b110f'
    or lower(name) = lower('Design Club')
    or slug = 'design-club'
  order by (id = '60b9d817-bba2-49db-b7c7-362fdd1b110f') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '60b9d817-bba2-49db-b7c7-362fdd1b110f',
      'Design Club',
      'design-club',
      'The executive team will announce a new case study related to a specific area of design (eg. architectural design) every few weeks. These case studies are written in such a way that general members are essentially employe',
      'The executive team will announce a new case study related to a specific area of design (eg. architectural design) every few weeks. These case studies are written in such a way that general members are essentially employees, who are competing to have their design chosen for high paying clients. They are expected to create a design based on the instructions and rules given by the “client”.',
      'jfssdesignclub@gmail.com',
      'jfss_designclub',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Design Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Design Club',
      slug = 'design-club',
      short_description = 'The executive team will announce a new case study related to a specific area of design (eg. architectural design) every few weeks. These case studies are written in such a way that general members are essentially employe',
      description = 'The executive team will announce a new case study related to a specific area of design (eg. architectural design) every few weeks. These case studies are written in such a way that general members are essentially employees, who are competing to have their design chosen for high paying clients. They are expected to create a design based on the instructions and rules given by the “client”.',
      contact_email = 'jfssdesignclub@gmail.com',
      instagram_handle = 'jfss_designclub',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Design Club']::text[]
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

-- Digital Security Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '0ea97dcb-2872-4ad9-9cf2-a06c20768d16'
    or lower(name) = lower('Digital Security Club')
    or slug = 'digital-security-club'
  order by (id = '0ea97dcb-2872-4ad9-9cf2-a06c20768d16') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '0ea97dcb-2872-4ad9-9cf2-a06c20768d16',
      'Digital Security Club',
      'digital-security-club',
      'We are a club that explores the security aspect of technology through concepts such as Cryptography, Antivirus development, Penetration Testing, and Networking. We also simultaneously make the John Fraser Digital Platfor',
      'We are a club that explores the security aspect of technology through concepts such as Cryptography, Antivirus development, Penetration Testing, and Networking. We also simultaneously make the John Fraser Digital Platform Secure and Safe for the student body.',
      null,
      'jfss_digitalsecurity',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Digital Security Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Digital Security Club',
      slug = 'digital-security-club',
      short_description = 'We are a club that explores the security aspect of technology through concepts such as Cryptography, Antivirus development, Penetration Testing, and Networking. We also simultaneously make the John Fraser Digital Platfor',
      description = 'We are a club that explores the security aspect of technology through concepts such as Cryptography, Antivirus development, Penetration Testing, and Networking. We also simultaneously make the John Fraser Digital Platform Secure and Safe for the student body.',
      contact_email = null,
      instagram_handle = 'jfss_digitalsecurity',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Digital Security Club']::text[]
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

-- East Asian Students Association
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'ddd9887b-688a-4222-bced-8e0de13ff81b'
    or lower(name) = lower('East Asian Students Association')
    or slug = 'east-asian-students-association'
  order by (id = 'ddd9887b-688a-4222-bced-8e0de13ff81b') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'ddd9887b-688a-4222-bced-8e0de13ff81b',
      'East Asian Students Association',
      'east-asian-students-association',
      'EASA strives to spread East Asian culture and provide an inclusive space for everyone to enjoy our culture!!',
      'EASA strives to spread East Asian culture and provide an inclusive space for everyone to enjoy our culture!!',
      null,
      'fraser_easa',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['East Asian Students Association']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'East Asian Students Association',
      slug = 'east-asian-students-association',
      short_description = 'EASA strives to spread East Asian culture and provide an inclusive space for everyone to enjoy our culture!!',
      description = 'EASA strives to spread East Asian culture and provide an inclusive space for everyone to enjoy our culture!!',
      contact_email = null,
      instagram_handle = 'fraser_easa',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['East Asian Students Association']::text[]
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

-- Engineering Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'b2f11ad1-0c76-4dd1-9e64-b96cdb4b35ee'
    or lower(name) = lower('Engineering Club')
    or slug = 'engineering-club'
  order by (id = 'b2f11ad1-0c76-4dd1-9e64-b96cdb4b35ee') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'b2f11ad1-0c76-4dd1-9e64-b96cdb4b35ee',
      'Engineering Club',
      'engineering-club',
      'Engineering Club aims to educate and involve our members with different branches and aspects of engineering. The club year compromises of learning CAD, circuitry, and working on projects as a group, attempting to tackle ',
      'Engineering Club aims to educate and involve our members with different branches and aspects of engineering. The club year compromises of learning CAD, circuitry, and working on projects as a group, attempting to tackle problems through an engineering mindset using the design process.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Engineering Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Engineering Club',
      slug = 'engineering-club',
      short_description = 'Engineering Club aims to educate and involve our members with different branches and aspects of engineering. The club year compromises of learning CAD, circuitry, and working on projects as a group, attempting to tackle ',
      description = 'Engineering Club aims to educate and involve our members with different branches and aspects of engineering. The club year compromises of learning CAD, circuitry, and working on projects as a group, attempting to tackle problems through an engineering mindset using the design process.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Engineering Club']::text[]
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

-- Environmental Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'e85588a7-09c7-4b5d-b3f1-5fb9a9bd5988'
    or lower(name) = lower('Environmental Club')
    or slug = 'environmental-club'
  order by (id = 'e85588a7-09c7-4b5d-b3f1-5fb9a9bd5988') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'e85588a7-09c7-4b5d-b3f1-5fb9a9bd5988',
      'Environmental Club',
      'environmental-club',
      'John Fraser’s Environmental Club is an open council consisting of dedicated students who wish to create a more sustainable future for their peers, the community, and the world. We host meetings with open conversations ra',
      'John Fraser’s Environmental Club is an open council consisting of dedicated students who wish to create a more sustainable future for their peers, the community, and the world. We host meetings with open conversations raising awareness to create a greener future. In the past, the club has implemented strong school-wide initiatives, such as the environmental policy including the distribution of compostable utensils, as well as the Jag Closet. We are here to educate and empower!',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Environmental Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Environmental Club',
      slug = 'environmental-club',
      short_description = 'John Fraser’s Environmental Club is an open council consisting of dedicated students who wish to create a more sustainable future for their peers, the community, and the world. We host meetings with open conversations ra',
      description = 'John Fraser’s Environmental Club is an open council consisting of dedicated students who wish to create a more sustainable future for their peers, the community, and the world. We host meetings with open conversations raising awareness to create a greener future. In the past, the club has implemented strong school-wide initiatives, such as the environmental policy including the distribution of compostable utensils, as well as the Jag Closet. We are here to educate and empower!',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Environmental Club']::text[]
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

-- Fitness Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '64d687f1-e302-46c1-9549-ae96aacf4bca'
    or lower(name) = lower('Fitness Club')
    or slug = 'fitness-club'
  order by (id = '64d687f1-e302-46c1-9549-ae96aacf4bca') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '64d687f1-e302-46c1-9549-ae96aacf4bca',
      'Fitness Club',
      'fitness-club',
      'Fitness Club  provides members access to the fitness room while promoting growth and healthy living.',
      'Fitness Club  provides members access to the fitness room while promoting growth and healthy living.',
      'jfssfitnessclub@gmail.com',
      'jfssfitnessclub',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Fitness Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Fitness Club',
      slug = 'fitness-club',
      short_description = 'Fitness Club  provides members access to the fitness room while promoting growth and healthy living.',
      description = 'Fitness Club  provides members access to the fitness room while promoting growth and healthy living.',
      contact_email = 'jfssfitnessclub@gmail.com',
      instagram_handle = 'jfssfitnessclub',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Fitness Club']::text[]
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

-- Fraser Athletic Council (FAC)
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'a43c1244-d58f-4ff6-8286-1196afcb6b88'
    or lower(name) = lower('Fraser Athletic Council (FAC)')
    or slug = 'fraser-athletic-council-fac'
  order by (id = 'a43c1244-d58f-4ff6-8286-1196afcb6b88') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'a43c1244-d58f-4ff6-8286-1196afcb6b88',
      'Fraser Athletic Council (FAC)',
      'fraser-athletic-council-fac',
      'FAC hosts events for the athletic department at our school. We aim to shine light on our athletes and athletic department through school wide events like sprit rallies, Friday Night Lights, Intramurals and more! FAC also',
      'FAC hosts events for the athletic department at our school. We aim to shine light on our athletes and athletic department through school wide events like sprit rallies, Friday Night Lights, Intramurals and more! FAC also aims to promote healthy active living within our school and bring the school together through recreational events!',
      null,
      'jfssathletics',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Fraser Athletic Council (FAC)']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Fraser Athletic Council (FAC)',
      slug = 'fraser-athletic-council-fac',
      short_description = 'FAC hosts events for the athletic department at our school. We aim to shine light on our athletes and athletic department through school wide events like sprit rallies, Friday Night Lights, Intramurals and more! FAC also',
      description = 'FAC hosts events for the athletic department at our school. We aim to shine light on our athletes and athletic department through school wide events like sprit rallies, Friday Night Lights, Intramurals and more! FAC also aims to promote healthy active living within our school and bring the school together through recreational events!',
      contact_email = null,
      instagram_handle = 'jfssathletics',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Fraser Athletic Council (FAC)']::text[]
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

-- Fraser Chefs
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd'
    or lower(name) = lower('Fraser Chefs')
    or slug = 'fraser-chefs'
  order by (id = 'adbff931-c030-4ac5-9ed6-78b9105a3dbd') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'adbff931-c030-4ac5-9ed6-78b9105a3dbd',
      'Fraser Chefs',
      'fraser-chefs',
      'Space for students to cook, learn essential life skills and social together.',
      'Space for students to cook, learn essential life skills and social together.',
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
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Fraser Chefs',
      slug = 'fraser-chefs',
      short_description = 'Space for students to cook, learn essential life skills and social together.',
      description = 'Space for students to cook, learn essential life skills and social together.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Fraser chefs']::text[]
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
  values (v_club_id, 'Fraser chefs')
  on conflict do nothing;

end
$club_seed$;

-- Fraser Esports
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '4df091b3-9bcf-44f2-920b-887d478b6643'
    or lower(name) = lower('Fraser Esports')
    or slug = 'fraser-esports'
  order by (id = '4df091b3-9bcf-44f2-920b-887d478b6643') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '4df091b3-9bcf-44f2-920b-887d478b6643',
      'Fraser Esports',
      'fraser-esports',
      'We are a club centered around people''s love for video games! We host gaming events throughout the year including casual and competitive tournaments aswell as trivia in which prizes are given out, and every one is invited',
      'We are a club centered around people''s love for video games! We host gaming events throughout the year including casual and competitive tournaments aswell as trivia in which prizes are given out, and every one is invited! Our club is open, no application necessary!',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Fraser ESports']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Fraser Esports',
      slug = 'fraser-esports',
      short_description = 'We are a club centered around people''s love for video games! We host gaming events throughout the year including casual and competitive tournaments aswell as trivia in which prizes are given out, and every one is invited',
      description = 'We are a club centered around people''s love for video games! We host gaming events throughout the year including casual and competitive tournaments aswell as trivia in which prizes are given out, and every one is invited! Our club is open, no application necessary!',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Fraser ESports']::text[]
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
  values (v_club_id, 'Fraser ESports')
  on conflict do nothing;

end
$club_seed$;

-- Fraser Scholars
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '33866f50-de44-4daa-8db9-d989c592eadd'
    or lower(name) = lower('Fraser Scholars')
    or slug = 'fraser-scholars'
  order by (id = '33866f50-de44-4daa-8db9-d989c592eadd') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '33866f50-de44-4daa-8db9-d989c592eadd',
      'Fraser Scholars',
      'fraser-scholars',
      'Fraser Scholars is a student run club where senior students (grade 11/12) offer tutoring to all John Fraser Students. The club runs twice a week and students can drop in for help with their subjects or a quiet study spac',
      'Fraser Scholars is a student run club where senior students (grade 11/12) offer tutoring to all John Fraser Students. The club runs twice a week and students can drop in for help with their subjects or a quiet study space.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Fraser Scholars']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Fraser Scholars',
      slug = 'fraser-scholars',
      short_description = 'Fraser Scholars is a student run club where senior students (grade 11/12) offer tutoring to all John Fraser Students. The club runs twice a week and students can drop in for help with their subjects or a quiet study spac',
      description = 'Fraser Scholars is a student run club where senior students (grade 11/12) offer tutoring to all John Fraser Students. The club runs twice a week and students can drop in for help with their subjects or a quiet study space.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Fraser Scholars']::text[]
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

-- Fraser STEM Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '37f95b8e-10e4-475a-a420-8a20c76830b6'
    or lower(name) = lower('Fraser STEM Club')
    or slug = 'fraser-stem-club'
  order by (id = '37f95b8e-10e4-475a-a420-8a20c76830b6') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '37f95b8e-10e4-475a-a420-8a20c76830b6',
      'Fraser STEM Club',
      'fraser-stem-club',
      'Our events and activities will help students apply theoretical scientific concepts to practical activities, and provide them with better understanding of applied science in different fields. For example, an activity we p',
      'Our events and activities will help students apply theoretical scientific concepts to practical activities, and provide them with better understanding of applied science in different fields. For example, an activity we plan on hosting is an egg drop challenge, which allows students to apply their knowledge of physics to a fun competition. These activities allow students to learn actively and ignite their curiosity in STEM-related subjects.',
      null,
      'jfss.stem',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Fraser STEM Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Fraser STEM Club',
      slug = 'fraser-stem-club',
      short_description = 'Our events and activities will help students apply theoretical scientific concepts to practical activities, and provide them with better understanding of applied science in different fields. For example, an activity we p',
      description = 'Our events and activities will help students apply theoretical scientific concepts to practical activities, and provide them with better understanding of applied science in different fields. For example, an activity we plan on hosting is an egg drop challenge, which allows students to apply their knowledge of physics to a fun competition. These activities allow students to learn actively and ignite their curiosity in STEM-related subjects.',
      contact_email = null,
      instagram_handle = 'jfss.stem',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Fraser STEM Club']::text[]
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

-- French Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'bb301c27-4431-40a8-8c09-dc416aaacde4'
    or lower(name) = lower('French Club')
    or slug = 'french-club'
  order by (id = 'bb301c27-4431-40a8-8c09-dc416aaacde4') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'bb301c27-4431-40a8-8c09-dc416aaacde4',
      'French Club',
      'french-club',
      'Fraser’s French Club aims to support and encourage students in practicing and immersing themselves in the French language outside of the classroom through interactive activities and discussions.',
      'Fraser’s French Club aims to support and encourage students in practicing and immersing themselves in the French language outside of the classroom through interactive activities and discussions.',
      null,
      'fraserfrenchclub',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['French Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'French Club',
      slug = 'french-club',
      short_description = 'Fraser’s French Club aims to support and encourage students in practicing and immersing themselves in the French language outside of the classroom through interactive activities and discussions.',
      description = 'Fraser’s French Club aims to support and encourage students in practicing and immersing themselves in the French language outside of the classroom through interactive activities and discussions.',
      contact_email = null,
      instagram_handle = 'fraserfrenchclub',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['French Club']::text[]
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

-- Future Leader Initiative (FLIQ)
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '1a39fe69-338b-45a7-9f06-8da58b158be7'
    or lower(name) = lower('Future Leader Initiative (FLIQ)')
    or slug = 'future-leader-initiative-fliq'
  order by (id = '1a39fe69-338b-45a7-9f06-8da58b158be7') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '1a39fe69-338b-45a7-9f06-8da58b158be7',
      'Future Leader Initiative (FLIQ)',
      'future-leader-initiative-fliq',
      'Partnered with Queens University, FLIQ helps you create your own business with advice from career coaches and world class judges. You''ll have the chance to compete in an international pitch competition at Queens, and ear',
      'Partnered with Queens University, FLIQ helps you create your own business with advice from career coaches and world class judges. You''ll have the chance to compete in an international pitch competition at Queens, and earn university microcredentials.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Future Leader Initiative (FLIQ)']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Future Leader Initiative (FLIQ)',
      slug = 'future-leader-initiative-fliq',
      short_description = 'Partnered with Queens University, FLIQ helps you create your own business with advice from career coaches and world class judges. You''ll have the chance to compete in an international pitch competition at Queens, and ear',
      description = 'Partnered with Queens University, FLIQ helps you create your own business with advice from career coaches and world class judges. You''ll have the chance to compete in an international pitch competition at Queens, and earn university microcredentials.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Future Leader Initiative (FLIQ)']::text[]
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

-- Hindu Student Association
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'f35c5edd-a1bc-49da-9a24-e284a7e04105'
    or lower(name) = lower('Hindu Student Association')
    or slug = 'hindu-student-association'
  order by (id = 'f35c5edd-a1bc-49da-9a24-e284a7e04105') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'f35c5edd-a1bc-49da-9a24-e284a7e04105',
      'Hindu Student Association',
      'hindu-student-association',
      'The John Fraser Hindu Student Association is dedicated to fostering cultural awareness, inclusivity, and community spirit within Fraser. Our purpose is to celebrate and share Hindu traditions, values, and festivals with ',
      'The John Fraser Hindu Student Association is dedicated to fostering cultural awareness, inclusivity, and community spirit within Fraser. Our purpose is to celebrate and share Hindu traditions, values, and festivals with the school community. Each year, we proudly organize Fraser’s annual Diwali event, along with other activities that promote learning, unity, and appreciation for Hinduism and the culture.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Hindu Student Association']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Hindu Student Association',
      slug = 'hindu-student-association',
      short_description = 'The John Fraser Hindu Student Association is dedicated to fostering cultural awareness, inclusivity, and community spirit within Fraser. Our purpose is to celebrate and share Hindu traditions, values, and festivals with ',
      description = 'The John Fraser Hindu Student Association is dedicated to fostering cultural awareness, inclusivity, and community spirit within Fraser. Our purpose is to celebrate and share Hindu traditions, values, and festivals with the school community. Each year, we proudly organize Fraser’s annual Diwali event, along with other activities that promote learning, unity, and appreciation for Hinduism and the culture.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Hindu Student Association']::text[]
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

-- HOSA John Fraser
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '0e53b477-a6d3-407a-9da4-a196507960f3'
    or lower(name) = lower('HOSA John Fraser')
    or slug = 'hosa-john-fraser'
  order by (id = '0e53b477-a6d3-407a-9da4-a196507960f3') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '0e53b477-a6d3-407a-9da4-a196507960f3',
      'HOSA John Fraser',
      'hosa-john-fraser',
      'HOSA is a competition based club, focused in the health science field, that aims to give members the opportunity to learn more about various health professions. Members have the opportunity to compete in their events at ',
      'HOSA is a competition based club, focused in the health science field, that aims to give members the opportunity to learn more about various health professions. Members have the opportunity to compete in their events at the national and international level.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['HOSA John Fraser']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'HOSA John Fraser',
      slug = 'hosa-john-fraser',
      short_description = 'HOSA is a competition based club, focused in the health science field, that aims to give members the opportunity to learn more about various health professions. Members have the opportunity to compete in their events at ',
      description = 'HOSA is a competition based club, focused in the health science field, that aims to give members the opportunity to learn more about various health professions. Members have the opportunity to compete in their events at the national and international level.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['HOSA John Fraser']::text[]
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

-- iNNOVATE
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'abed1b7c-b824-4878-ba3a-355980f384f2'
    or lower(name) = lower('iNNOVATE')
    or slug = 'innovate'
  order by (id = 'abed1b7c-b824-4878-ba3a-355980f384f2') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'abed1b7c-b824-4878-ba3a-355980f384f2',
      'iNNOVATE',
      'innovate',
      'tutoring middle school students about programming, circuitry and 3D modelling',
      'tutoring middle school students about programming, circuitry and 3D modelling',
      'jfss.innovate@gmail.com',
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['iNNOVATE']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'iNNOVATE',
      slug = 'innovate',
      short_description = 'tutoring middle school students about programming, circuitry and 3D modelling',
      description = 'tutoring middle school students about programming, circuitry and 3D modelling',
      contact_email = 'jfss.innovate@gmail.com',
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['iNNOVATE']::text[]
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

-- Investment Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '811df66f-c931-4b05-abd4-6a361448b8b8'
    or lower(name) = lower('Investment Club')
    or slug = 'investment-club'
  order by (id = '811df66f-c931-4b05-abd4-6a361448b8b8') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '811df66f-c931-4b05-abd4-6a361448b8b8',
      'Investment Club',
      'investment-club',
      'Investment Club was created for students to learn investing principles and personal finance basics to strengthen a foundation for making good financial decisions. Our goal is to teach financial literacy and prepare membe',
      'Investment Club was created for students to learn investing principles and personal finance basics to strengthen a foundation for making good financial decisions. Our goal is to teach financial literacy and prepare members for future financial independence while encouraging a collaborative environment for sharing ideas and learning from each other.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Investment Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Investment Club',
      slug = 'investment-club',
      short_description = 'Investment Club was created for students to learn investing principles and personal finance basics to strengthen a foundation for making good financial decisions. Our goal is to teach financial literacy and prepare membe',
      description = 'Investment Club was created for students to learn investing principles and personal finance basics to strengthen a foundation for making good financial decisions. Our goal is to teach financial literacy and prepare members for future financial independence while encouraging a collaborative environment for sharing ideas and learning from each other.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Investment Club']::text[]
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

-- Jack.org
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '72498b69-3fb0-414c-9a3a-10a7c06af208'
    or lower(name) = lower('Jack.org')
    or slug = 'jackorg'
  order by (id = '72498b69-3fb0-414c-9a3a-10a7c06af208') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '72498b69-3fb0-414c-9a3a-10a7c06af208',
      'Jack.org',
      'jackorg',
      'The JFSS Jack.org chapter is part of a non profit organization called Jack.org. Our goal is to break down the stigma surrounding mental health and create a positive school environment where everyone feels welcomed. To do',
      'The JFSS Jack.org chapter is part of a non profit organization called Jack.org. Our goal is to break down the stigma surrounding mental health and create a positive school environment where everyone feels welcomed. To do so, we run many events such as flower pot painting, keychain making, and in the past, we''ve even brought in professional speakers to talk about mental health and how to deal with certain stressors.',
      null,
      'jackdotorgjfss',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Jack.org']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Jack.org',
      slug = 'jackorg',
      short_description = 'The JFSS Jack.org chapter is part of a non profit organization called Jack.org. Our goal is to break down the stigma surrounding mental health and create a positive school environment where everyone feels welcomed. To do',
      description = 'The JFSS Jack.org chapter is part of a non profit organization called Jack.org. Our goal is to break down the stigma surrounding mental health and create a positive school environment where everyone feels welcomed. To do so, we run many events such as flower pot painting, keychain making, and in the past, we''ve even brought in professional speakers to talk about mental health and how to deal with certain stressors.',
      contact_email = null,
      instagram_handle = 'jackdotorgjfss',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Jack.org']::text[]
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

-- JFSS Biology Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'eecbb24d-f174-460b-bb8c-3f7f764a82ab'
    or lower(name) = lower('JFSS Biology Club')
    or slug = 'jfss-biology-club'
  order by (id = 'eecbb24d-f174-460b-bb8c-3f7f764a82ab') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'eecbb24d-f174-460b-bb8c-3f7f764a82ab',
      'JFSS Biology Club',
      'jfss-biology-club',
      'The John Fraser Biology Club is a student-run organization that promotes a passion for biology through discussion-based learning and hands-on experiments. The club offers members opportunities to engage with various biol',
      'The John Fraser Biology Club is a student-run organization that promotes a passion for biology through discussion-based learning and hands-on experiments. The club offers members opportunities to engage with various biological topics, including dissections, interactive labs, and experiments. These activities allow students to explore concepts in depth and develop practical skills. The club fosters a collaborative environment where students can apply their knowledge, deepen their understanding of biology, and enhance their scientific learning experience.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFSS Biology Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS Biology Club',
      slug = 'jfss-biology-club',
      short_description = 'The John Fraser Biology Club is a student-run organization that promotes a passion for biology through discussion-based learning and hands-on experiments. The club offers members opportunities to engage with various biol',
      description = 'The John Fraser Biology Club is a student-run organization that promotes a passion for biology through discussion-based learning and hands-on experiments. The club offers members opportunities to engage with various biological topics, including dissections, interactive labs, and experiments. These activities allow students to explore concepts in depth and develop practical skills. The club fosters a collaborative environment where students can apply their knowledge, deepen their understanding of biology, and enhance their scientific learning experience.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFSS Biology Club']::text[]
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

-- JFSS Cyber Computing Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'e1151772-b3a5-4551-b2ce-d54833bd114f'
    or lower(name) = lower('JFSS Cyber Computing Club')
    or slug = 'jfss-cyber-computing-club'
  order by (id = 'e1151772-b3a5-4551-b2ce-d54833bd114f') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'e1151772-b3a5-4551-b2ce-d54833bd114f',
      'JFSS Cyber Computing Club',
      'jfss-cyber-computing-club',
      'The Cyber Computing Club, started in the academic year 2024-2025, sought to teach students the basics of networking, which include IP addresses, MAC addresses, TCP/UDP, the Three-Way Handshake, the OSI model, and more in',
      'The Cyber Computing Club, started in the academic year 2024-2025, sought to teach students the basics of networking, which include IP addresses, MAC addresses, TCP/UDP, the Three-Way Handshake, the OSI model, and more intricate topics like virtualization and subnetting. There were many activities and projects, all conducted on a private network. Students also familiarized themselves with Bash scripting and the Linux kernel, enabling them to understand Linux core subsystems and Linux-specific applications. Additionally, students learnt the five stages of ethical hacking, including reconnaissance, enumeration/scanning (stealth scanning), gaining access, maintaining access, and cleaning footprints.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFSS Cyber Computing Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS Cyber Computing Club',
      slug = 'jfss-cyber-computing-club',
      short_description = 'The Cyber Computing Club, started in the academic year 2024-2025, sought to teach students the basics of networking, which include IP addresses, MAC addresses, TCP/UDP, the Three-Way Handshake, the OSI model, and more in',
      description = 'The Cyber Computing Club, started in the academic year 2024-2025, sought to teach students the basics of networking, which include IP addresses, MAC addresses, TCP/UDP, the Three-Way Handshake, the OSI model, and more intricate topics like virtualization and subnetting. There were many activities and projects, all conducted on a private network. Students also familiarized themselves with Bash scripting and the Linux kernel, enabling them to understand Linux core subsystems and Linux-specific applications. Additionally, students learnt the five stages of ethical hacking, including reconnaissance, enumeration/scanning (stealth scanning), gaining access, maintaining access, and cleaning footprints.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFSS Cyber Computing Club']::text[]
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

-- JFSS Photography Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'bb7ff7ba-198d-4ea7-a3e3-d2a904205891'
    or lower(name) = lower('JFSS Photography Club')
    or slug = 'jfss-photography-club'
  order by (id = 'bb7ff7ba-198d-4ea7-a3e3-d2a904205891') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'bb7ff7ba-198d-4ea7-a3e3-d2a904205891',
      'JFSS Photography Club',
      'jfss-photography-club',
      'The Photography Club was revitalized for the 2024-2025 academic year after a period of inactivity. With a renewed vision, we introduced two new initiatives: Light of Ecstasy and the Candid Group, each aimed at expanding ',
      'The Photography Club was revitalized for the 2024-2025 academic year after a period of inactivity. With a renewed vision, we introduced two new initiatives: Light of Ecstasy and the Candid Group, each aimed at expanding students'' creative and technical engagement with photography. The JFSS Photography Club is dedicated to fostering a creative community for students passionate about photography. Its purpose is to provide a platform for students to develop technical skills, express creativity, and build experience in both artistic and event photography. Through initiatives like Light of Ecstasy and the Candid Group, the club offers opportunities for publication, event coverage, and hands-on practice, helping students explore photography as both a personal interest and potential career path.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFSS Photography Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS Photography Club',
      slug = 'jfss-photography-club',
      short_description = 'The Photography Club was revitalized for the 2024-2025 academic year after a period of inactivity. With a renewed vision, we introduced two new initiatives: Light of Ecstasy and the Candid Group, each aimed at expanding ',
      description = 'The Photography Club was revitalized for the 2024-2025 academic year after a period of inactivity. With a renewed vision, we introduced two new initiatives: Light of Ecstasy and the Candid Group, each aimed at expanding students'' creative and technical engagement with photography. The JFSS Photography Club is dedicated to fostering a creative community for students passionate about photography. Its purpose is to provide a platform for students to develop technical skills, express creativity, and build experience in both artistic and event photography. Through initiatives like Light of Ecstasy and the Candid Group, the club offers opportunities for publication, event coverage, and hands-on practice, helping students explore photography as both a personal interest and potential career path.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFSS Photography Club']::text[]
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

-- JFSS PsychSociety
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '7dd8780b-8e2f-445a-a459-fdbd15d68c1a'
    or lower(name) = lower('JFSS PsychSociety')
    or slug = 'jfss-psychsociety'
  order by (id = '7dd8780b-8e2f-445a-a459-fdbd15d68c1a') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '7dd8780b-8e2f-445a-a459-fdbd15d68c1a',
      'JFSS PsychSociety',
      'jfss-psychsociety',
      '​JFSS Psychsociety is a club that explores the world of human behavior through fun experiments and engaging projects. We focus on topics like perception, social dynamics, and MBTI''s all while fostering a creative and int',
      '​JFSS Psychsociety is a club that explores the world of human behavior through fun experiments and engaging projects. We focus on topics like perception, social dynamics, and MBTI''s all while fostering a creative and interactive learning environment.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFSS PsychSociety']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS PsychSociety',
      slug = 'jfss-psychsociety',
      short_description = '​JFSS Psychsociety is a club that explores the world of human behavior through fun experiments and engaging projects. We focus on topics like perception, social dynamics, and MBTI''s all while fostering a creative and int',
      description = '​JFSS Psychsociety is a club that explores the world of human behavior through fun experiments and engaging projects. We focus on topics like perception, social dynamics, and MBTI''s all while fostering a creative and interactive learning environment.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFSS PsychSociety']::text[]
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

-- JFSS Sending Sunshine
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'ba5ad486-a35b-4877-81e9-6f789a6f6878'
    or lower(name) = lower('JFSS Sending Sunshine')
    or slug = 'jfss-sending-sunshine'
  order by (id = 'ba5ad486-a35b-4877-81e9-6f789a6f6878') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'ba5ad486-a35b-4877-81e9-6f789a6f6878',
      'JFSS Sending Sunshine',
      'jfss-sending-sunshine',
      'Sending Sunshine is an organization dedicated to improving the lives of senior citizens across the country through the gestures of cards, words and handmade gifts. Our mission at John Fraser is to foster this spirit of c',
      'Sending Sunshine is an organization dedicated to improving the lives of senior citizens across the country through the gestures of cards, words and handmade gifts. Our mission at John Fraser is to foster this spirit of community service while helping those in our school to make connections, earn volunteer hours and continue to be good citizens of our community and  help them continue to be so as they graduate',
      null,
      'jfss_sendingsunshine',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFSS Sending Sunshine']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS Sending Sunshine',
      slug = 'jfss-sending-sunshine',
      short_description = 'Sending Sunshine is an organization dedicated to improving the lives of senior citizens across the country through the gestures of cards, words and handmade gifts. Our mission at John Fraser is to foster this spirit of c',
      description = 'Sending Sunshine is an organization dedicated to improving the lives of senior citizens across the country through the gestures of cards, words and handmade gifts. Our mission at John Fraser is to foster this spirit of community service while helping those in our school to make connections, earn volunteer hours and continue to be good citizens of our community and  help them continue to be so as they graduate',
      contact_email = null,
      instagram_handle = 'jfss_sendingsunshine',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFSS Sending Sunshine']::text[]
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

-- John Fraser Debate Society
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'a778a3a2-9763-40c6-a430-a82adc368430'
    or lower(name) = lower('John Fraser Debate Society')
    or slug = 'john-fraser-debate-society'
  order by (id = 'a778a3a2-9763-40c6-a430-a82adc368430') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'a778a3a2-9763-40c6-a430-a82adc368430',
      'John Fraser Debate Society',
      'john-fraser-debate-society',
      'We teach students how to debate on the British Parliament style and give lessons with real debates that happen within the lunch break or after school.',
      'We teach students how to debate on the British Parliament style and give lessons with real debates that happen within the lunch break or after school.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['John Fraser Debate Society']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'John Fraser Debate Society',
      slug = 'john-fraser-debate-society',
      short_description = 'We teach students how to debate on the British Parliament style and give lessons with real debates that happen within the lunch break or after school.',
      description = 'We teach students how to debate on the British Parliament style and give lessons with real debates that happen within the lunch break or after school.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['John Fraser Debate Society']::text[]
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

-- John Fraser's Astronomy Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'd865aabf-0bea-40fd-ae38-9cf1b0d5c81d'
    or lower(name) = lower('John Fraser''s Astronomy Club')
    or slug = 'john-frasers-astronomy-club'
  order by (id = 'd865aabf-0bea-40fd-ae38-9cf1b0d5c81d') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'd865aabf-0bea-40fd-ae38-9cf1b0d5c81d',
      'John Fraser''s Astronomy Club',
      'john-frasers-astronomy-club',
      'The astronomy club aims to introduce the fascinating field of astronomy to all members of the John Fraser community, whether they are aspiring astronomers or simply fascinated by the night sky. Through interactive lesson',
      'The astronomy club aims to introduce the fascinating field of astronomy to all members of the John Fraser community, whether they are aspiring astronomers or simply fascinated by the night sky. Through interactive lessons, workshops, and activities, we hope to offer like-minded students a captivating journey into the world of astronomy.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['John Fraser''s Astronomy Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'John Fraser''s Astronomy Club',
      slug = 'john-frasers-astronomy-club',
      short_description = 'The astronomy club aims to introduce the fascinating field of astronomy to all members of the John Fraser community, whether they are aspiring astronomers or simply fascinated by the night sky. Through interactive lesson',
      description = 'The astronomy club aims to introduce the fascinating field of astronomy to all members of the John Fraser community, whether they are aspiring astronomers or simply fascinated by the night sky. Through interactive lessons, workshops, and activities, we hope to offer like-minded students a captivating journey into the world of astronomy.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['John Fraser''s Astronomy Club']::text[]
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

-- John Fraser's Business Society
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '895a0b23-fc90-47f4-83d3-ca62e82332e8'
    or lower(name) = lower('John Fraser''s Business Society')
    or slug = 'john-frasers-business-society'
  order by (id = '895a0b23-fc90-47f4-83d3-ca62e82332e8') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '895a0b23-fc90-47f4-83d3-ca62e82332e8',
      'John Fraser''s Business Society',
      'john-frasers-business-society',
      'Educate students on various business related topics and concepts',
      'Educate students on various business related topics and concepts',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['John Fraser''s Business Society']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'John Fraser''s Business Society',
      slug = 'john-frasers-business-society',
      short_description = 'Educate students on various business related topics and concepts',
      description = 'Educate students on various business related topics and concepts',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['John Fraser''s Business Society']::text[]
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

-- John Fraser's Law Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'eea53486-b00e-475a-a5ac-2cf3254ba1e6'
    or lower(name) = lower('John Fraser''s Law Club')
    or slug = 'john-frasers-law-club'
  order by (id = 'eea53486-b00e-475a-a5ac-2cf3254ba1e6') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'eea53486-b00e-475a-a5ac-2cf3254ba1e6',
      'John Fraser''s Law Club',
      'john-frasers-law-club',
      'Law club is a club where students will learn about various areas of Canadian Law such as The Canadian Charter of Rights and Freedoms, types of law (tort, civil, criminal), criminal punishments, careers in law, and more. ',
      'Law club is a club where students will learn about various areas of Canadian Law such as The Canadian Charter of Rights and Freedoms, types of law (tort, civil, criminal), criminal punishments, careers in law, and more. Students will engage with the slideshow content through activities such as Kahoots and Jeopardy games. They will also get to participate in debates and mock trials to apply and extend their knowledge. Overall, this club allows students who are interested in the legal field to increase their knowledge and get to explore an interest of theirs. This club adds diversity to the school clubs since it is the only Law Club and one of the few social science-based clubs. We encourage students to find their passion in law and take future law or social science courses at JFSS. We want to support students'' passions and inspire them to learn about law and figure out whether this is a field they''d like to pursue a career in. Overall, Law Club is a welcoming and safe environment that encourages students to learn and grow in a fun way!',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['John Fraser''s Law CLub']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'John Fraser''s Law Club',
      slug = 'john-frasers-law-club',
      short_description = 'Law club is a club where students will learn about various areas of Canadian Law such as The Canadian Charter of Rights and Freedoms, types of law (tort, civil, criminal), criminal punishments, careers in law, and more. ',
      description = 'Law club is a club where students will learn about various areas of Canadian Law such as The Canadian Charter of Rights and Freedoms, types of law (tort, civil, criminal), criminal punishments, careers in law, and more. Students will engage with the slideshow content through activities such as Kahoots and Jeopardy games. They will also get to participate in debates and mock trials to apply and extend their knowledge. Overall, this club allows students who are interested in the legal field to increase their knowledge and get to explore an interest of theirs. This club adds diversity to the school clubs since it is the only Law Club and one of the few social science-based clubs. We encourage students to find their passion in law and take future law or social science courses at JFSS. We want to support students'' passions and inspire them to learn about law and figure out whether this is a field they''d like to pursue a career in. Overall, Law Club is a welcoming and safe environment that encourages students to learn and grow in a fun way!',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['John Fraser''s Law CLub']::text[]
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
  values (v_club_id, 'John Fraser''s Law CLub')
  on conflict do nothing;

end
$club_seed$;

-- JFSS INTERACT
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '59a4ffbc-958e-4086-99b6-bd2458754e88'
    or lower(name) = lower('JFSS INTERACT')
    or slug = 'jfss-interact'
  order by (id = '59a4ffbc-958e-4086-99b6-bd2458754e88') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '59a4ffbc-958e-4086-99b6-bd2458754e88',
      'JFSS INTERACT',
      'jfss-interact',
      'Rotary based club - charitable events',
      'Rotary based club - charitable events',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['JFSS INTERACT']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'JFSS INTERACT',
      slug = 'jfss-interact',
      short_description = 'Rotary based club - charitable events',
      description = 'Rotary based club - charitable events',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['JFSS INTERACT']::text[]
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

-- Journaling Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'f040490c-3cf9-421f-a4a9-57c42624a7fc'
    or lower(name) = lower('Journaling Club')
    or slug = 'journaling-club'
  order by (id = 'f040490c-3cf9-421f-a4a9-57c42624a7fc') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'f040490c-3cf9-421f-a4a9-57c42624a7fc',
      'Journaling Club',
      'journaling-club',
      'Journaling Club''s goal is to encourage self-discovery and personal growth through journaling.  Journaling is not only a tool for recording daily experiences but also a way of processing emotions, setting goals, and unlea',
      'Journaling Club''s goal is to encourage self-discovery and personal growth through journaling.  Journaling is not only a tool for recording daily experiences but also a way of processing emotions, setting goals, and unleashing one’s creativity. Our purpose is to offer students at John Fraser a safe and welcoming space to students who have a passion for journaling, creative writing, and personal reflection. . Our club activities include engaging writing prompts, collaborative projects with other students and friends,  themed journaling sessions, and bullet journaling events.',
      'jfssjournalism@gmail.com',
      'journaljfss',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Journaling Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Journaling Club',
      slug = 'journaling-club',
      short_description = 'Journaling Club''s goal is to encourage self-discovery and personal growth through journaling.  Journaling is not only a tool for recording daily experiences but also a way of processing emotions, setting goals, and unlea',
      description = 'Journaling Club''s goal is to encourage self-discovery and personal growth through journaling.  Journaling is not only a tool for recording daily experiences but also a way of processing emotions, setting goals, and unleashing one’s creativity. Our purpose is to offer students at John Fraser a safe and welcoming space to students who have a passion for journaling, creative writing, and personal reflection. . Our club activities include engaging writing prompts, collaborative projects with other students and friends,  themed journaling sessions, and bullet journaling events.',
      contact_email = 'jfssjournalism@gmail.com',
      instagram_handle = 'journaljfss',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Journaling Club']::text[]
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

-- Kinesiology Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '5e735f53-d0d9-480c-a28e-31ee540b5115'
    or lower(name) = lower('Kinesiology Club')
    or slug = 'kinesiology-club'
  order by (id = '5e735f53-d0d9-480c-a28e-31ee540b5115') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '5e735f53-d0d9-480c-a28e-31ee540b5115',
      'Kinesiology Club',
      'kinesiology-club',
      'Teach about kinesiology and relating topics such as sports psychology and nutrition',
      'Teach about kinesiology and relating topics such as sports psychology and nutrition',
      null,
      'jfss.kinesiolgy',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Kinesiology Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Kinesiology Club',
      slug = 'kinesiology-club',
      short_description = 'Teach about kinesiology and relating topics such as sports psychology and nutrition',
      description = 'Teach about kinesiology and relating topics such as sports psychology and nutrition',
      contact_email = null,
      instagram_handle = 'jfss.kinesiolgy',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Kinesiology Club']::text[]
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

-- Ladybug Magazine
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '5d7b72e2-010e-4f06-9c81-ccb4614efab9'
    or lower(name) = lower('Ladybug Magazine')
    or slug = 'ladybug-magazine'
  order by (id = '5d7b72e2-010e-4f06-9c81-ccb4614efab9') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '5d7b72e2-010e-4f06-9c81-ccb4614efab9',
      'Ladybug Magazine',
      'ladybug-magazine',
      'Welcome to Fraser’s first fashion magazine, where creativity knows no limits! At Ladybug Magazine, we’re here to inspire confidence and celebrate individuality with student-made content in styling, writing, graphic desig',
      'Welcome to Fraser’s first fashion magazine, where creativity knows no limits! At Ladybug Magazine, we’re here to inspire confidence and celebrate individuality with student-made content in styling, writing, graphic design, and video making. We’ve launched Fraser’s first digital fashion magazine and even hosted a school fashion show to bring our vision to life! If you have a creative vision, Ladybug is just the right place for you! Follow us on Instagram @ladybugm4g on Instagram for fresh ideas, behind-the-scenes content, and to stay connected with our vibrant student body. And feel free to ask us why we''re called ''Ladybug''!',
      'theladybugjfss@gmail.com',
      'ladybugm4g',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Ladybug Magazine']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Ladybug Magazine',
      slug = 'ladybug-magazine',
      short_description = 'Welcome to Fraser’s first fashion magazine, where creativity knows no limits! At Ladybug Magazine, we’re here to inspire confidence and celebrate individuality with student-made content in styling, writing, graphic desig',
      description = 'Welcome to Fraser’s first fashion magazine, where creativity knows no limits! At Ladybug Magazine, we’re here to inspire confidence and celebrate individuality with student-made content in styling, writing, graphic design, and video making. We’ve launched Fraser’s first digital fashion magazine and even hosted a school fashion show to bring our vision to life! If you have a creative vision, Ladybug is just the right place for you! Follow us on Instagram @ladybugm4g on Instagram for fresh ideas, behind-the-scenes content, and to stay connected with our vibrant student body. And feel free to ask us why we''re called ''Ladybug''!',
      contact_email = 'theladybugjfss@gmail.com',
      instagram_handle = 'ladybugm4g',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Ladybug Magazine']::text[]
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

-- Math Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'b0732d44-5dc6-43b0-b4b9-d261a581ea9a'
    or lower(name) = lower('Math Club')
    or slug = 'math-club'
  order by (id = 'b0732d44-5dc6-43b0-b4b9-d261a581ea9a') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'b0732d44-5dc6-43b0-b4b9-d261a581ea9a',
      'Math Club',
      'math-club',
      'Math Club is John Fraser''s first club dedicated to making STEM subjects more fun and approachable. Run by a team of seven executives, we provide services from Waterloo contest preparation, math tutoring, festive math act',
      'Math Club is John Fraser''s first club dedicated to making STEM subjects more fun and approachable. Run by a team of seven executives, we provide services from Waterloo contest preparation, math tutoring, festive math activities, and advice for post-secondary math! This year, our goals are to improve students'' competition skills and coordinate board-wide and school-wide math challenges :) 🧮',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Math Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Math Club',
      slug = 'math-club',
      short_description = 'Math Club is John Fraser''s first club dedicated to making STEM subjects more fun and approachable. Run by a team of seven executives, we provide services from Waterloo contest preparation, math tutoring, festive math act',
      description = 'Math Club is John Fraser''s first club dedicated to making STEM subjects more fun and approachable. Run by a team of seven executives, we provide services from Waterloo contest preparation, math tutoring, festive math activities, and advice for post-secondary math! This year, our goals are to improve students'' competition skills and coordinate board-wide and school-wide math challenges :) 🧮',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Math Club']::text[]
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

-- Medlife
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '87106a8e-9980-48b6-be8e-9ace444b8644'
    or lower(name) = lower('Medlife')
    or slug = 'medlife'
  order by (id = '87106a8e-9980-48b6-be8e-9ace444b8644') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '87106a8e-9980-48b6-be8e-9ace444b8644',
      'Medlife',
      'medlife',
      'Medlife John Fraser is a chapter within Medlife internationals. Throughout the year, we run various events to raise money to help build schools, hospitals, and other necessities in third world countries. Members contribu',
      'Medlife John Fraser is a chapter within Medlife internationals. Throughout the year, we run various events to raise money to help build schools, hospitals, and other necessities in third world countries. Members contribute by helping to facilitate various events as well as spread awareness about Medlife''s mission!',
      null,
      'medlifejfss',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Medlife']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Medlife',
      slug = 'medlife',
      short_description = 'Medlife John Fraser is a chapter within Medlife internationals. Throughout the year, we run various events to raise money to help build schools, hospitals, and other necessities in third world countries. Members contribu',
      description = 'Medlife John Fraser is a chapter within Medlife internationals. Throughout the year, we run various events to raise money to help build schools, hospitals, and other necessities in third world countries. Members contribute by helping to facilitate various events as well as spread awareness about Medlife''s mission!',
      contact_email = null,
      instagram_handle = 'medlifejfss',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Medlife']::text[]
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

-- Minga
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '2c261f83-f5f3-4ac1-9ad5-7fc1f9689b21'
    or lower(name) = lower('Minga')
    or slug = 'minga'
  order by (id = '2c261f83-f5f3-4ac1-9ad5-7fc1f9689b21') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '2c261f83-f5f3-4ac1-9ad5-7fc1f9689b21',
      'Minga',
      'minga',
      'Minga is a humanitarian club at John Fraser that works towards bringing awareness to humanitarian issues and spreading positivity within our community. Throughout the school year, we host events and fundraisers to help t',
      'Minga is a humanitarian club at John Fraser that works towards bringing awareness to humanitarian issues and spreading positivity within our community. Throughout the school year, we host events and fundraisers to help those in need, such as We Scare Hunger, Minga Market, and Postivity. Our goal is to make change in our community and globally!',
      'jfssminga@gmail.com',
      'johnfraserminga',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Minga']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Minga',
      slug = 'minga',
      short_description = 'Minga is a humanitarian club at John Fraser that works towards bringing awareness to humanitarian issues and spreading positivity within our community. Throughout the school year, we host events and fundraisers to help t',
      description = 'Minga is a humanitarian club at John Fraser that works towards bringing awareness to humanitarian issues and spreading positivity within our community. Throughout the school year, we host events and fundraisers to help those in need, such as We Scare Hunger, Minga Market, and Postivity. Our goal is to make change in our community and globally!',
      contact_email = 'jfssminga@gmail.com',
      instagram_handle = 'johnfraserminga',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Minga']::text[]
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

-- MIST (Muslim Interscholastic Tournament)
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'dde7eb33-aa38-40c1-8afa-efe596a7a19f'
    or lower(name) = lower('MIST (Muslim Interscholastic Tournament)')
    or slug = 'mist-muslim-interscholastic-tournament'
  order by (id = 'dde7eb33-aa38-40c1-8afa-efe596a7a19f') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'dde7eb33-aa38-40c1-8afa-efe596a7a19f',
      'MIST (Muslim Interscholastic Tournament)',
      'mist-muslim-interscholastic-tournament',
      'The Muslim Inter-Scholastic Tournament (MIST) is an engaging, educational, and exciting tournament geared towards connecting high school students to develop leadership, communication, and creative skills, all while gaini',
      'The Muslim Inter-Scholastic Tournament (MIST) is an engaging, educational, and exciting tournament geared towards connecting high school students to develop leadership, communication, and creative skills, all while gaining a deeper understanding of Islam. All students, regardless of their faith, are welcome to and encouraged to join! John Fraser''s MIST team regularly competes in MIST and brings home awards, lasting memories, and even make it to Nationals in the USA. MIST has something to offer for everyone: sports teams, rap battles, chant-offs, performances, and more!',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['MIST (Muslim Interscholastic Tournament)']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'MIST (Muslim Interscholastic Tournament)',
      slug = 'mist-muslim-interscholastic-tournament',
      short_description = 'The Muslim Inter-Scholastic Tournament (MIST) is an engaging, educational, and exciting tournament geared towards connecting high school students to develop leadership, communication, and creative skills, all while gaini',
      description = 'The Muslim Inter-Scholastic Tournament (MIST) is an engaging, educational, and exciting tournament geared towards connecting high school students to develop leadership, communication, and creative skills, all while gaining a deeper understanding of Islam. All students, regardless of their faith, are welcome to and encouraged to join! John Fraser''s MIST team regularly competes in MIST and brings home awards, lasting memories, and even make it to Nationals in the USA. MIST has something to offer for everyone: sports teams, rap battles, chant-offs, performances, and more!',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['MIST (Muslim Interscholastic Tournament)']::text[]
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

-- Model United Nations
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'd953747d-5da2-46b6-a44e-3963513ad38a'
    or lower(name) = lower('Model United Nations')
    or slug = 'model-united-nations'
  order by (id = 'd953747d-5da2-46b6-a44e-3963513ad38a') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'd953747d-5da2-46b6-a44e-3963513ad38a',
      'Model United Nations',
      'model-united-nations',
      'The high school’s competitive Model United Nations (MUN) team is a dynamic group of students who excel in diplomacy, public speaking, and critical thinking. They research global issues, represent different countries, and',
      'The high school’s competitive Model United Nations (MUN) team is a dynamic group of students who excel in diplomacy, public speaking, and critical thinking. They research global issues, represent different countries, and collaborate on resolutions to real-world problems. Known for their teamwork and strategic negotiation skills, they participate in conferences against other schools, often winning awards for their preparation and debate prowess. The team fosters leadership, cultural awareness, and confidence, preparing students for future roles in international relations, law, and beyond. Through rigorous practice and dedication, they have been recognized for their commitment to global citizenship.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Model United Nations']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Model United Nations',
      slug = 'model-united-nations',
      short_description = 'The high school’s competitive Model United Nations (MUN) team is a dynamic group of students who excel in diplomacy, public speaking, and critical thinking. They research global issues, represent different countries, and',
      description = 'The high school’s competitive Model United Nations (MUN) team is a dynamic group of students who excel in diplomacy, public speaking, and critical thinking. They research global issues, represent different countries, and collaborate on resolutions to real-world problems. Known for their teamwork and strategic negotiation skills, they participate in conferences against other schools, often winning awards for their preparation and debate prowess. The team fosters leadership, cultural awareness, and confidence, preparing students for future roles in international relations, law, and beyond. Through rigorous practice and dedication, they have been recognized for their commitment to global citizenship.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Model United Nations']::text[]
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

-- Muslim Student Association
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '78bce99d-6779-41f4-830f-0849285617e1'
    or lower(name) = lower('Muslim Student Association')
    or slug = 'muslim-student-association'
  order by (id = '78bce99d-6779-41f4-830f-0849285617e1') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '78bce99d-6779-41f4-830f-0849285617e1',
      'Muslim Student Association',
      'muslim-student-association',
      'What is MSA 🌙? A supportive space for Muslim students to connect. We promote Islamic values and cultural understanding in the school🤍. We organize prayers and Islamic events + spread awareness 🕋. Why join us? To conne',
      'What is MSA 🌙? A supportive space for Muslim students to connect. We promote Islamic values and cultural understanding in the school🤍. We organize prayers and Islamic events + spread awareness 🕋. Why join us? To connect with other Muslim students, participate in Islamic events and leadership opportunities, and help promote representation and understanding of Islamic values🤍. What were some of our past events? The Iftar, MuslimFest, and so much more🎉! What about upcoming events and activities..? Calligraphy workshop, scavenger hunts, The Iftar, an enhanced focus on Ramadan + IHM🤗.. and possible club merch!',
      'johnfraser.msa@gmail.com',
      'frasermsa.',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Muslim Student Association']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Muslim Student Association',
      slug = 'muslim-student-association',
      short_description = 'What is MSA 🌙? A supportive space for Muslim students to connect. We promote Islamic values and cultural understanding in the school🤍. We organize prayers and Islamic events + spread awareness 🕋. Why join us? To conne',
      description = 'What is MSA 🌙? A supportive space for Muslim students to connect. We promote Islamic values and cultural understanding in the school🤍. We organize prayers and Islamic events + spread awareness 🕋. Why join us? To connect with other Muslim students, participate in Islamic events and leadership opportunities, and help promote representation and understanding of Islamic values🤍. What were some of our past events? The Iftar, MuslimFest, and so much more🎉! What about upcoming events and activities..? Calligraphy workshop, scavenger hunts, The Iftar, an enhanced focus on Ramadan + IHM🤗.. and possible club merch!',
      contact_email = 'johnfraser.msa@gmail.com',
      instagram_handle = 'frasermsa.',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Muslim Student Association']::text[]
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

-- Neuropsychology 101
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'bd2711e9-9a41-4a28-a8ea-4304780a6641'
    or lower(name) = lower('Neuropsychology 101')
    or slug = 'neuropsychology-101'
  order by (id = 'bd2711e9-9a41-4a28-a8ea-4304780a6641') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'bd2711e9-9a41-4a28-a8ea-4304780a6641',
      'Neuropsychology 101',
      'neuropsychology-101',
      'Neuropsych 101 is a club where students can explore neuroscience and psychology! We meet biweekly to dive into new topics, engage in activities, and enjoy open events like Trivia Night, Muse Meditation and Sheep Brain Di',
      'Neuropsych 101 is a club where students can explore neuroscience and psychology! We meet biweekly to dive into new topics, engage in activities, and enjoy open events like Trivia Night, Muse Meditation and Sheep Brain Dissection. Whether you''re a beginner or already interested in the brain, joining Neuropsych 101 is a fantastic way to learn, have fun, and connect with others who share your curiosity :)',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Neuropsychology 101']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Neuropsychology 101',
      slug = 'neuropsychology-101',
      short_description = 'Neuropsych 101 is a club where students can explore neuroscience and psychology! We meet biweekly to dive into new topics, engage in activities, and enjoy open events like Trivia Night, Muse Meditation and Sheep Brain Di',
      description = 'Neuropsych 101 is a club where students can explore neuroscience and psychology! We meet biweekly to dive into new topics, engage in activities, and enjoy open events like Trivia Night, Muse Meditation and Sheep Brain Dissection. Whether you''re a beginner or already interested in the brain, joining Neuropsych 101 is a fantastic way to learn, have fun, and connect with others who share your curiosity :)',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Neuropsychology 101']::text[]
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

-- Palestinian Student Association
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '9f1f077a-dff7-4750-b32d-1248383fc259'
    or lower(name) = lower('Palestinian Student Association')
    or slug = 'palestinian-student-association'
  order by (id = '9f1f077a-dff7-4750-b32d-1248383fc259') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '9f1f077a-dff7-4750-b32d-1248383fc259',
      'Palestinian Student Association',
      'palestinian-student-association',
      'John Fraser''s Palestinian Student Association is a club committed to showcasing Palestine''s beautiful culture, traditions, and customs, providing a space for Palestinian students and allies, and raising awareness for the',
      'John Fraser''s Palestinian Student Association is a club committed to showcasing Palestine''s beautiful culture, traditions, and customs, providing a space for Palestinian students and allies, and raising awareness for the issues of our people.',
      null,
      'jfsspsa',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Palestinian Student Association']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Palestinian Student Association',
      slug = 'palestinian-student-association',
      short_description = 'John Fraser''s Palestinian Student Association is a club committed to showcasing Palestine''s beautiful culture, traditions, and customs, providing a space for Palestinian students and allies, and raising awareness for the',
      description = 'John Fraser''s Palestinian Student Association is a club committed to showcasing Palestine''s beautiful culture, traditions, and customs, providing a space for Palestinian students and allies, and raising awareness for the issues of our people.',
      contact_email = null,
      instagram_handle = 'jfsspsa',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Palestinian Student Association']::text[]
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

-- Peer Mentoring
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '38733e7a-4df2-405e-be93-f8883886e6b7'
    or lower(name) = lower('Peer Mentoring')
    or slug = 'peer-mentoring'
  order by (id = '38733e7a-4df2-405e-be93-f8883886e6b7') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '38733e7a-4df2-405e-be93-f8883886e6b7',
      'Peer Mentoring',
      'peer-mentoring',
      'Peer Mentoring is a group of trained senior students who are the student-body extension of the guidance department. We aim to foster a positive environment, promote care for mental health, and create a smooth transition ',
      'Peer Mentoring is a group of trained senior students who are the student-body extension of the guidance department. We aim to foster a positive environment, promote care for mental health, and create a smooth transition into highschool. We work closely with students who request mentors and a broader range through classroom workshops and school wide events. Anyone can request a mentor anytime during the year through our Instagram (@jfsspeermentoring) or through the Guidance Brightspace or their Guidance counsellor!',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Peer Mentoring']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Peer Mentoring',
      slug = 'peer-mentoring',
      short_description = 'Peer Mentoring is a group of trained senior students who are the student-body extension of the guidance department. We aim to foster a positive environment, promote care for mental health, and create a smooth transition ',
      description = 'Peer Mentoring is a group of trained senior students who are the student-body extension of the guidance department. We aim to foster a positive environment, promote care for mental health, and create a smooth transition into highschool. We work closely with students who request mentors and a broader range through classroom workshops and school wide events. Anyone can request a mentor anytime during the year through our Instagram (@jfsspeermentoring) or through the Guidance Brightspace or their Guidance counsellor!',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Peer Mentoring']::text[]
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

-- Philosophy and Ethics Society
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'f073dd65-67b6-4483-bb6d-2152d28ef666'
    or lower(name) = lower('Philosophy and Ethics Society')
    or slug = 'philosophy-and-ethics-society'
  order by (id = 'f073dd65-67b6-4483-bb6d-2152d28ef666') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'f073dd65-67b6-4483-bb6d-2152d28ef666',
      'Philosophy and Ethics Society',
      'philosophy-and-ethics-society',
      'Frasers Philosophy and Ethics Society aims to teach students about the different kinds of philosophical and ethical views of past and present, and how they interconnect with one another through fun games and debates.',
      'Frasers Philosophy and Ethics Society aims to teach students about the different kinds of philosophical and ethical views of past and present, and how they interconnect with one another through fun games and debates.',
      'jfss.philosophyandethics.society@gmail.com',
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Philosophy and Ethics Society']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Philosophy and Ethics Society',
      slug = 'philosophy-and-ethics-society',
      short_description = 'Frasers Philosophy and Ethics Society aims to teach students about the different kinds of philosophical and ethical views of past and present, and how they interconnect with one another through fun games and debates.',
      description = 'Frasers Philosophy and Ethics Society aims to teach students about the different kinds of philosophical and ethical views of past and present, and how they interconnect with one another through fun games and debates.',
      contact_email = 'jfss.philosophyandethics.society@gmail.com',
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Philosophy and Ethics Society']::text[]
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

-- Project Luminosity
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '977c9d3c-133d-4d1f-a795-1cb6e568b22f'
    or lower(name) = lower('Project Luminosity')
    or slug = 'project-luminosity'
  order by (id = '977c9d3c-133d-4d1f-a795-1cb6e568b22f') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '977c9d3c-133d-4d1f-a795-1cb6e568b22f',
      'Project Luminosity',
      'project-luminosity',
      'A club focused on providing helpful information and recourses regarding education, graduation, and extracurriculars giving students insight on key info helpful to post secondary success',
      'A club focused on providing helpful information and recourses regarding education, graduation, and extracurriculars giving students insight on key info helpful to post secondary success',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Project Luminosity']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Project Luminosity',
      slug = 'project-luminosity',
      short_description = 'A club focused on providing helpful information and recourses regarding education, graduation, and extracurriculars giving students insight on key info helpful to post secondary success',
      description = 'A club focused on providing helpful information and recourses regarding education, graduation, and extracurriculars giving students insight on key info helpful to post secondary success',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Project Luminosity']::text[]
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

-- RClub
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'b74ec12c-a777-4168-98c0-c6735b247164'
    or lower(name) = lower('RClub')
    or slug = 'rclub'
  order by (id = 'b74ec12c-a777-4168-98c0-c6735b247164') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'b74ec12c-a777-4168-98c0-c6735b247164',
      'RClub',
      'rclub',
      'The purpose of RClub is to create a safe, inclusive environment where like-minded car enthusiasts can come together to learn more about automobiles on a smaller scale. Firstly, as you may know, many students at John Fras',
      'The purpose of RClub is to create a safe, inclusive environment where like-minded car enthusiasts can come together to learn more about automobiles on a smaller scale. Firstly, as you may know, many students at John Fraser were not able to take the auto tech courses due to the excessive volume. This poses a problem as students feel excluded and separated from their school body simply because their interests were not fulfilled. In this way, the RClub will work to solve the problem as students are will be given the opportunity to join a club similar to their desired auto course. For the academic year 2024-2025, the goal of the RClub is to teach lessons and material that educates students about the functions of an RC car, similar to a full sized vehicle. Moreover, students will benefit from joining the RClub as we will be working with risk-free RC (Remote Control) cars rather than street cars. This is significant as safety is a top priority.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['RClub']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'RClub',
      slug = 'rclub',
      short_description = 'The purpose of RClub is to create a safe, inclusive environment where like-minded car enthusiasts can come together to learn more about automobiles on a smaller scale. Firstly, as you may know, many students at John Fras',
      description = 'The purpose of RClub is to create a safe, inclusive environment where like-minded car enthusiasts can come together to learn more about automobiles on a smaller scale. Firstly, as you may know, many students at John Fraser were not able to take the auto tech courses due to the excessive volume. This poses a problem as students feel excluded and separated from their school body simply because their interests were not fulfilled. In this way, the RClub will work to solve the problem as students are will be given the opportunity to join a club similar to their desired auto course. For the academic year 2024-2025, the goal of the RClub is to teach lessons and material that educates students about the functions of an RC car, similar to a full sized vehicle. Moreover, students will benefit from joining the RClub as we will be working with risk-free RC (Remote Control) cars rather than street cars. This is significant as safety is a top priority.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['RClub']::text[]
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

-- RISE
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'e87526f1-604b-410b-9b2a-c22d07ae8f4b'
    or lower(name) = lower('RISE')
    or slug = 'rise'
  order by (id = 'e87526f1-604b-410b-9b2a-c22d07ae8f4b') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'e87526f1-604b-410b-9b2a-c22d07ae8f4b',
      'RISE',
      'rise',
      'CARE is an acronym for Cancer Awareness Research and Education. It''s a part of a wider nonprofit that''s mostly based out in America. We''re dedicated to bringing more awareness regarding Cancer into Ontario, more specific',
      'CARE is an acronym for Cancer Awareness Research and Education. It''s a part of a wider nonprofit that''s mostly based out in America. We''re dedicated to bringing more awareness regarding Cancer into Ontario, more specifically, John Fraser. We''re looking into hosting events to make a cancer patient''s day a little brighter!',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['RISE']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'RISE',
      slug = 'rise',
      short_description = 'CARE is an acronym for Cancer Awareness Research and Education. It''s a part of a wider nonprofit that''s mostly based out in America. We''re dedicated to bringing more awareness regarding Cancer into Ontario, more specific',
      description = 'CARE is an acronym for Cancer Awareness Research and Education. It''s a part of a wider nonprofit that''s mostly based out in America. We''re dedicated to bringing more awareness regarding Cancer into Ontario, more specifically, John Fraser. We''re looking into hosting events to make a cancer patient''s day a little brighter!',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['RISE']::text[]
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

-- Robotics Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'c66bb3b0-3868-4f80-b5dd-e9c9107dfca8'
    or lower(name) = lower('Robotics Club')
    or slug = 'robotics-club'
  order by (id = 'c66bb3b0-3868-4f80-b5dd-e9c9107dfca8') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'c66bb3b0-3868-4f80-b5dd-e9c9107dfca8',
      'Robotics Club',
      'robotics-club',
      'A club for John Fraser students to learn and create various robots and automated machines and will use them by competing in the 2026 CETA and/or SKILLS competition.',
      'A club for John Fraser students to learn and create various robots and automated machines and will use them by competing in the 2026 CETA and/or SKILLS competition.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Robotics Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Robotics Club',
      slug = 'robotics-club',
      short_description = 'A club for John Fraser students to learn and create various robots and automated machines and will use them by competing in the 2026 CETA and/or SKILLS competition.',
      description = 'A club for John Fraser students to learn and create various robots and automated machines and will use them by competing in the 2026 CETA and/or SKILLS competition.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Robotics Club']::text[]
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

-- Rock Band
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '628a9a5a-fd0d-4872-aa6a-f72cca795e69'
    or lower(name) = lower('Rock Band')
    or slug = 'rock-band'
  order by (id = '628a9a5a-fd0d-4872-aa6a-f72cca795e69') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '628a9a5a-fd0d-4872-aa6a-f72cca795e69',
      'Rock Band',
      'rock-band',
      'The Rock Band is a team of musicians who work together to rehearse and perform live music of Rock or Pop songs. Our band consists of instruments like Drums, Guitar, Bass, Keyboard and Vocals. Our goal is to add more uniq',
      'The Rock Band is a team of musicians who work together to rehearse and perform live music of Rock or Pop songs. Our band consists of instruments like Drums, Guitar, Bass, Keyboard and Vocals. Our goal is to add more unique music opportunities in the school to give students a chance to gain experience performing or watch a live performance. We hold shows in school for the students at John Fraser and sometimes at events outside of school. We hope to spread a love for Rock and the overall music we share.',
      'johnfraserrockband@gmail.com',
      'jfss.rockband',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Rock Band']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Rock Band',
      slug = 'rock-band',
      short_description = 'The Rock Band is a team of musicians who work together to rehearse and perform live music of Rock or Pop songs. Our band consists of instruments like Drums, Guitar, Bass, Keyboard and Vocals. Our goal is to add more uniq',
      description = 'The Rock Band is a team of musicians who work together to rehearse and perform live music of Rock or Pop songs. Our band consists of instruments like Drums, Guitar, Bass, Keyboard and Vocals. Our goal is to add more unique music opportunities in the school to give students a chance to gain experience performing or watch a live performance. We hold shows in school for the students at John Fraser and sometimes at events outside of school. We hope to spread a love for Rock and the overall music we share.',
      contact_email = 'johnfraserrockband@gmail.com',
      instagram_handle = 'jfss.rockband',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Rock Band']::text[]
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

-- Sikh Students Association
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '98c85b67-47c5-4623-8174-9e19cda75e55'
    or lower(name) = lower('Sikh Students Association')
    or slug = 'sikh-students-association'
  order by (id = '98c85b67-47c5-4623-8174-9e19cda75e55') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '98c85b67-47c5-4623-8174-9e19cda75e55',
      'Sikh Students Association',
      'sikh-students-association',
      'To educate and spread knowledge about Sikhism throughout the student body with school-wide events and opportunities for all students regardless of their background. All are welcome to join!',
      'To educate and spread knowledge about Sikhism throughout the student body with school-wide events and opportunities for all students regardless of their background. All are welcome to join!',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Sikh Students Association']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Sikh Students Association',
      slug = 'sikh-students-association',
      short_description = 'To educate and spread knowledge about Sikhism throughout the student body with school-wide events and opportunities for all students regardless of their background. All are welcome to join!',
      description = 'To educate and spread knowledge about Sikhism throughout the student body with school-wide events and opportunities for all students regardless of their background. All are welcome to join!',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Sikh Students Association']::text[]
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

-- Soccer Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '6f9d0e4e-ec5d-41e0-9069-8865e2bbd8f5'
    or lower(name) = lower('Soccer Club')
    or slug = 'soccer-club'
  order by (id = '6f9d0e4e-ec5d-41e0-9069-8865e2bbd8f5') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '6f9d0e4e-ec5d-41e0-9069-8865e2bbd8f5',
      'Soccer Club',
      'soccer-club',
      'The Soccer Club is a dynamic space for all skill levels, focusing on both practice and fun games. Whether you''re new to the sport or looking to sharpen your skills, the club offers structured practice sessions that targe',
      'The Soccer Club is a dynamic space for all skill levels, focusing on both practice and fun games. Whether you''re new to the sport or looking to sharpen your skills, the club offers structured practice sessions that target core techniques like dribbling, passing, and shooting, helping players build confidence and improve. Alongside training, we play a variety of friendly matches and small-sided games that encourage teamwork and quick thinking in a relaxed environment. Our goal is to foster a love for soccer, encourage physical fitness, and create a positive, inclusive community where everyone can enjoy the game.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Soccer Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Soccer Club',
      slug = 'soccer-club',
      short_description = 'The Soccer Club is a dynamic space for all skill levels, focusing on both practice and fun games. Whether you''re new to the sport or looking to sharpen your skills, the club offers structured practice sessions that targe',
      description = 'The Soccer Club is a dynamic space for all skill levels, focusing on both practice and fun games. Whether you''re new to the sport or looking to sharpen your skills, the club offers structured practice sessions that target core techniques like dribbling, passing, and shooting, helping players build confidence and improve. Alongside training, we play a variety of friendly matches and small-sided games that encourage teamwork and quick thinking in a relaxed environment. Our goal is to foster a love for soccer, encourage physical fitness, and create a positive, inclusive community where everyone can enjoy the game.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Soccer Club']::text[]
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

-- South Asian Society
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '3d8db870-3b3d-4868-b866-639726127859'
    or lower(name) = lower('South Asian Society')
    or slug = 'south-asian-society'
  order by (id = '3d8db870-3b3d-4868-b866-639726127859') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '3d8db870-3b3d-4868-b866-639726127859',
      'South Asian Society',
      'south-asian-society',
      'South Asian Society aims to provide South Asians a sense of inclusion and a chance to reconnect with their heritage. We aim to provide a supportive system where you can delve deeper into your identity, whether you''ve gro',
      'South Asian Society aims to provide South Asians a sense of inclusion and a chance to reconnect with their heritage. We aim to provide a supportive system where you can delve deeper into your identity, whether you''ve grown up in your traditions or are just beginning to discover them. Our club offers a lively and energetic space for all students and is not just restricted to South Asians , but also our allies. We actively encourage people who simply wish to be a part of a dynamic, inclusive group and welcome everyone with open arms.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['South Asian Society']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'South Asian Society',
      slug = 'south-asian-society',
      short_description = 'South Asian Society aims to provide South Asians a sense of inclusion and a chance to reconnect with their heritage. We aim to provide a supportive system where you can delve deeper into your identity, whether you''ve gro',
      description = 'South Asian Society aims to provide South Asians a sense of inclusion and a chance to reconnect with their heritage. We aim to provide a supportive system where you can delve deeper into your identity, whether you''ve grown up in your traditions or are just beginning to discover them. Our club offers a lively and energetic space for all students and is not just restricted to South Asians , but also our allies. We actively encourage people who simply wish to be a part of a dynamic, inclusive group and welcome everyone with open arms.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['South Asian Society']::text[]
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

-- STEAM Innovation Challenge (John Fraser Chapter)
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '96012aef-ea20-4580-879d-21f97f3c4761'
    or lower(name) = lower('STEAM Innovation Challenge (John Fraser Chapter)')
    or slug = 'steam-innovation-challenge-john-fraser-chapter'
  order by (id = '96012aef-ea20-4580-879d-21f97f3c4761') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '96012aef-ea20-4580-879d-21f97f3c4761',
      'STEAM Innovation Challenge (John Fraser Chapter)',
      'steam-innovation-challenge-john-fraser-chapter',
      'STEAM Innovation Challenge is a competition based club where students will have an entire year to work on a prompt given by steaminnovationchallenge.org. They will have the choice to compete in three different categories',
      'STEAM Innovation Challenge is a competition based club where students will have an entire year to work on a prompt given by steaminnovationchallenge.org. They will have the choice to compete in three different categories: Engineering, Life Sciences, and Astronomy. Students will write a full scientific report, and present a model of their innovation to a judge with experience in the respective field at the STEAM IC Annual Conference held in May.',
      'jfss.steam.innovationchallenge@gmail.com',
      'jfss.steam.innovation',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['STEAM Innovation Challenge (John Fraser Chapter)']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'STEAM Innovation Challenge (John Fraser Chapter)',
      slug = 'steam-innovation-challenge-john-fraser-chapter',
      short_description = 'STEAM Innovation Challenge is a competition based club where students will have an entire year to work on a prompt given by steaminnovationchallenge.org. They will have the choice to compete in three different categories',
      description = 'STEAM Innovation Challenge is a competition based club where students will have an entire year to work on a prompt given by steaminnovationchallenge.org. They will have the choice to compete in three different categories: Engineering, Life Sciences, and Astronomy. Students will write a full scientific report, and present a model of their innovation to a judge with experience in the respective field at the STEAM IC Annual Conference held in May.',
      contact_email = 'jfss.steam.innovationchallenge@gmail.com',
      instagram_handle = 'jfss.steam.innovation',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['STEAM Innovation Challenge (John Fraser Chapter)']::text[]
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

-- Student Activity Council (SAC)
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '5b8da50e-2578-44df-85db-7ee4698b4cf2'
    or lower(name) = lower('Student Activity Council (SAC)')
    or slug = 'student-activity-council-sac'
  order by (id = '5b8da50e-2578-44df-85db-7ee4698b4cf2') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '5b8da50e-2578-44df-85db-7ee4698b4cf2',
      'Student Activity Council (SAC)',
      'student-activity-council-sac',
      'SAC stands for "Student Activity Council". We are a team of John Fraser students committed to enhancing your high school experience through a diverse array of events!',
      'SAC stands for "Student Activity Council". We are a team of John Fraser students committed to enhancing your high school experience through a diverse array of events!',
      'johnfraserstudentcouncil@gmail.com',
      'johnfrasersac',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Student Activity Council (SAC)']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Student Activity Council (SAC)',
      slug = 'student-activity-council-sac',
      short_description = 'SAC stands for "Student Activity Council". We are a team of John Fraser students committed to enhancing your high school experience through a diverse array of events!',
      description = 'SAC stands for "Student Activity Council". We are a team of John Fraser students committed to enhancing your high school experience through a diverse array of events!',
      contact_email = 'johnfraserstudentcouncil@gmail.com',
      instagram_handle = 'johnfrasersac',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Student Activity Council (SAC)']::text[]
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

-- The Fraser Post
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '30ae9222-43eb-4ee3-90eb-68bfdb1a432c'
    or lower(name) = lower('The Fraser Post')
    or slug = 'the-fraser-post'
  order by (id = '30ae9222-43eb-4ee3-90eb-68bfdb1a432c') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '30ae9222-43eb-4ee3-90eb-68bfdb1a432c',
      'The Fraser Post',
      'the-fraser-post',
      'The official student magazine dedicated to sharing creative work with the student body.',
      'The official student magazine dedicated to sharing creative work with the student body.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['The Fraser Post']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'The Fraser Post',
      slug = 'the-fraser-post',
      short_description = 'The official student magazine dedicated to sharing creative work with the student body.',
      description = 'The official student magazine dedicated to sharing creative work with the student body.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['The Fraser Post']::text[]
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

-- The Pinnacle Project
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'f5fb00a1-db29-4b9b-83e4-6f9c6c083812'
    or lower(name) = lower('The Pinnacle Project')
    or slug = 'the-pinnacle-project'
  order by (id = 'f5fb00a1-db29-4b9b-83e4-6f9c6c083812') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'f5fb00a1-db29-4b9b-83e4-6f9c6c083812',
      'The Pinnacle Project',
      'the-pinnacle-project',
      'A youth-led volunteer organization dedicated to improving the GTA community through collaborations with greater NPOs.',
      'A youth-led volunteer organization dedicated to improving the GTA community through collaborations with greater NPOs.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['The Pinnacle Project']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'The Pinnacle Project',
      slug = 'the-pinnacle-project',
      short_description = 'A youth-led volunteer organization dedicated to improving the GTA community through collaborations with greater NPOs.',
      description = 'A youth-led volunteer organization dedicated to improving the GTA community through collaborations with greater NPOs.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['The Pinnacle Project']::text[]
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

-- The Robotics Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'abccb979-b77c-4066-9ad1-f53363fa7bdc'
    or lower(name) = lower('The Robotics Club')
    or slug = 'the-robotics-club'
  order by (id = 'abccb979-b77c-4066-9ad1-f53363fa7bdc') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'abccb979-b77c-4066-9ad1-f53363fa7bdc',
      'The Robotics Club',
      'the-robotics-club',
      'We provide JFSS students the opportunity to explore, create and innovate with robotics solutions in order to tackle real world problems and create a better tomorrow.',
      'We provide JFSS students the opportunity to explore, create and innovate with robotics solutions in order to tackle real world problems and create a better tomorrow.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['The Robotics Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'The Robotics Club',
      slug = 'the-robotics-club',
      short_description = 'We provide JFSS students the opportunity to explore, create and innovate with robotics solutions in order to tackle real world problems and create a better tomorrow.',
      description = 'We provide JFSS students the opportunity to explore, create and innovate with robotics solutions in order to tackle real world problems and create a better tomorrow.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['The Robotics Club']::text[]
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

-- Visual Arts Club
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = '9c894e6d-8d1b-4638-b0a2-5d82d3330744'
    or lower(name) = lower('Visual Arts Club')
    or slug = 'visual-arts-club'
  order by (id = '9c894e6d-8d1b-4638-b0a2-5d82d3330744') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      '9c894e6d-8d1b-4638-b0a2-5d82d3330744',
      'Visual Arts Club',
      'visual-arts-club',
      'The Visual Arts Club is a supportive space for passionate artists! Our events are drop-in and open to all skill levels. Enjoy drawing, sketching, crafting, and much more while connecting with fellow like-minded artists!',
      'The Visual Arts Club is a supportive space for passionate artists! Our events are drop-in and open to all skill levels. Enjoy drawing, sketching, crafting, and much more while connecting with fellow like-minded artists!',
      'jfssvisualarts@gmail.com',
      'jfssvisualarts',
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Visual Arts Club']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Visual Arts Club',
      slug = 'visual-arts-club',
      short_description = 'The Visual Arts Club is a supportive space for passionate artists! Our events are drop-in and open to all skill levels. Enjoy drawing, sketching, crafting, and much more while connecting with fellow like-minded artists!',
      description = 'The Visual Arts Club is a supportive space for passionate artists! Our events are drop-in and open to all skill levels. Enjoy drawing, sketching, crafting, and much more while connecting with fellow like-minded artists!',
      contact_email = 'jfssvisualarts@gmail.com',
      instagram_handle = 'jfssvisualarts',
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Visual Arts Club']::text[]
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

-- Warm Wishes
do $club_seed$
declare
  v_club_id uuid;
  v_is_imported_seed boolean;
begin
  select id, is_imported_seed
  into v_club_id, v_is_imported_seed
  from public.clubs
  where
    id = 'd6ce7a63-c9e7-4486-8606-78852cc4dcf6'
    or lower(name) = lower('Warm Wishes')
    or slug = 'warm-wishes'
  order by (id = 'd6ce7a63-c9e7-4486-8606-78852cc4dcf6') desc, is_imported_seed desc
  limit 1;

  if v_club_id is null then
    insert into public.clubs (
      id, name, slug, short_description, description, contact_email,
      instagram_handle, meeting_location, meeting_schedule, status,
      created_by, source_label, eligible_for_reapplication, is_imported_seed, source_names
    )
    values (
      'd6ce7a63-c9e7-4486-8606-78852cc4dcf6',
      'Warm Wishes',
      'warm-wishes',
      'Warm Wishes partners with local long-term care centers, connecting students with residents through a pen pal system. Members write weekly letters to brighten the residents'' days, fostering friendships across generations.',
      'Warm Wishes partners with local long-term care centers, connecting students with residents through a pen pal system. Members write weekly letters to brighten the residents'' days, fostering friendships across generations. Alongside letters, the club sends handmade gifts and holiday tokens for Christmas, Thanksgiving, and New Year’s, spreading joy and inclusivity. This interactive experience also offers students insight into elder care and long-term care, valuable for those interested in healthcare hospitality. Through these meaningful exchanges, Warm Wishes aims to bring positivity and support to residents who may lack family connections during special times of the year.',
      null,
      null,
      null,
      null,
      'APPROVED',
      null,
      'Past Clubs',
      true,
      true,
      array['Warm Wishes']::text[]
    )
    returning id into v_club_id;
  elsif v_is_imported_seed then
    update public.clubs
    set
      name = 'Warm Wishes',
      slug = 'warm-wishes',
      short_description = 'Warm Wishes partners with local long-term care centers, connecting students with residents through a pen pal system. Members write weekly letters to brighten the residents'' days, fostering friendships across generations.',
      description = 'Warm Wishes partners with local long-term care centers, connecting students with residents through a pen pal system. Members write weekly letters to brighten the residents'' days, fostering friendships across generations. Alongside letters, the club sends handmade gifts and holiday tokens for Christmas, Thanksgiving, and New Year’s, spreading joy and inclusivity. This interactive experience also offers students insight into elder care and long-term care, valuable for those interested in healthcare hospitality. Through these meaningful exchanges, Warm Wishes aims to bring positivity and support to residents who may lack family connections during special times of the year.',
      contact_email = null,
      instagram_handle = null,
      meeting_location = null,
      meeting_schedule = null,
      source_label = 'Past Clubs',
      eligible_for_reapplication = true,
      source_names = array['Warm Wishes']::text[]
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
      ('Fraser Aces (F.A.C.E.)', 'fraser-aces-face'),
      ('Aid4Need', 'aid4need'),
      ('Announcements Club', 'announcements-club'),
      ('AP Student Society', 'ap-student-society'),
      ('Arts Council', 'arts-council'),
      ('Aviation Club', 'aviation-club'),
      ('AV Club', 'av-club'),
      ('Black Student and Allies Association', 'black-student-and-allies-association'),
      ('Creative Writing Club', 'creative-writing-club'),
      ('Chapter One', 'chapter-one'),
      ('Chemistry Club', 'chemistry-club'),
      ('Christian Club (Project 153)', 'christian-club-project-153'),
      ('Commerce Club', 'commerce-club'),
      ('Crochet Club', 'crochet-club'),
      ('Data Science Club', 'data-science-club'),
      ('DECA', 'deca'),
      ('Dental Society', 'dental-society'),
      ('Design Club', 'design-club'),
      ('Digital Security Club', 'digital-security-club'),
      ('East Asian Students Association', 'east-asian-students-association'),
      ('Engineering Club', 'engineering-club'),
      ('Environmental Club', 'environmental-club'),
      ('Fitness Club', 'fitness-club'),
      ('Fraser Athletic Council (FAC)', 'fraser-athletic-council-fac'),
      ('Fraser Chefs', 'fraser-chefs'),
      ('Fraser Esports', 'fraser-esports'),
      ('Fraser Scholars', 'fraser-scholars'),
      ('Fraser STEM Club', 'fraser-stem-club'),
      ('French Club', 'french-club'),
      ('Future Leader Initiative (FLIQ)', 'future-leader-initiative-fliq'),
      ('Hindu Student Association', 'hindu-student-association'),
      ('HOSA John Fraser', 'hosa-john-fraser'),
      ('iNNOVATE', 'innovate'),
      ('Investment Club', 'investment-club'),
      ('Jack.org', 'jackorg'),
      ('JFSS Biology Club', 'jfss-biology-club'),
      ('JFSS Cyber Computing Club', 'jfss-cyber-computing-club'),
      ('JFSS Photography Club', 'jfss-photography-club'),
      ('JFSS PsychSociety', 'jfss-psychsociety'),
      ('JFSS Sending Sunshine', 'jfss-sending-sunshine'),
      ('John Fraser Debate Society', 'john-fraser-debate-society'),
      ('John Fraser''s Astronomy Club', 'john-frasers-astronomy-club'),
      ('John Fraser''s Business Society', 'john-frasers-business-society'),
      ('John Fraser''s Law Club', 'john-frasers-law-club'),
      ('JFSS INTERACT', 'jfss-interact'),
      ('Journaling Club', 'journaling-club'),
      ('Kinesiology Club', 'kinesiology-club'),
      ('Ladybug Magazine', 'ladybug-magazine'),
      ('Math Club', 'math-club'),
      ('Medlife', 'medlife'),
      ('Minga', 'minga'),
      ('MIST (Muslim Interscholastic Tournament)', 'mist-muslim-interscholastic-tournament'),
      ('Model United Nations', 'model-united-nations'),
      ('Muslim Student Association', 'muslim-student-association'),
      ('Neuropsychology 101', 'neuropsychology-101'),
      ('Palestinian Student Association', 'palestinian-student-association'),
      ('Peer Mentoring', 'peer-mentoring'),
      ('Philosophy and Ethics Society', 'philosophy-and-ethics-society'),
      ('Project Luminosity', 'project-luminosity'),
      ('RClub', 'rclub'),
      ('RISE', 'rise'),
      ('Robotics Club', 'robotics-club'),
      ('Rock Band', 'rock-band'),
      ('Sikh Students Association', 'sikh-students-association'),
      ('Soccer Club', 'soccer-club'),
      ('South Asian Society', 'south-asian-society'),
      ('STEAM Innovation Challenge (John Fraser Chapter)', 'steam-innovation-challenge-john-fraser-chapter'),
      ('Student Activity Council (SAC)', 'student-activity-council-sac'),
      ('The Fraser Post', 'the-fraser-post'),
      ('The Pinnacle Project', 'the-pinnacle-project'),
      ('The Robotics Club', 'the-robotics-club'),
      ('Visual Arts Club', 'visual-arts-club'),
      ('Warm Wishes', 'warm-wishes')
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
  if v_resolved_count < 73 then
    raise exception 'Past clubs seed incomplete: expected 73 resolved canonical clubs, found %', v_resolved_count;
  end if;
end $$;
