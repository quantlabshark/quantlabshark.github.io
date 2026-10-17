create or replace function foamlab_private.companion_api(operation text,payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); base jsonb; vlook jsonb; counts jsonb; i foamlab_private.companion_items; unlocked text[]; k text;
begin
 if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) then
  raise exception using errcode='42501',message='请先使用 GitHub 登录。';
 end if;
 if operation is null or operation not in ('state','checkin','settings','equip') then raise exception '未知操作。';end if;
 base:=foamlab_private.pet_api(case when operation='checkin' then 'checkin' else 'state' end,'{}');
 insert into foamlab_private.companion_profiles(user_id) values(who) on conflict do nothing;
 select c.look into vlook from foamlab_private.companion_profiles c where user_id=who for update;
 select jsonb_build_object(
 'lessons',(select count(*) from public.foamlab_learning_progress p join public.foamlab_content c on c.id=p.content_id where p.user_id=who and p.completed and c.kind='lesson' and c.status='published'),
 'checkins',(select count(*) from public.foamlab_pet_events where user_id=who and kind='checkin'),
 'questions',(select count(*) from public.foamlab_pet_events where user_id=who and kind='topic' and points>0),
 'replies',(select count(*) from public.foamlab_pet_events where user_id=who and kind='reply' and points>0),
 'articles',(select count(*) from public.foamlab_content where author_id=who and kind in ('article','log') and status='published')) into counts;
 insert into foamlab_private.companion_inventory(user_id,item_id)
 select who,c.id from foamlab_private.companion_items c
 where c.required_level<=(base->>'level')::integer
 and (c.requirement is null or coalesce((counts->>(c.requirement->>'type'))::integer,0)>=(c.requirement->>'count')::integer)
 on conflict do nothing;
 select array_agg(item_id) into unlocked from foamlab_private.companion_inventory where user_id=who;
 if operation='equip' then
  select * into i from foamlab_private.companion_items where id=payload->>'id';
  if not found or not i.id=any(unlocked) then raise exception '这个收藏尚未解锁。';end if;
  if i.category='badge' then raise exception '学习勋章会自动陈列。';end if;
  vlook:=vlook||jsonb_build_object(i.category,i.id);
 elsif operation='settings' then
  if payload ? 'name' then
   if jsonb_typeof(payload->'name')<>'string' or length(trim(payload->>'name')) not between 1 and 20 then raise exception '名字请输入 1–20 个字。';end if;
   vlook:=vlook||jsonb_build_object('name',trim(payload->>'name'));
  end if;
  foreach k in array array['motion','visible'] loop
   if payload ? k then
    if jsonb_typeof(payload->k)<>'boolean' then raise exception '显示设置无效。';end if;
    vlook:=vlook||jsonb_build_object(k,payload->k);
   end if;
  end loop;
 end if;
 update foamlab_private.companion_profiles c set look=vlook where user_id=who;
 return base||jsonb_build_object('pet',(base->'pet')||vlook,'level_factor',30,
 'items',(select jsonb_agg(to_jsonb(c)||jsonb_build_object('unlocked',c.id=any(unlocked),'progress',case when c.requirement is not null then coalesce((counts->>(c.requirement->>'type'))::integer,0) else null end) order by c.category,c.required_level,c.id) from foamlab_private.companion_items c));
end $$;
