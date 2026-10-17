begin;
alter table public.foamlab_roles drop constraint foamlab_roles_role_check;
alter table public.foamlab_roles add constraint foamlab_roles_role_check
 check(role in ('admin','editor','moderator','supporter','blocked'));
alter table public.foamlab_content add column read_access text not null default 'inherit'
 check(read_access in ('inherit','public','member','supporter','admin'));
alter table public.foamlab_sections add column read_access text not null default 'inherit'
 check(read_access in ('inherit','public','member','supporter','admin'));
grant select(read_access) on public.foamlab_content to anon;

create function foamlab_private.effective_read_access(mode text,placements uuid[],attributes jsonb)
 returns text language plpgsql stable security definer set search_path='' as $function$
declare required integer;
begin
 if coalesce(attributes->>'admin_only','false')='true' then return 'admin';end if;
 if mode in ('public','member','supporter','admin') then return mode;end if;
 with recursive ancestors as (
  select root.id as placement,s.id,s.parent_id,s.read_access,0 as depth,array[s.id] as seen
  from unnest(placements) root(id) join public.foamlab_sections s on s.id=root.id
  union all
  select a.placement,s.id,s.parent_id,s.read_access,a.depth+1,a.seen||s.id
  from ancestors a join public.foamlab_sections s on s.id=a.parent_id where not s.id=any(a.seen)
 ), closest as (
  select distinct on(placement) placement,read_access
  from ancestors where read_access<>'inherit' order by placement,depth
 )
 select max(case coalesce(c.read_access,'member') when 'public' then 0 when 'member' then 1 when 'supporter' then 2 else 3 end)
 into required from unnest(placements) p(id) left join closest c on c.placement=p.id;
 return (array['public','member','supporter','admin'])[coalesce(required,1)+1];
end $function$;
revoke all on function foamlab_private.effective_read_access(text,uuid[],jsonb) from public;
grant execute on function foamlab_private.effective_read_access(text,uuid[],jsonb) to anon,authenticated;

create function foamlab_private.can_read_access(mode text) returns boolean
 language sql stable security invoker set search_path='' as $function$
 select case when mode='public' then true
 when auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' then false
 when foamlab_private.has_role(array['admin']) then true
 when mode='member' then true
 when mode='supporter' then foamlab_private.has_role(array['supporter'])
 else false end;
$function$;
revoke all on function foamlab_private.can_read_access(text) from public;
grant execute on function foamlab_private.can_read_access(text) to anon,authenticated;

create policy content_read_access on public.foamlab_content as restrictive for select to authenticated
 using ((select foamlab_private.has_role(array['admin']) and coalesce(auth.jwt()->>'is_anonymous','false')<>'true')
 or foamlab_private.can_read_access(foamlab_private.effective_read_access(read_access,section_ids,metadata)));
create policy message_read_access on public.foamlab_messages as restrictive for select to anon,authenticated
 using (content_id is null or exists(select 1 from public.foamlab_content c where c.id=content_id
 and foamlab_private.can_read_access(foamlab_private.effective_read_access(c.read_access,c.section_ids,c.metadata))));

create function foamlab_private.guard_read_access() returns trigger
 language plpgsql security definer set search_path='' as $function$
begin
 if auth.uid() is not null and not foamlab_private.has_role(array['admin']) then
  if (tg_op='INSERT' and new.read_access<>'inherit')
  or (tg_op='UPDATE' and new.read_access is distinct from old.read_access) then
   raise exception using errcode='42501',message='只有管理员可以修改阅读权限。';
  end if;
 end if;
 return new;
end $function$;
revoke all on function foamlab_private.guard_read_access() from public,anon,authenticated;
create trigger guard_read_access before insert or update on public.foamlab_content
 for each row execute function foamlab_private.guard_read_access();

create function foamlab_private.read_article(p_slug text) returns jsonb
 language plpgsql stable security definer set search_path='' as $function$
declare article public.foamlab_content; mode text;
begin
 if p_slug is null or length(p_slug)>180 then raise exception using errcode='22023',message='文章地址无效。';end if;
 select * into article from public.foamlab_content where slug=p_slug and status='published';
 if not found then return jsonb_build_object('allowed',true,'item',null);end if;
 mode:=foamlab_private.effective_read_access(article.read_access,article.section_ids,article.metadata);
 if not foamlab_private.can_read_access(mode) then
  return jsonb_build_object('allowed',false,'access',mode,'slug',article.slug,'title',article.title);
 end if;
 return jsonb_build_object('allowed',true,'access',mode,'item',to_jsonb(article));
