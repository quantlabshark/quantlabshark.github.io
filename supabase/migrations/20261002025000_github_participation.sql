-- Participation requires an identity verified by Supabase Auth, not user-editable metadata.
create function foamlab_private.has_github_identity() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.identities where user_id=(select auth.uid()) and provider='github')
$$;
revoke all on function foamlab_private.has_github_identity() from public;
grant execute on function foamlab_private.has_github_identity() to authenticated;

create function foamlab_private.require_github_participant() returns trigger
language plpgsql set search_path='' as $$
begin
 if current_user='authenticated' and not foamlab_private.has_github_identity() then
  raise exception using errcode='42501',message='A verified GitHub account is required';
 end if;
 return new;
end $$;
revoke all on function foamlab_private.require_github_participant() from public;
create trigger require_github_before_thread before insert or update on public.foamlab_threads
 for each row execute function foamlab_private.require_github_participant();
create trigger require_github_before_message before insert or update on public.foamlab_messages
 for each row execute function foamlab_private.require_github_participant();
create trigger require_github_before_content before insert or update on public.foamlab_content
 for each row execute function foamlab_private.require_github_participant();
