begin;

create table public.foamlab_content_operations (
 id bigint generated always as identity primary key,
 entity text not null check(entity in ('content','section')),
 record_id uuid not null,
 operation text not null,
 actor_id uuid,
 actor_name text not null,
 actor_role text not null,
 title text not null,
 slug text not null,
 previous_status text,
 current_status text,
 changed_fields text[] not null default '{}',
 snapshot jsonb not null,
 created_at timestamptz not null default clock_timestamp()
);
create index content_operations_record on public.foamlab_content_operations(entity,record_id,id desc);
alter table public.foamlab_content_operations enable row level security;
revoke all on public.foamlab_content_operations from public,anon,authenticated;
grant select on public.foamlab_content_operations to authenticated;
create policy content_operations_admin_read on public.foamlab_content_operations for select to authenticated
 using ((select foamlab_private.has_role(array['admin'])));

-- Take the journal lock before any rows are locked. IDs then follow commit
-- order, so a reader can advance a watermark without skipping late commits.
create function foamlab_private.lock_content_operations() returns trigger
 language plpgsql set search_path='' as $function$
begin
 perform pg_catalog.pg_advisory_xact_lock(7402512);
 return null;
end
$function$;
create trigger aa_content_operation_lock before insert or update or delete on public.foamlab_content
 for each statement execute function foamlab_private.lock_content_operations();
create trigger aa_section_operation_lock before insert or update or delete on public.foamlab_sections
 for each statement execute function foamlab_private.lock_content_operations();

create function foamlab_private.record_content_operation() returns trigger
 language plpgsql security definer set search_path='' as $function$
declare item jsonb; previous jsonb; fields text[]; action text; who uuid:=auth.uid(); role_name text; display_name text;
begin
 item:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 previous:=case when tg_op='INSERT' then '{}'::jsonb else to_jsonb(old) end;
 select coalesce(array_agg(k order by k),'{}'::text[]) into fields
 from jsonb_object_keys(item) k where k not in ('updated_at','created_at','revision')
 and (tg_op<>'UPDATE' or item->k is distinct from previous->k);
 action:=case tg_op when 'INSERT' then 'create' when 'DELETE' then 'delete' else 'update' end;
 if tg_op='UPDATE' and tg_table_name='foamlab_content' then
  if item->>'status' is distinct from previous->>'status' then
   action:=case item->>'status' when 'published' then 'publish' when 'archived' then 'archive' when 'trash' then 'trash' else 'restore' end;
  elsif item->'section_ids' is distinct from previous->'section_ids' then action:='move';
  end if;
 end if;
 select coalesce((select role from public.foamlab_roles where user_id=who),case when who is null then 'system' else 'member' end) into role_name;
 select coalesce((select nullif(pp.display_name,'') from public.foamlab_public_profiles pp where pp.user_id=who),
 (select coalesce(nullif(u.raw_user_meta_data->>'user_name',''),nullif(u.raw_user_meta_data->>'full_name','')) from auth.users u where u.id=who),
 case when who is null then '系统维护' else '网站成员' end) into display_name;
 insert into public.foamlab_content_operations(entity,record_id,operation,actor_id,actor_name,actor_role,title,slug,previous_status,current_status,changed_fields,snapshot)
 values(case tg_table_name when 'foamlab_content' then 'content' else 'section' end,(item->>'id')::uuid,action,who,display_name,role_name,
 coalesce(item->>'title',item->>'name',''),coalesce(item->>'slug',item->>'key',''),previous->>'status',item->>'status',fields,item);
 return null;
end
$function$;
revoke all on function foamlab_private.record_content_operation() from public,anon,authenticated;
create trigger z_record_content_operation after insert or update or delete on public.foamlab_content
 for each row execute function foamlab_private.record_content_operation();
create trigger z_record_section_operation after insert or update or delete on public.foamlab_sections
 for each row execute function foamlab_private.record_content_operation();

-- The first pull reconciles existing online content before incremental reads.
select pg_catalog.pg_advisory_xact_lock(7402512);
insert into public.foamlab_content_operations(entity,record_id,operation,actor_name,actor_role,title,slug,current_status,snapshot)
 select 'section',id,'snapshot','同步基线','system',name,key,null,to_jsonb(s) from public.foamlab_sections s order by id;
insert into public.foamlab_content_operations(entity,record_id,operation,actor_name,actor_role,title,slug,current_status,snapshot)
 select 'content',id,'snapshot','同步基线','system',title,slug,status,to_jsonb(c) from public.foamlab_content c order by id;