end $function$;
revoke all on function foamlab_private.read_article(text) from public;
grant execute on function foamlab_private.read_article(text) to anon,authenticated;
create function public.foamlab_read_article(p_slug text) returns jsonb
 language sql stable security invoker set search_path='' as $function$
 select foamlab_private.read_article(p_slug);
$function$;
revoke all on function public.foamlab_read_article(text) from public;
grant execute on function public.foamlab_read_article(text) to anon,authenticated;

-- The notification feed is used by a private definer API. Apply the same
-- reader check before it returns excerpts of comments on restricted articles.
create or replace view foamlab_private.reply_notification_feed as
 select n.id,n.recipient_id,n.message_id,n.kind,n.created_at,n.read_at,m.author_id,
 coalesce(nullif(p.display_name,''),'社区成员') as author_name,left(m.body,240) as excerpt,
 c.slug,coalesce(c.title,t.title) as title,m.thread_id,m.reply_to_id
 from foamlab_private.reply_notifications n join public.foamlab_messages m on m.id=n.message_id
 left join public.foamlab_content c on c.id=m.content_id
 left join public.foamlab_threads t on t.id=m.thread_id
 left join public.foamlab_public_profiles p on p.user_id=m.author_id
 where m.status='visible' and
 ((c.status='published' and c.comments_enabled and coalesce(c.metadata->>'admin_only','false')<>'true'
 and foamlab_private.can_read_access(foamlab_private.effective_read_access(c.read_access,c.section_ids,c.metadata)))
 or t.status in ('open','resolved','closed'));

