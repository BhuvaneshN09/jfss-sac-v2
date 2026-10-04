-- Official club list for the Google Sheet sync.
-- Approved + currently active clubs that have at least one teacher supervisor.
-- Does not change existing club data.

create or replace function public.get_official_club_sheet()
returns table (
  club_id uuid,
  club_name text,
  club_type text,
  description text,
  club_leaders text,
  teacher_supervisors text,
  meeting_dates text,
  club_location text,
  contact_information text,
  member_application_url text,
  exec_application_url text,
  school_year text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    club.id as club_id,
    club.name as club_name,
    case
      when club.creation_origin = 'NEW_APPLICATION' then 'New club'
      else 'Old club'
    end as club_type,
    club.description,
    coalesce(nullif(btrim(club.owner_names), ''), '') as club_leaders,
    (
      select string_agg(
        advisor.supervisor_name,
        ', '
        order by advisor.supervisor_name
      )
      from public.club_advisors as advisor
      where advisor.club_id = club.id
        and advisor.school_year = year_state.school_year
        and advisor.status = 'ACTIVE'
    ) as teacher_supervisors,
    nullif(
      btrim(
        concat_ws(
          ' · ',
          nullif(array_to_string(club.meeting_days, ', '), ''),
          nullif(btrim(coalesce(club.meeting_time_details, '')), ''),
          case
            when club.meeting_schedule is null then null
            when lower(btrim(club.meeting_schedule)) in ('', 'biweekly') then null
            else btrim(club.meeting_schedule)
          end
        )
      ),
      ''
    ) as meeting_dates,
    nullif(btrim(coalesce(club.meeting_location, '')), '') as club_location,
    nullif(
      btrim(
        concat_ws(
          ' · ',
          club.contact_email,
          case
            when nullif(btrim(coalesce(club.instagram_handle, '')), '') is null then null
            else
              'Instagram: '
              || regexp_replace(btrim(club.instagram_handle), '^@+', '')
          end
        )
      ),
      ''
    ) as contact_information,
    club.member_application_url,
    club.exec_application_url,
    year_state.school_year,
    club.updated_at
  from public.clubs as club
  join public.club_school_years as year_state
    on year_state.club_id = club.id
  where club.status = 'APPROVED'
    and club.deleted_at is null
    and year_state.school_year = public.get_current_club_school_year()
    and year_state.status = 'ACTIVE'
    and exists (
      select 1
      from public.club_advisors as advisor
      where advisor.club_id = club.id
        and advisor.school_year = year_state.school_year
        and advisor.status = 'ACTIVE'
    )
  order by lower(club.name);
$$;

comment on function public.get_official_club_sheet() is
  'Sheet sync: current-year approved clubs with at least one active teacher supervisor.';

revoke all on function public.get_official_club_sheet() from public, anon, authenticated;
grant execute on function public.get_official_club_sheet() to service_role;
