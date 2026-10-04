-- Block new-club applications that reuse an existing club name or alias.

create or replace function public.club_name_is_taken(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    nullif(btrim(coalesce(p_name, '')), '') is not null
    and (
      exists (
        select 1
        from public.clubs as club
        where lower(btrim(club.name)) = lower(btrim(p_name))
      )
      or exists (
        select 1
        from public.club_aliases as club_alias
        where lower(btrim(club_alias.alias)) = lower(btrim(p_name))
      )
    );
$$;

comment on function public.club_name_is_taken(text) is
  'True when a club or alias already uses this name, ignoring case.';

revoke all on function public.club_name_is_taken(text) from public, anon;
grant execute on function public.club_name_is_taken(text) to authenticated;

create or replace function public.reject_duplicate_club_application_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.club_name_is_taken(new.proposed_name) then
    raise exception 'A club with that name already exists';
  end if;
  return new;
end;
$$;

drop trigger if exists reject_duplicate_club_application_name
on public.club_registration_requests;

create trigger reject_duplicate_club_application_name
before insert or update of proposed_name
on public.club_registration_requests
for each row
execute function public.reject_duplicate_club_application_name();
