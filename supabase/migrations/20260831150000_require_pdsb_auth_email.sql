-- Only PDSB accounts may create an application profile.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is null
     or split_part(lower(btrim(new.email)), '@', 2) <> 'pdsb.net' then
    raise exception 'Only @pdsb.net accounts may access this application'
      using errcode = '42501';
  end if;

  insert into public.profiles (
    id,
    email,
    full_name,
    avatar_url
  )
  values (
    new.id,
    lower(new.email),
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    ),
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  );

  return new;
end;
$$;
