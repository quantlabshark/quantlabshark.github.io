-- Deleted comments remain in the administrator's monthly journal, never in
-- the content synchronization feed or in a public endpoint.
alter table public.foamlab_content_operations drop constraint foamlab_content_operations_entity_check;
alter table public.foamlab_content_operations add constraint foamlab_content_operations_entity_check
 check(entity in ('content','section','comment','guestbook'));
create or replace function foamlab_private.keep_content_sync_state() returns trigger
 language plpgsql security definer set search_path='' as $$
begin
 if new.entity not in ('content','section') then return null;end if;
 insert into foamlab_private.content_sync_state(entity,record_id,event_id,deleted,snapshot)
 values(new.entity,new.record_id,new.id,new.operation='delete',new.snapshot)
 on conflict(entity,record_id) do update set event_id=excluded.event_id,deleted=excluded.deleted,snapshot=excluded.snapshot
 where content_sync_state.event_id<excluded.event_id;
 return null;
end $$;

create table public.foamlab_guestbook (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 body text not null check(char_length(btrim(body)) between 2 and 3000),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp()
);
create index guestbook_created on public.foamlab_guestbook(created_at desc,id desc);
create index guestbook_author on public.foamlab_guestbook(author_id);
alter table public.foamlab_guestbook enable row level security;
revoke all on public.foamlab_guestbook from public,anon,authenticated;
grant select on public.foamlab_guestbook to anon,authenticated;
grant insert,update,delete on public.foamlab_guestbook to authenticated;
create policy guestbook_read on public.foamlab_guestbook for select to anon,authenticated using(true);
create policy guestbook_post on public.foamlab_guestbook for insert to authenticated
 with check(author_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']));
create policy guestbook_edit on public.foamlab_guestbook for update to authenticated
 using(author_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']))
 with check(author_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']));
create policy guestbook_delete on public.foamlab_guestbook for delete to authenticated using(
 foamlab_private.has_role(array['admin','editor','moderator'])
 or (author_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked'])));
create function foamlab_private.guard_guestbook() returns trigger
 language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then
  new.created_at:=clock_timestamp();
 else
  if new.author_id is distinct from old.author_id or new.id<>old.id then
   raise exception using errcode='42501',message='不能更改留言作者或标识。';
  end if;
  new.created_at:=old.created_at;
 end if;
 new.updated_at:=clock_timestamp();new.body:=btrim(new.body);return new;
end $$;
create trigger guard_guestbook before insert or update on public.foamlab_guestbook
 for each row execute function foamlab_private.guard_guestbook();
create trigger require_github_guestbook before insert or update on public.foamlab_guestbook
 for each row execute function foamlab_private.require_github_participant();

create function foamlab_private.record_deleted_comment() returns trigger
 language plpgsql security definer set search_path='' as $$
declare item jsonb:=to_jsonb(old);who uuid:=auth.uid();actor_name text;actor_role text;
 author_name text;parent_title text;parent_url text;parent_slug text;kind text;
begin
 kind:=case when tg_table_name='foamlab_guestbook' then 'guestbook' else 'comment' end;
 select coalesce((select role from public.foamlab_roles where user_id=who),case when who is null then 'system' else 'member' end) into actor_role;
 select coalesce((select nullif(display_name,'') from public.foamlab_public_profiles where user_id=who),case when who is null then '系统维护' else '网站成员' end) into actor_name;
 select coalesce((select nullif(display_name,'') from public.foamlab_public_profiles where user_id=(item->>'author_id')::uuid),'网站成员') into author_name;
 if kind='guestbook' then parent_title:='留言板';parent_url:='/#guestbook';parent_slug:='guestbook';
 elsif item->>'content_id' is not null then
  select title,slug,'/read/?slug='||slug into parent_title,parent_slug,parent_url from public.foamlab_content where id=(item->>'content_id')::uuid;
 else
  select title,id::text,'/community/?topic='||id::text into parent_title,parent_slug,parent_url from public.foamlab_threads where id=(item->>'thread_id')::uuid;
 end if;
 insert into public.foamlab_content_operations(entity,record_id,operation,actor_id,actor_name,actor_role,title,slug,previous_status,current_status,changed_fields,snapshot)
 values(kind,(item->>'id')::uuid,'delete',who,actor_name,actor_role,coalesce(parent_title,'已删除页面中的评论'),coalesce(parent_slug,item->>'content_id',item->>'thread_id','guestbook'),coalesce(item->>'status','visible'),'deleted',array['body'],
  item||jsonb_build_object('author_name',author_name,'parent_title',parent_title,'parent_url',parent_url));
 return old;
end $$;
revoke all on function foamlab_private.record_deleted_comment() from public,anon,authenticated;
create trigger aa_message_delete_operation_lock before delete on public.foamlab_messages
 for each statement execute function foamlab_private.lock_content_operations();
create trigger aa_guestbook_delete_operation_lock before delete on public.foamlab_guestbook
 for each statement execute function foamlab_private.lock_content_operations();
create trigger a_record_deleted_comment before delete on public.foamlab_messages
 for each row execute function foamlab_private.record_deleted_comment();
create trigger a_record_deleted_guestbook before delete on public.foamlab_guestbook
 for each row execute function foamlab_private.record_deleted_comment();

-- The public update list is bounded to 100 rows. A UUID-only ledger prevents
-- editing/re-publishing an old page from adding it again after it was evicted.
create table foamlab_private.announced_pages (
 entity text not null check(entity in ('content','section')),record_id uuid not null,
 primary key(entity,record_id)
);
create table foamlab_private.recent_page_updates (
 entity text not null,record_id uuid not null,added_at timestamptz not null,
 primary key(entity,record_id),
 foreign key(entity,record_id) references foamlab_private.announced_pages(entity,record_id) on delete cascade
);
create index recent_page_updates_date on foamlab_private.recent_page_updates(added_at desc,entity,record_id);
alter table foamlab_private.announced_pages enable row level security;
alter table foamlab_private.recent_page_updates enable row level security;
revoke all on foamlab_private.announced_pages,foamlab_private.recent_page_updates from public,anon,authenticated;
insert into foamlab_private.announced_pages
 select 'content',id from public.foamlab_content where status<>'draft'
 union select 'content',content_id from public.foamlab_revisions where snapshot->>'status'='published'
 union select 'section',id from public.foamlab_sections where visible;
insert into foamlab_private.recent_page_updates(entity,record_id,added_at)
 select o.entity,o.record_id,min(o.created_at) from public.foamlab_content_operations o
 join foamlab_private.announced_pages a using(entity,record_id)
 where o.actor_role in ('admin','system') and (
  (o.entity='content' and o.operation in ('create','publish') and o.snapshot->>'status'='published'
   and coalesce(o.snapshot->'metadata'->>'admin_only','false')<>'true'
   and exists(select 1 from public.foamlab_content c where c.id=o.record_id and c.status='published'
    and foamlab_private.required_access_level(c.read_access,c.section_ids,c.metadata,foamlab_private.section_read_levels())<3))
  or (o.entity='section' and o.operation='create' and (o.snapshot->>'visible')::boolean
    and exists(select 1 from public.foamlab_sections s where s.id=o.record_id and s.visible
      and coalesce((foamlab_private.section_read_levels()->>s.id::text)::int,1)<3))
 ) group by o.entity,o.record_id order by min(o.created_at) desc,o.entity,o.record_id limit 100;

create function foamlab_private.record_recent_page() returns trigger
 language plpgsql security definer set search_path='' as $$
declare kind text:=case when tg_table_name='foamlab_content' then 'content' else 'section' end;
 item jsonb;is_visible boolean;fresh boolean;
begin
 item:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 if tg_op='DELETE' then delete from foamlab_private.announced_pages where entity=kind and record_id=(item->>'id')::uuid;return null;end if;
 is_visible:=case when kind='content' then item->>'status'='published' else (item->>'visible')::boolean end;
 if not is_visible then delete from foamlab_private.recent_page_updates where entity=kind and record_id=(item->>'id')::uuid;return null;end if;
 insert into foamlab_private.announced_pages values(kind,(item->>'id')::uuid) on conflict do nothing;
 fresh:=found;
 if not fresh or (auth.uid() is not null and not foamlab_private.has_role(array['admin'])) then return null;end if;
 if kind='content' then
  if coalesce(item->'metadata'->>'admin_only','false')='true'
   or foamlab_private.required_access_level(new.read_access,new.section_ids,new.metadata,foamlab_private.section_read_levels())>=3 then return null;end if;
 else
  if coalesce((foamlab_private.section_read_levels()->>new.id::text)::int,1)>=3 then return null;end if;
 end if;
 insert into foamlab_private.recent_page_updates values(kind,(item->>'id')::uuid,clock_timestamp());
 delete from foamlab_private.recent_page_updates where (entity,record_id) in (
  select entity,record_id from foamlab_private.recent_page_updates order by added_at desc,entity,record_id offset 100
 );return null;
end $$;
revoke all on function foamlab_private.record_recent_page() from public,anon,authenticated;
create trigger z_recent_content after insert or update or delete on public.foamlab_content
 for each row execute function foamlab_private.record_recent_page();
create trigger z_recent_section after insert or update or delete on public.foamlab_sections
 for each row execute function foamlab_private.record_recent_page();

create function foamlab_private.recent_updates() returns jsonb
 language sql stable security definer set search_path='' as $$
 with items as (
  select u.entity,u.record_id,c.title,'/read/?slug='||c.slug as url,u.added_at
  from foamlab_private.recent_page_updates u join public.foamlab_content c on u.entity='content' and c.id=u.record_id
  where c.status='published' and coalesce(c.metadata->>'admin_only','false')<>'true'
   and foamlab_private.required_access_level(c.read_access,c.section_ids,c.metadata,foamlab_private.section_read_levels())<3
  union all
  select u.entity,u.record_id,s.name,
   case when left(s.href,1)='/' and left(s.href,2)<>'//' then s.href else '/section/?id='||s.id::text end,u.added_at
  from foamlab_private.recent_page_updates u join public.foamlab_sections s on u.entity='section' and s.id=u.record_id
  where s.visible and coalesce((foamlab_private.section_read_levels()->>s.id::text)::int,1)<3
   and not exists(with recursive ancestors as (
    select parent_id from public.foamlab_sections where id=s.id
    union select p.parent_id from public.foamlab_sections p join ancestors a on p.id=a.parent_id
   ) select 1 from ancestors a join public.foamlab_sections p on p.id=a.parent_id where not p.visible)
 ) select coalesce(jsonb_agg(jsonb_build_object('entity',entity,'id',record_id,'title',title,'url',url,
  'date',to_char(added_at at time zone 'Asia/Shanghai','YYYY-MM-DD')) order by added_at desc,entity,record_id),'[]'::jsonb) from items;
$$;
revoke all on function foamlab_private.recent_updates() from public,anon,authenticated;
grant execute on function foamlab_private.recent_updates() to anon,authenticated;
create function public.foamlab_recent_updates() returns jsonb
 language sql stable security invoker set search_path='' as $$select foamlab_private.recent_updates();$$;
revoke all on function public.foamlab_recent_updates() from public;
grant execute on function public.foamlab_recent_updates() to anon,authenticated;
notify pgrst,'reload schema';
