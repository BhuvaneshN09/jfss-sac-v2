-- Archived clubs with an active current-year re-application should appear in
-- the reapplication workflow, not in the archived-club queue.

drop function if exists public.list_archived_clubs(text);

create or replace function public.list_archived_clubs(
  p_search text default null
)
returns table (
  club_id uuid,
  name text,
  slug text,
  description text,
  short_description text,
  logo_url text,
  last_active_school_year text,
  archived_at timestamptz,
  archived_by uuid,
  archived_by_email text,
  archived_by_name text,
  eligible_for_reapplication boolean,
  creation_origin text,
  registration_request_count bigint,
  reapplication_request_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text;
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

  v_q := nullif(lower(btrim(coalesce(p_search, ''))), '');
  v_year := public.get_current_club_school_year();

  return query
  select
    c.id,
    c.name,
    c.slug,
    c.description,
    c.short_description,
    c.logo_url,
    c.last_active_school_year,
    c.archived_at,
    c.archived_by,
    p.email,
    p.full_name,
    c.eligible_for_reapplication,
    c.creation_origin,
    (
      select count(*)::bigint
      from public.club_registration_requests r
      where r.created_club_id = c.id
    ),
    (
      select count(*)::bigint
      from public.club_reapplication_requests r
      where r.club_id = c.id
    )
  from public.clubs c
  left join public.profiles p on p.id = c.archived_by
  where c.status = 'ARCHIVED'
    and c.deleted_at is null
    and not exists (
      select 1
      from public.club_reapplication_requests r
      where r.club_id = c.id
        and r.school_year = v_year
        and r.status in (
          'SUBMITTED',
          'UNDER_REVIEW',
          'CHANGES_REQUESTED',
          'APPROVED'
        )
    )
    and (
      v_q is null
      or lower(c.name) like '%' || v_q || '%'
      or lower(c.slug) like '%' || v_q || '%'
      or lower(coalesce(c.description, '')) like '%' || v_q || '%'
      or lower(coalesce(c.short_description, '')) like '%' || v_q || '%'
    )
  order by c.archived_at desc nulls last, c.name;
end;
$$;

revoke all on function public.list_archived_clubs(text)
from public, anon;

grant execute on function public.list_archived_clubs(text)
to authenticated;
