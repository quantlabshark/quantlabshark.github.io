-- Visits made with an existing authenticated session are separate from Auth's
-- last credential sign-in. Only administrators may read these timestamps.
create table foamlab_private.member_activity (
 user_id uuid primary key references auth.users(id) on delete cascade,
 last_seen_at timestamptz not null
);
alter table foamlab_private.member_activity enable row level security;
revoke all on foamlab_private.member_activity from public,anon,authenticated;

create function foamlab_private.record_member_visit()
returns timestamptz language plpgsql security definer set search_path='' as $$
declare who uuid=auth.uid(); stamp timestamptz=statement_timestamp(); recorded timestamptz;
begin
 if who is null or not exists(
  select 1 from auth.users where id=who and deleted_at is null and not coalesce(is_anonymous,false)
 ) then
  raise exception '请先登录。' using errcode='42501';
 end if;
 -- No client user ID or timestamp is accepted. Concurrent pages share one row;
 -- the server also limits updates when several visible windows are open.
 insert into foamlab_private.member_activity as activity(user_id,last_seen_at)
 values(who,stamp)
 on conflict(user_id) do update set last_seen_at=excluded.last_seen_at
 where activity.last_seen_at < stamp-interval '30 seconds';
 select last_seen_at into recorded from foamlab_private.member_activity where user_id=who;
 return recorded;
end $$;
revoke all on function foamlab_private.record_member_visit() from public,anon,authenticated;
grant execute on function foamlab_private.record_member_visit() to authenticated;

create function public.foamlab_record_member_visit()
returns timestamptz language sql security invoker set search_path='' as $$
 select foamlab_private.record_member_visit();
$$;
revoke all on function public.foamlab_record_member_visit() from public,anon,authenticated;
grant execute on function public.foamlab_record_member_visit() to authenticated;


create or replace function foamlab_private.admin_members(
 p_query text, p_role text, p_sort text, p_direction text, p_page integer, p_size integer
) returns jsonb language plpgsql stable security definer set search_path='' as $$
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
 with members as (
  select u.id as user_id,
   coalesce(nullif(p.display_name,''),nullif(pp.display_name,''),nullif(u.raw_user_meta_data->>'full_name',''),nullif(u.raw_user_meta_data->>'user_name',''),nullif(u.raw_user_meta_data->>'name',''),'未设置昵称') as display_name,
   coalesce(nullif(g.identity_data->>'user_name',''),nullif(g.identity_data->>'preferred_username',''),nullif(u.raw_user_meta_data->>'user_name',''),nullif(u.raw_user_meta_data->>'preferred_username',''),'') as username,
   coalesce(u.email,'') as email,
   u.created_at as registered_at,greatest(u.last_sign_in_at,activity.last_seen_at) as last_sign_in_at,
   coalesce(r.role,'member') as role,
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
end $$;
revoke all on function foamlab_private.admin_members(text,text,text,text,integer,integer) from public,anon,authenticated;
grant execute on function foamlab_private.admin_members(text,text,text,text,integer,integer) to authenticated;