-- A local publisher gets a read-only machine credential. It is bound to an
-- administrator, checked on every request, and cannot mutate website content.
create table foamlab_private.content_sync_clients (
 id uuid primary key,
 owner_id uuid not null references auth.users(id) on delete cascade,
 key_hash text not null unique check(key_hash ~ '^[0-9a-f]{64}$'),
 enabled boolean not null default true,
 created_at timestamptz not null default now()
);
alter table foamlab_private.content_sync_clients enable row level security;
revoke all on foamlab_private.content_sync_clients from public,anon,authenticated;
create policy content_sync_clients_closed on foamlab_private.content_sync_clients
 for all to anon,authenticated using(false) with check(false);

create function foamlab_private.read_content_operations(client_id uuid,client_key text,after_id bigint,through_id bigint,batch_size integer)
 returns jsonb language plpgsql stable security definer set search_path='' as $function$
declare watermark bigint; events jsonb; next_id bigint;
begin
 if client_key is null or length(client_key)<40 or not exists(
  select 1 from foamlab_private.content_sync_clients c
  join public.foamlab_roles r on r.user_id=c.owner_id and r.role='admin'
  join auth.users u on u.id=c.owner_id and u.deleted_at is null and not coalesce(u.is_anonymous,false)
  where c.id=client_id and c.enabled and c.key_hash=encode(sha256(convert_to(client_key,'UTF8')),'hex')
 ) then raise exception using errcode='42501',message='同步连接无效或其管理员权限已撤销。';end if;
 if after_id is null or after_id<0 or batch_size is null or batch_size not between 1 and 100
 or (through_id is not null and through_id<after_id) then
  raise exception using errcode='22023',message='同步范围无效。';
 end if;
 select coalesce(max(id),0) into watermark from public.foamlab_content_operations;
 if through_id is not null then watermark:=least(watermark,through_id);end if;
 with page as (select * from public.foamlab_content_operations where id>after_id and id<=watermark order by id limit batch_size)
 select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('history',case when p.entity='content' and p.operation='snapshot' then (
  select coalesce(jsonb_agg((v.snapshot-'body')||jsonb_build_object('body_md5',md5(replace(coalesce(v.snapshot->>'body',''),E'\r\n',E'\n')))),'[]'::jsonb)
  from (select snapshot from public.foamlab_revisions where content_id=p.record_id order by revision desc limit 50) v
 ) else '[]'::jsonb end) order by p.id),'[]'::jsonb),coalesce(max(p.id),after_id) into events,next_id from page p;
 return jsonb_build_object('version',1,'through',watermark,'next',next_id,'has_more',exists(select 1 from public.foamlab_content_operations where id>next_id and id<=watermark),'events',events);
end
$function$;
revoke all on function foamlab_private.read_content_operations(uuid,text,bigint,bigint,integer) from public,anon,authenticated;
grant execute on function foamlab_private.read_content_operations(uuid,text,bigint,bigint,integer) to anon,authenticated;
grant usage on schema foamlab_private to anon,authenticated;
create function public.foamlab_read_content_operations(p_client_id uuid,p_client_key text,p_after bigint default 0,p_through bigint default null,p_size integer default 100)
 returns jsonb language sql stable security invoker set search_path='' as $function$
 select foamlab_private.read_content_operations(p_client_id,p_client_key,p_after,p_through,p_size);
$function$;
revoke all on function public.foamlab_read_content_operations(uuid,text,bigint,bigint,integer) from public;
grant execute on function public.foamlab_read_content_operations(uuid,text,bigint,bigint,integer) to anon,authenticated;
create function foamlab_private.register_content_sync_client(client_id uuid,key_hash_value text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare who uuid:=auth.uid();
begin
 if who is null or not foamlab_private.has_role(array['admin']) then raise exception using errcode='42501',message='只有管理员可以登记同步连接。';end if;
 if client_id is null or key_hash_value is null or key_hash_value !~ '^[0-9a-f]{64}$' then raise exception using errcode='22023',message='同步连接格式不正确。';end if;
 if exists(select 1 from foamlab_private.content_sync_clients where id=client_id and owner_id<>who) then raise exception using errcode='42501',message='这条同步连接属于另一位管理员。';end if;
 insert into foamlab_private.content_sync_clients(id,owner_id,key_hash) values(client_id,who,key_hash_value)
 on conflict(id) do update set key_hash=excluded.key_hash,enabled=true;
 return jsonb_build_object('client_id',client_id,'enabled',true);
end $function$;
revoke all on function foamlab_private.register_content_sync_client(uuid,text) from public,anon,authenticated;
grant execute on function foamlab_private.register_content_sync_client(uuid,text) to authenticated;
create function public.foamlab_register_content_sync_client(p_client_id uuid,p_key_hash text)
returns jsonb language sql security invoker set search_path='' as $function$
 select foamlab_private.register_content_sync_client(p_client_id,p_key_hash);
$function$;
revoke all on function public.foamlab_register_content_sync_client(uuid,text) from public,anon,authenticated;
grant execute on function public.foamlab_register_content_sync_client(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;
