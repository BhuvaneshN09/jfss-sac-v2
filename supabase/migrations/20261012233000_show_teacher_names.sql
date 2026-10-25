-- Staff IDs such as P0188579 were saved as supervisor names from the email.
-- Show the teacher name submitted with the club application instead.

create or replace function public.resolve_teacher_display_name(
  p_name text,
  p_email text
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    case
      when nullif(btrim(p_name), '') is not null
        and btrim(p_name) !~* '^p[0-9]+$'
        and position('@' in btrim(p_name)) = 0
      then btrim(p_name)
    end,
    (
      select chosen.name
      from (
        select btrim(request.faculty_advisor_name) as name
        from public.club_registration_requests as request
        where lower(btrim(request.faculty_advisor_email)) = lower(btrim(p_email))
          and nullif(btrim(request.faculty_advisor_name), '') is not null
          and btrim(request.faculty_advisor_name) !~* '^p[0-9]+$'
          and position('@' in request.faculty_advisor_name) = 0
        group by btrim(request.faculty_advisor_name)
        order by
          count(*) desc,
          length(btrim(request.faculty_advisor_name)) desc,
          btrim(request.faculty_advisor_name)
        limit 1
      ) as chosen
    ),
    (
      select chosen.name
      from (
        select btrim(person.supervisor_name) as name
        from public.club_reapplication_supervisors as person
        where lower(btrim(person.supervisor_email)) = lower(btrim(p_email))
          and nullif(btrim(person.supervisor_name), '') is not null
          and btrim(person.supervisor_name) !~* '^p[0-9]+$'
          and position('@' in person.supervisor_name) = 0
        group by btrim(person.supervisor_name)
        order by
          count(*) desc,
          length(btrim(person.supervisor_name)) desc,
          btrim(person.supervisor_name)
        limit 1
      ) as chosen
    ),
    (
      select chosen.name
      from (
        select btrim(person.supervisor_name) as name
        from public.club_supervisor_request_supervisors as person
        where lower(btrim(person.supervisor_email)) = lower(btrim(p_email))
          and nullif(btrim(person.supervisor_name), '') is not null
          and btrim(person.supervisor_name) !~* '^p[0-9]+$'
          and position('@' in person.supervisor_name) = 0
        group by btrim(person.supervisor_name)
        order by
          count(*) desc,
          length(btrim(person.supervisor_name)) desc,
          btrim(person.supervisor_name)
        limit 1
      ) as chosen
    ),
    (
      select named.cleaned
      from (
        select regexp_replace(
          btrim(profile.full_name),
          '\s+-\s+John Fraser SS\s*\(.*$',
          '',
          'i'
        ) as cleaned
        from public.profiles as profile
        where profile.email = lower(btrim(p_email))
        limit 1
      ) as named
      where nullif(named.cleaned, '') is not null
        and named.cleaned !~* '^p[0-9]+$'
        and position('@' in named.cleaned) = 0
    ),
    nullif(btrim(p_name), '')
  );
$$;

revoke all on function public.resolve_teacher_display_name(text, text)
from public, anon, authenticated;

create or replace function public.club_advisors_use_teacher_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.supervisor_name := public.resolve_teacher_display_name(
    new.supervisor_name,
    new.supervisor_email
  );
  return new;
end;
$$;

revoke all on function public.club_advisors_use_teacher_name()
from public, anon, authenticated;

drop trigger if exists club_advisors_use_teacher_name
on public.club_advisors;

create trigger club_advisors_use_teacher_name
before insert or update of supervisor_name, supervisor_email
on public.club_advisors
for each row
execute function public.club_advisors_use_teacher_name();

update public.club_advisors
set supervisor_name = public.resolve_teacher_display_name(
  supervisor_name,
  supervisor_email
)
where supervisor_name ~* '^p[0-9]+$';

create or replace function public.get_public_club_supervisors(
  p_club_id uuid
)
returns table (
  id uuid,
  supervisor_name text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    advisor.id,
    public.resolve_teacher_display_name(
      advisor.supervisor_name,
      advisor.supervisor_email
    ) as supervisor_name
  from public.club_advisors as advisor
  join public.clubs as club
    on club.id = advisor.club_id
  where advisor.club_id = p_club_id
    and advisor.status = 'ACTIVE'
    and advisor.school_year = public.get_current_club_school_year()
    and club.deleted_at is null
    and club.status = 'APPROVED'
    and public.club_is_publicly_active(club.id)
  order by 2;
$$;

revoke all on function public.get_public_club_supervisors(uuid)
from public;

grant execute on function public.get_public_club_supervisors(uuid)
to anon, authenticated;

notify pgrst, 'reload schema';
