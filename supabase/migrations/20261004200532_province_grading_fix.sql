create or replace function foamlab_private.case_match(answer jsonb,spec jsonb)
returns boolean language plpgsql immutable set search_path='' as $$
declare kind text:=spec->>'type'; actual text; expected text; a numeric;b numeric;n integer;i integer;
 arr text[];req text[];opt text[];pos integer:=0;nextpos integer;
begin
 if answer is null or jsonb_typeof(answer)='null' then return false;end if;
 if kind='select' or kind='name' then
  if jsonb_typeof(answer)<>'string' then return false;end if;
  actual:=trim(answer#>>'{}');
  return actual=spec->>'expected' or coalesce(spec->'alternatives' ? actual,false);
 elsif kind='number' then
  if jsonb_typeof(answer) not in ('string','number') then return false;end if;
  actual:=trim(answer#>>'{}');expected:=spec->>'expected';
  if actual !~ '^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$' or length(actual)>80 then return false;end if;
  a:=actual::numeric;b:=expected::numeric;
  return abs(a-b)<=case when b=0 then 0.000000000001 else abs(b)*0.001 end;
 elsif kind in ('vector','dimensions') then
  n:=case when kind='vector' then 3 else 7 end;
  if jsonb_typeof(answer)<>'array' or jsonb_array_length(answer)<>n then return false;end if;
  for i in 0..n-1 loop
   actual:=trim(answer->>i);
   if kind='dimensions' then
    if actual is null or actual !~ '^[+-]?[0-9]+$' or length(actual)>4 or actual::integer<>(spec->'expected'->>i)::integer then return false;end if;
   elsif not foamlab_private.case_match(answer->i,jsonb_build_object('type','number','expected',spec->'expected'->i)) then return false;
   end if;
  end loop;
  return true;
 elsif kind='commands' then
  if jsonb_typeof(answer)<>'array' or jsonb_array_length(answer)>15 then return false;end if;
  select array_agg(trim(v)) into arr from jsonb_array_elements_text(answer) v;
  select array_agg(v) into req from jsonb_array_elements_text(spec->'expected') v;
  select coalesce(array_agg(v),'{}') into opt from jsonb_array_elements_text(coalesce(spec->'optional','[]')) v;
  if coalesce(cardinality(arr),0)=0 or cardinality(arr)<>(select count(distinct v) from unnest(arr) v) then return false;end if;
  if exists(select 1 from unnest(arr) v where not v=any(req||opt)) then return false;end if;
  foreach actual in array req loop
   nextpos:=array_position(arr,actual);
   if nextpos is null or nextpos<=pos then return false;end if;
   pos:=nextpos;
  end loop;
  if array_position(arr,'checkMesh') is not null and
   (array_position(arr,'checkMesh')>=pos or (array_position(arr,'blockMesh') is not null and array_position(arr,'checkMesh')<array_position(arr,'blockMesh'))) then return false;end if;
  if array_position(arr,'foamToVTK -latestTime') is not null and array_position(arr,'foamToVTK -latestTime')<=pos then return false;end if;
  return true;
 end if;
 return false;
exception when invalid_text_representation or numeric_value_out_of_range then return false;
end $$;
revoke all on function foamlab_private.case_match(jsonb,jsonb) from public,anon,authenticated;

create or replace function foamlab_private.case_api(op text,region text,input jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid();q jsonb;keydata jsonb;draft jsonb;lastrow public.town_case_attempts;
 scores jsonb;total integer;correct integer;done boolean;firstwin boolean:=false;firstvisit boolean:=false;points integer:=0;shoots integer:=0;allgold integer;
begin
 select question into q from public.town_province_cases where province=region and enabled;
 if q is null then raise exception '这个省份的关卡尚未开放。';end if;
 if op='get' then
  if who is not null and (not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked'])) then who:=null;end if;
  select answers into draft from public.town_case_drafts where user_id=who and province=region;
  select * into lastrow from public.town_case_attempts where user_id=who and province=region order by submitted_at desc,id desc limit 1;
  select completed_at is not null into done from foamlab_private.case_progress where user_id=who and province=region;
  return jsonb_build_object('question',q,'draft',coalesce(draft,'{}'),'completed',coalesce(done,false),
   'scores',lastrow.scores,'next_submit_at',lastrow.submitted_at+interval '30 seconds','server_now',clock_timestamp(),
   'results',case when done then (select data->'results' from foamlab_private.case_answers where province=region) else null end);
 end if;
 if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) then
  raise exception using errcode='42501',message='请先使用 GitHub 登录。';end if;
 if not foamlab_private.town_enabled() then raise exception '小镇暂时无法使用。';end if;
 if not exists(select 1 from public.foamlab_town_residents where user_id=who) then raise exception '先入住任意小镇，就可以挑战所有省份。';end if;
 -- Lock the shared pet first, matching reward writes and serializing simultaneous submissions.
 perform 1 from public.foamlab_pets where user_id=who for update;
 if op='visit' then
  insert into foamlab_private.case_progress(user_id,province) values(who,region) on conflict do nothing;
  get diagnostics total=row_count;firstvisit:=total=1;
  if firstvisit then
   insert into foamlab_private.town_inventory(user_id,item_id) values(who,'visit-'||region) on conflict do nothing;
   points:=foamlab_private.pet_award(who,'province_visit','province-visit:'||region,5,0);
  end if;
  return jsonb_build_object('visited',true,'first',firstvisit,'xp',points);
 end if;
 if op not in ('save','submit') then raise exception '未知操作。';end if;
 if input is null or jsonb_typeof(input)<>'object' or octet_length(input::text)>65536 then raise exception '填写内容格式无效。';end if;
 select data into keydata from foamlab_private.case_answers where province=region;
 if keydata is null then raise exception '关卡正在准备，请稍后再试。';end if;
 if exists(select 1 from jsonb_object_keys(input) k where not exists(select 1 from jsonb_array_elements(keydata->'answers') s where s->>'id'=k)) then raise exception '填写内容包含无效题号。';end if;
 insert into public.town_case_drafts(user_id,province,answers) values(who,region,input)
 on conflict(user_id,province) do update set answers=excluded.answers,updated_at=clock_timestamp();
 if op='save' then return jsonb_build_object('saved',true,'saved_at',clock_timestamp());end if;
 select * into lastrow from public.town_case_attempts where user_id=who and province=region order by submitted_at desc,id desc limit 1;
 if lastrow.submitted_at+interval '30 seconds'>clock_timestamp() then
  return jsonb_build_object('cooldown',true,'next_submit_at',lastrow.submitted_at+interval '30 seconds','server_now',clock_timestamp());
 end if;
 with checked as (
  select s->>'file' as file,coalesce(foamlab_private.case_match(input->(s->>'id'),s),false) as ok from jsonb_array_elements(keydata->'answers') s
 ), grouped as (select file,count(*)::integer total,count(*) filter(where ok)::integer correct from checked group by file)
 select jsonb_agg(jsonb_build_object('file',g.file,'correct',g.correct,'total',g.total) order by g.file),sum(g.total),sum(g.correct)
 into scores,total,correct from grouped g;
 done:=total>0 and total=correct;
 insert into public.town_case_attempts(user_id,province,scores,passed) values(who,region,scores,done);
 if done then
  insert into foamlab_private.case_progress(user_id,province) values(who,region) on conflict do nothing;
  update foamlab_private.case_progress set completed_at=clock_timestamp() where user_id=who and province=region and completed_at is null;
  get diagnostics total=row_count;firstwin:=total=1;
  if firstwin then
   points:=foamlab_private.pet_award(who,'province_case','province-case:'||region,(q->>'xp')::integer,0);
   shoots:=(q->>'bamboo')::integer;
   insert into foamlab_private.town_wallet(user_id,balance,earned) values(who,shoots,shoots)
    on conflict(user_id) do update set balance=foamlab_private.town_wallet.balance+excluded.balance,earned=foamlab_private.town_wallet.earned+excluded.earned,updated_at=now();
   insert into foamlab_private.town_inventory(user_id,item_id) values(who,'province-'||region),(who,'visit-'||region) on conflict do nothing;
   select count(*) into allgold from foamlab_private.case_progress where user_id=who and completed_at is not null;
   if allgold>=34 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'title-nine-regions') on conflict do nothing;end if;
  end if;
 end if;
 return foamlab_private.case_api('get',region,'{}')||jsonb_build_object('passed',done,'first',firstwin,'reward',jsonb_build_object('xp',points,'bamboo',shoots));
end $$;
revoke all on function foamlab_private.case_api(text,text,jsonb) from public,anon,authenticated;
grant execute on function foamlab_private.case_api(text,text,jsonb) to anon,authenticated;
