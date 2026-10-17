create or replace function foamlab_private.guard_community() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' then new.created_at=old.created_at; end if;
 if not foamlab_private.has_role(array['admin','moderator']) then
  if tg_op='INSERT' and tg_table_name='foamlab_threads' then
   if exists(select 1 from public.foamlab_settings where key='site' and value->>'discussion_open'='false') then raise exception 'New discussions are temporarily closed'; end if;
   if (select count(*) from public.foamlab_threads where author_id=auth.uid() and created_at>now()-interval '1 hour')>=5 then raise exception 'Please wait before creating more topics'; end if;
  end if;
  if tg_op='INSERT' and tg_table_name='foamlab_messages' and (select count(*) from public.foamlab_messages where author_id=auth.uid() and created_at>now()-interval '1 hour')>=40 then raise exception 'Please wait before posting again'; end if;
  if tg_op='UPDATE' then
   if new.author_id<>old.author_id then raise exception 'Author cannot change'; end if;
   if tg_table_name='foamlab_threads' then
    if new.pinned<>old.pinned or new.status not in ('open','resolved') then raise exception 'Moderator action required'; end if;
   else
    if new.status<>old.status or new.thread_id is distinct from old.thread_id or new.content_id is distinct from old.content_id then raise exception 'Message destination cannot change'; end if;
   end if;
  end if;
 end if;
 if tg_op='INSERT' then new.created_at=now(); end if;
 new.updated_at=now(); return new;
end $$;
create function foamlab_private.protect_admin() returns trigger language plpgsql set search_path='' as $$
begin
 if old.role='admin' and (tg_op='DELETE' or new.role<>'admin') and (select count(*) from public.foamlab_roles where role='admin')<=1 then raise exception 'The last administrator cannot be removed'; end if;
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
create trigger protect_last_admin before update or delete on public.foamlab_roles for each row execute function foamlab_private.protect_admin();
revoke all on function foamlab_private.protect_admin() from public;
