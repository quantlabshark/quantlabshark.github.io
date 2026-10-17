begin;

-- Synchronization keeps one current state per object, independently of the
-- administrator-facing audit history. Tombstones prevent deleted pages from
-- reappearing when an older local checkout is published.
select pg_catalog.pg_advisory_xact_lock(7402512);
create table foamlab_private.content_sync_state (
 entity text not null check(entity in ('content','section')),
 record_id uuid not null,
 event_id bigint not null unique,
 deleted boolean not null,
 snapshot jsonb not null,
 primary key(entity,record_id)
);
alter table foamlab_private.content_sync_state enable row level security;
revoke all on foamlab_private.content_sync_state from public,anon,authenticated;
insert into foamlab_private.content_sync_state(entity,record_id,event_id,deleted,snapshot)
 select distinct on (entity,record_id) entity,record_id,id,operation='delete',snapshot
 from public.foamlab_content_operations order by entity,record_id,id desc;

create function foamlab_private.keep_content_sync_state() returns trigger
 language plpgsql security definer set search_path='' as $function$
begin
 insert into foamlab_private.content_sync_state(entity,record_id,event_id,deleted,snapshot)
 values(new.entity,new.record_id,new.id,new.operation='delete',new.snapshot)
 on conflict(entity,record_id) do update
 set event_id=excluded.event_id,deleted=excluded.deleted,snapshot=excluded.snapshot
 where content_sync_state.event_id<excluded.event_id;
 return null;
end $function$;
revoke all on function foamlab_private.keep_content_sync_state() from public,anon,authenticated;
create trigger keep_content_sync_state after insert on public.foamlab_content_operations
 for each row execute function foamlab_private.keep_content_sync_state();

create or replace function foamlab_private.read_content_operations(client_id uuid,client_key text,after_id bigint,through_id bigint,batch_size integer)
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
 select coalesce(max(event_id),0) into watermark from foamlab_private.content_sync_state;
 -- A compact state can be replaced between pages. Restart the complete read
 -- instead of advancing past an object whose older state is no longer present.
 if through_id is not null and through_id<>watermark then
  raise exception using errcode='40001',message='读取期间网站内容已更新，请重新读取同步状态。';
 end if;
 with page as (
  select * from foamlab_private.content_sync_state
  where event_id>after_id and event_id<=watermark order by event_id limit batch_size
 )
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',p.event_id,'entity',p.entity,'record_id',p.record_id,
  'operation',case when p.deleted then 'delete' else 'snapshot' end,'snapshot',p.snapshot,
  'history',case when p.entity='content' then (
   select coalesce(jsonb_agg((v.snapshot-'body')||jsonb_build_object('body_md5',md5(replace(coalesce(v.snapshot->>'body',''),E'\r\n',E'\n')))),'[]'::jsonb)
   from (select snapshot from public.foamlab_revisions where content_id=p.record_id order by revision desc limit 50) v
  ) else '[]'::jsonb end) order by p.event_id),'[]'::jsonb),coalesce(max(p.event_id),after_id)
 into events,next_id from page p;
 return jsonb_build_object('version',1,'through',watermark,'next',next_id,
  'has_more',exists(select 1 from foamlab_private.content_sync_state where event_id>next_id and event_id<=watermark),'events',events);
end $function$;

create index content_operations_created_at on public.foamlab_content_operations(created_at);
alter policy content_operations_admin_read on public.foamlab_content_operations
 using ((select foamlab_private.has_role(array['admin'])) and created_at>=(select now()-interval '1 month'));

create extension if not exists pg_cron;
create function foamlab_private.prune_content_operations() returns bigint
 language plpgsql security definer set search_path='' as $function$
declare removed bigint;
begin
 delete from public.foamlab_content_operations where created_at<now()-interval '1 month';
 get diagnostics removed=row_count;
 delete from cron.job_run_details
 where jobid=(select jobid from cron.job where jobname='foamlab-maintenance-monthly-retention')
 and end_time<now()-interval '1 month';
 return removed;
end $function$;
revoke all on function foamlab_private.prune_content_operations() from public,anon,authenticated;
select cron.schedule('foamlab-maintenance-monthly-retention','5 * * * *',
 'select foamlab_private.prune_content_operations();');
select foamlab_private.prune_content_operations();

notify pgrst,'reload schema';
commit;
