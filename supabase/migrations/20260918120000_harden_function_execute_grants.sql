-- Harden function search_path and close PostgREST access to trigger functions.
-- Does not change tables, rows, club records, or application RPC behavior.

-- ---------------------------------------------------------
-- Pin search_path on helpers that currently inherit the caller path
-- ---------------------------------------------------------

alter function public.like_contains_pattern(text)
  set search_path = '';

alter function public.is_safe_https_url(text)
  set search_path = '';

alter function public.assert_safe_https_url_change(text, text, text)
  set search_path = '';

-- ---------------------------------------------------------
-- Trigger / event-trigger functions are not public APIs.
-- Default PUBLIC execute lets anon and authenticated call them
-- via /rest/v1/rpc. Revoke that. Triggers still fire as the
-- table owner.
-- ---------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as fn
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prorettype in ('trigger'::regtype, 'event_trigger'::regtype)
  loop
    execute format(
      'revoke all on function %s from public, anon, authenticated',
      r.fn
    );
  end loop;
end $$;

-- New functions created by this role should not default to PUBLIC execute.
alter default privileges in schema public
  revoke execute on functions from public;

do $$
begin
  execute 'alter default privileges for role postgres in schema public revoke execute on functions from public';
exception
  when insufficient_privilege then
    null;
end $$;
