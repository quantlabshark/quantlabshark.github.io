begin;
-- The two historical author roles have identical permissions. Keep editor as
-- the stored author key, and accept moderator only as a legacy API alias.
update public.foamlab_roles set role='editor' where role='moderator';

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
    or p_role not in ('','member','admin','editor','moderator','blocked')
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
 if p_user_id is null or p_role is null or p_role not in ('member','admin','editor','moderator','blocked')
    or p_expected_role is null or p_expected_role not in ('member','admin','editor','moderator','blocked') then
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
end $function$
;
notify pgrst, 'reload schema';
commit;
