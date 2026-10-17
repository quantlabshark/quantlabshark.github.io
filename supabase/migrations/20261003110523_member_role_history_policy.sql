-- History is written by the guarded definer and remains private to the backend.
create policy member_history_backend_only on foamlab_private.member_role_history
for all to anon,authenticated using (false) with check (false);