CREATE OR REPLACE FUNCTION foamlab_private.admin_set_member_role(p_user_id uuid, p_role text, p_expected_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare old_role text; actor uuid=auth.uid();
begin
 if actor is null or not foamlab_private.has_role(array['admin']) then
  raise exception '只有管理员可以修改成员权限。' using errcode='42501';
 end if;
 -- Serialize admin changes; re-check the caller after taking the lock.
 perform pg_catalog.pg_advisory_xact_lock(793241,1);
 if not foamlab_private.has_role(array['admin']) then
  raise exception '管理员权限已变化，请刷新页面。' using errcode='42501';
 end if;
 if p_user_id is null or p_role is null or p_role not in ('member','supporter','admin','editor','moderator','blocked')
    or p_expected_role is null or p_expected_role not in ('member','supporter','admin','editor','moderator','blocked') then
  raise exception '请选择有效的成员与权限。' using errcode='22023';
 end if;
 -- Accept the former moderator label as an alias for the common author role.
 if p_role='moderator' then p_role:='editor';end if;
 if p_expected_role='moderator' then p_expected_role:='editor';end if;
 if not exists(select 1 from auth.users where id=p_user_id and deleted_at is null and not coalesce(is_anonymous,false)) then
  raise exception '该注册用户不存在。' using errcode='22023';
 end if;
 select coalesce((select role from public.foamlab_roles where user_id=p_user_id),'member') into old_role;
 if old_role='moderator' then old_role:='editor';end if;
 if old_role is distinct from p_expected_role then
  raise exception '该用户权限已被修改，请刷新成员列表后重试。' using errcode='40001';
 end if;
 if actor=p_user_id and p_role<>'admin' then
  raise exception '请由另一位管理员调整你的权限。' using errcode='42501';
 end if;
 if old_role=p_role then return jsonb_build_object('user_id',p_user_id,'role',p_role,'changed',false);end if;
 if old_role='admin' and p_role<>'admin' and (select count(*) from public.foamlab_roles where role='admin')<=1 then
  raise exception '至少保留一位管理员。' using errcode='42501';
 end if;
 if p_role='member' then delete from public.foamlab_roles where user_id=p_user_id;
 else insert into public.foamlab_roles(user_id,role) values(p_user_id,p_role)
  on conflict(user_id) do update set role=excluded.role;
 end if;
 insert into foamlab_private.member_role_history(actor_id,user_id,previous_role,new_role) values(actor,p_user_id,old_role,p_role);
 return jsonb_build_object('user_id',p_user_id,'role',p_role,'changed',true);
end $function$;

CREATE OR REPLACE FUNCTION foamlab_private.admin_members(p_query text, p_role text, p_sort text, p_direction text, p_page integer, p_size integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 if auth.uid() is null or not foamlab_private.has_role(array['admin']) then
  raise exception '只有管理员可以查看注册成员。' using errcode='42501';
 end if;
 if p_query is null or length(p_query)>200 or p_role is null
    or p_role not in ('','member','supporter','admin','editor','moderator','blocked')
    or p_sort is null or p_sort not in ('registered_at','last_sign_in_at','username','level')
    or p_direction is null or p_direction not in ('asc','desc')
    or p_page is null or p_page<1 or p_size is null or p_size not in (25,50,100) then
  raise exception '成员查询参数无效。' using errcode='22023';
 end if;
 if p_role='moderator' then p_role:='editor';end if;
 with members as (
  select u.id as user_id,
   coalesce(nullif(p.display_name,''),nullif(pp.display_name,''),nullif(u.raw_user_meta_data->>'full_name',''),nullif(u.raw_user_meta_data->>'user_name',''),nullif(u.raw_user_meta_data->>'name',''),'未设置昵称') as display_name,
   coalesce(nullif(g.identity_data->>'user_name',''),nullif(g.identity_data->>'preferred_username',''),nullif(u.raw_user_meta_data->>'user_name',''),nullif(u.raw_user_meta_data->>'preferred_username',''),'') as username,
   coalesce(u.email,'') as email,
   u.created_at as registered_at,greatest(u.last_sign_in_at,activity.last_seen_at) as last_sign_in_at,
   case when r.role='moderator' then 'editor' else coalesce(r.role,'member') end as role,
   foamlab_private.pet_level(coalesce(pet.xp,0)) as level,coalesce(pet.xp,0) as xp,
   coalesce(p.institution,'') as institution,coalesce(p.research,'') as research,
   coalesce(p.level,'') as learning_stage,coalesce(p.bio,'') as bio
  from auth.users u
  left join foamlab_private.member_activity activity on activity.user_id=u.id
  left join public.foamlab_profiles p on p.user_id=u.id
  left join public.foamlab_public_profiles pp on pp.user_id=u.id
  left join public.foamlab_roles r on r.user_id=u.id
  left join public.foamlab_pets pet on pet.user_id=u.id
  left join lateral (select i.identity_data from auth.identities i where i.user_id=u.id and i.provider='github' order by i.created_at,i.id limit 1) g on true
  where u.deleted_at is null and not coalesce(u.is_anonymous,false)
 ), filtered as (
  select * from members where (p_role='' or role=p_role)
   and (btrim(p_query)='' or strpos(lower(concat_ws(' ',display_name,username,email,user_id::text,institution,research)),lower(btrim(p_query)))>0)
 ), numbered as (
  select *,row_number() over(order by
   case when p_sort='registered_at' and p_direction='asc' then registered_at end asc nulls last,
   case when p_sort='registered_at' and p_direction='desc' then registered_at end desc nulls last,
   case when p_sort='last_sign_in_at' and p_direction='asc' then last_sign_in_at end asc nulls last,
   case when p_sort='last_sign_in_at' and p_direction='desc' then last_sign_in_at end desc nulls last,
   case when p_sort='username' and p_direction='asc' then lower(coalesce(nullif(username,''),display_name)) end asc,
   case when p_sort='username' and p_direction='desc' then lower(coalesce(nullif(username,''),display_name)) end desc,
   case when p_sort='level' and p_direction='asc' then level end asc,
   case when p_sort='level' and p_direction='desc' then level end desc,user_id asc
  ) as rn from filtered
 ), totals as (
  select count(*) as total,least(p_page,greatest(1,ceil(count(*)::numeric/p_size)::integer)) as page from filtered
 )
 select jsonb_build_object('total',t.total,'page',t.page,'page_size',p_size,
  'items',coalesce((select jsonb_agg(to_jsonb(n)-'rn' order by n.rn) from numbered n where n.rn>(t.page-1)*p_size and n.rn<=t.page*p_size),'[]'::jsonb))
 into result from totals t;
 return result;
end $function$;

notify pgrst,'reload schema';
commit;
