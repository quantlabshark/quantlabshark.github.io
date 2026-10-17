-- Province challenges: questions public, answer keys in a private schema.
create table public.town_province_cases(province text primary key, question jsonb not null, enabled boolean not null default true);
create table foamlab_private.case_answers(province text primary key references public.town_province_cases(province), data jsonb not null);
create table public.town_case_drafts(
 user_id uuid references auth.users(id) on delete cascade,province text references public.town_province_cases(province),
 answers jsonb not null default '{}',updated_at timestamptz not null default now(), primary key(user_id,province),
 check(jsonb_typeof(answers)='object' and octet_length(answers::text)<=65536));
create table public.town_case_attempts(
 id bigint generated always as identity primary key,user_id uuid not null references auth.users(id) on delete cascade,
 province text not null references public.town_province_cases(province),submitted_at timestamptz not null default clock_timestamp(),
 scores jsonb not null,passed boolean not null);
create index town_case_attempts_user_province_time on public.town_case_attempts(user_id,province,submitted_at desc);
create table foamlab_private.case_progress(
 user_id uuid references auth.users(id) on delete cascade,province text references public.town_province_cases(province),
 visited_at timestamptz not null default now(),completed_at timestamptz,primary key(user_id,province));
alter table public.town_province_cases enable row level security;
alter table public.town_case_drafts enable row level security;
alter table public.town_case_attempts enable row level security;
alter table foamlab_private.case_answers enable row level security;
alter table foamlab_private.case_progress enable row level security;
revoke all on public.town_province_cases,public.town_case_drafts,public.town_case_attempts,foamlab_private.case_answers,foamlab_private.case_progress from public,anon,authenticated;
grant select on public.town_province_cases to anon,authenticated;
grant select on public.town_case_drafts,public.town_case_attempts to authenticated;
create policy province_questions_read on public.town_province_cases for select to anon,authenticated using(enabled);
create policy province_draft_owner on public.town_case_drafts for select to authenticated using(user_id=(select auth.uid()));
create policy province_attempt_owner on public.town_case_attempts for select to authenticated using(user_id=(select auth.uid()) or (select foamlab_private.has_role(array['admin'])));

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
    if actual !~ '^[+-]?[0-9]+$' or length(actual)>4 or actual::integer<>(spec->'expected'->>i)::integer then return false;end if;
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
 select jsonb_agg(jsonb_build_object('file',file,'correct',correct,'total',total) order by file),sum(total),sum(correct)
 into scores,total,correct from grouped;
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
create or replace function public.town_case_get(province text)
returns jsonb language sql security invoker set search_path='' as $$select foamlab_private.case_api('get',province,'{}')$$;
create or replace function public.town_case_save(province text,answers jsonb)
returns jsonb language sql security invoker set search_path='' as $$select foamlab_private.case_api('save',province,answers)$$;
create or replace function public.town_case_submit(province text,answers jsonb)
returns jsonb language sql security invoker set search_path='' as $$select foamlab_private.case_api('submit',province,answers)$$;
create or replace function public.town_case_visit(province text)
returns jsonb language sql security invoker set search_path='' as $$select foamlab_private.case_api('visit',province,'{}')$$;
revoke all on function public.town_case_get(text),public.town_case_save(text,jsonb),public.town_case_submit(text,jsonb),public.town_case_visit(text) from public,anon,authenticated;
grant execute on function public.town_case_get(text) to anon,authenticated;
grant execute on function public.town_case_save(text,jsonb),public.town_case_submit(text,jsonb),public.town_case_visit(text) to authenticated;
create or replace function foamlab_private.case_medals(owner uuid default null)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('province',province,'visited',true,'completed',completed_at is not null)),'[]')
 from foamlab_private.case_progress where user_id=coalesce(owner,auth.uid())
 and exists(select 1 from public.foamlab_town_residents where user_id=coalesce(owner,auth.uid())) $$;
revoke all on function foamlab_private.case_medals(uuid) from public,anon,authenticated;
grant execute on function foamlab_private.case_medals(uuid) to anon,authenticated;
create or replace function public.town_case_medals(owner uuid default null)
returns jsonb language sql stable security invoker set search_path='' as $$select foamlab_private.case_medals(owner)$$;
revoke all on function public.town_case_medals(uuid) from public;
grant execute on function public.town_case_medals(uuid) to anon,authenticated;

-- Public metadata and medal definitions. Answer keys are deployed separately.
insert into public.town_province_cases(province,question) values ('beijing','{"id": "beijing", "name": "北京", "title": "顶盖驱动方腔 · Re = 10", "solver": "icoFoam", "difficulty": "intro", "story": "方腔里的第一缕涡旋，从北京开启旅程。", "xp": 20, "bamboo": 8}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-beijing','badge','北京到访章','首次到访北京省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-beijing','badge','北京省勋章','完成北京省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('tianjin','{"id": "tianjin", "name": "天津", "title": "摆动水槽中的自由液面晃荡", "solver": "interFoam", "difficulty": "basic", "story": "天津港的船舶液舱：船身摇摆时，水面如何晃荡？", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-tianjin','badge','天津到访章','首次到访天津省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-tianjin','badge','天津省勋章','完成天津省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('hebei','{"id": "hebei", "name": "河北", "title": "同轴圆筒旋转剪切流", "solver": "simpleFoam", "difficulty": "basic", "story": "河北的机械转子：观察同轴圆筒间的黏性剪切。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-hebei','badge','河北到访章','首次到访河北省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-hebei','badge','河北省勋章','完成河北省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('shanxi','{"id": "shanxi", "name": "山西", "title": "带电细线周围的电势分布", "solver": "electrostaticFoam", "difficulty": "intro", "story": "山西的静电除尘装置，把带电细线周围看不见的电场画出来。", "xp": 20, "bamboo": 8}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-shanxi','badge','山西到访章','首次到访山西省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-shanxi','badge','山西省勋章','完成山西省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('neimenggu','{"id": "neimenggu", "name": "内蒙古", "title": "旋转坐标系中的搅拌器", "solver": "SRFSimpleFoam", "difficulty": "advanced", "story": "从草原风电联想旋转参考系；本关研究坐标随叶轮转动时的流动。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-neimenggu','badge','内蒙古到访章','首次到访内蒙古省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-neimenggu','badge','内蒙古省勋章','完成内蒙古省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('liaoning','{"id": "liaoning", "name": "辽宁", "title": "Mach 5 气流绕过 15° 楔体", "solver": "rhoCentralFoam", "difficulty": "advanced", "story": "辽宁的航空制造：超声速来流在楔体前形成激波。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-liaoning','badge','辽宁到访章','首次到访辽宁省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-liaoning','badge','辽宁省勋章','完成辽宁省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('jilin','{"id": "jilin", "name": "吉林", "title": "热源房间中的自然对流", "solver": "buoyantBoussinesqSimpleFoam", "difficulty": "advanced", "story": "吉林的冬季供暖：暖空气上升，冷空气回流。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-jilin','badge','吉林到访章','首次到访吉林省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-jilin','badge','吉林省勋章','完成吉林省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('heilongjiang','{"id": "heilongjiang", "name": "黑龙江", "title": "上下温差驱动的 Bénard 对流胞", "solver": "buoyantBoussinesqPimpleFoam", "difficulty": "advanced", "story": "黑龙江的上下温差：流体层中出现有序的对流胞。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-heilongjiang','badge','黑龙江到访章','首次到访黑龙江省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-heilongjiang','badge','黑龙江省勋章','完成黑龙江省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('shanghai','{"id": "shanghai", "name": "上海", "title": "楼群周围的风环境", "solver": "simpleFoam", "difficulty": "basic", "story": "上海陆家嘴的楼群风环境，观察建筑周围的加速与尾流。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-shanghai','badge','上海到访章','首次到访上海省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-shanghai','badge','上海省勋章','完成上海省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('jiangsu','{"id": "jiangsu", "name": "江苏", "title": "鼓泡塔中的气液两相上升流", "solver": "twoPhaseEulerFoam", "difficulty": "advanced", "story": "江苏化工园区的鼓泡反应器：气泡带动液体循环。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-jiangsu','badge','江苏到访章','首次到访江苏省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-jiangsu','badge','江苏省勋章','完成江苏省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('zhejiang','{"id": "zhejiang", "name": "浙江", "title": "浅水流越过方形底部隆起", "solver": "shallowWaterFoam", "difficulty": "basic", "story": "由钱塘江潮联想浅水流，看看底部隆起怎样改变水深与流速。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-zhejiang','badge','浙江到访章','首次到访浙江省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-zhejiang','badge','浙江省勋章','完成浙江省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('anhui','{"id": "anhui", "name": "安徽", "title": "移动标量源的输运与扩散", "solver": "scalarTransportFoam", "difficulty": "intro", "story": "由巢湖水质监测联想标量输运：移动源持续释放示踪物。", "xp": 20, "bamboo": 8}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-anhui','badge','安徽到访章','首次到访安徽省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-anhui','badge','安徽省勋章','完成安徽省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('fujian','{"id": "fujian", "name": "福建", "title": "圆柱绕流的势流解", "solver": "potentialFoam", "difficulty": "intro", "story": "福建海上桥墩的理想化圆柱绕流，用速度势重建流场。", "xp": 20, "bamboo": 8}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-fujian','badge','福建到访章','首次到访福建省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-fujian','badge','福建省勋章','完成福建省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('jiangxi','{"id": "jiangxi", "name": "江西", "title": "偏心圆柱周围的非牛顿流动", "solver": "nonNewtonianIcoFoam", "difficulty": "basic", "story": "景德镇瓷泥的流变特性：偏心圆柱之间的非牛顿剪切。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-jiangxi','badge','江西到访章','首次到访江西省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-jiangxi','badge','江西省勋章','完成江西省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('shandong','{"id": "shandong", "name": "山东", "title": "周期圆管的充分发展湍流", "solver": "simpleFoam", "difficulty": "basic", "story": "山东的输油管道：周期边界截取一段充分发展湍流。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-shandong','badge','山东到访章','首次到访山东省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-shandong','badge','山东省勋章','完成山东省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('henan','{"id": "henan", "name": "河南", "title": "通道中的多孔阻力区", "solver": "pisoFoam", "difficulty": "basic", "story": "河南粮仓的通风，从通道中的多孔阻力区开始理解。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-henan','badge','河南到访章','首次到访河南省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-henan','badge','河南省勋章','完成河南省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('hubei','{"id": "hubei", "name": "湖北", "title": "水柱溃坝 · damBreak", "solver": "interFoam", "difficulty": "basic", "story": "湖北的水利工程：释放静止水柱，观察自由液面推进。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-hubei','badge','湖北到访章','首次到访湖北省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-hubei','badge','湖北省勋章','完成湖北省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('hunan','{"id": "hunan", "name": "湖南", "title": "方形截面弯管的二次流", "solver": "simpleFoam", "difficulty": "basic", "story": "由湘江弯道联想弯管内流：转弯让截面速度重新分布。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-hunan','badge','湖南到访章','首次到访湖南省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-hunan','badge','湖南省勋章','完成湖南省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('guangdong','{"id": "guangdong", "name": "广东", "title": "法兰瞬态导热", "solver": "laplacianFoam", "difficulty": "intro", "story": "广东电子制造的热管理：观察热量在金属法兰中扩散。", "xp": 20, "bamboo": 8}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-guangdong','badge','广东到访章','首次到访广东省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-guangdong','badge','广东省勋章','完成广东省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('guangxi','{"id": "guangxi", "name": "广西", "title": "黏弹性流体通过收缩通道", "solver": "pimpleFoam", "difficulty": "advanced", "story": "广西糖浆的黏弹性：收缩通道里应力与速度如何耦合？", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-guangxi','badge','广西到访章','首次到访广西省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-guangxi','badge','广西省勋章','完成广西省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('hainan','{"id": "hainan", "name": "海南", "title": "欠膨胀射流的膨胀与压缩结构", "solver": "rhoCentralFoam", "difficulty": "advanced", "story": "海南文昌的喷流联想：欠膨胀射流中形成压缩与膨胀结构。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-hainan','badge','海南到访章','首次到访海南省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-hainan','badge','海南省勋章','完成海南省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('chongqing','{"id": "chongqing", "name": "重庆", "title": "双入口弯管中的层流混合", "solver": "icoFoam", "difficulty": "intro", "story": "重庆两江交汇的微缩联想：两股流体在弯管中汇合。", "xp": 20, "bamboo": 8}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-chongqing','badge','重庆到访章','首次到访重庆省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-chongqing','badge','重庆省勋章','完成重庆省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('sichuan','{"id": "sichuan", "name": "四川", "title": "翼型外流与压力分布", "solver": "simpleFoam", "difficulty": "basic", "story": "四川的飞机设计：翼型两侧的流速和压力为何不同？", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-sichuan','badge','四川到访章','首次到访四川省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-sichuan','badge','四川省勋章','完成四川省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('guizhou','{"id": "guizhou", "name": "贵州", "title": "旋转参考系中的二维搅拌容器", "solver": "simpleFoam", "difficulty": "advanced", "story": "贵州酿造中的搅拌罐，用多参考系描述转子与静止容器。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-guizhou','badge','贵州到访章','首次到访贵州省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-guizhou','badge','贵州省勋章','完成贵州省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('yunnan','{"id": "yunnan", "name": "云南", "title": "润湿壁面附近的毛细上升", "solver": "interFoam", "difficulty": "basic", "story": "云南茶叶与植物吸水的联想：润湿壁面使液面爬升。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-yunnan','badge','云南到访章','首次到访云南省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-yunnan','badge','云南省勋章','完成云南省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('xizang','{"id": "xizang", "name": "西藏", "title": "液体储罐的瞬态卸压", "solver": "sonicLiquidFoam", "difficulty": "advanced", "story": "由高原压差联想储罐卸压，观察可压缩液体的压力传播。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-xizang','badge','西藏到访章','首次到访西藏省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-xizang','badge','西藏省勋章','完成西藏省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('shaanxi','{"id": "shaanxi", "name": "陕西", "title": "激波管：激波、接触面与膨胀波", "solver": "rhoCentralFoam", "difficulty": "basic", "story": "陕西航天科研常见的激波管：两侧初态推动压力波传播。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-shaanxi','badge','陕西到访章','首次到访陕西省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-shaanxi','badge','陕西省勋章','完成陕西省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('gansu','{"id": "gansu", "name": "甘肃", "title": "超声速气流越过前向台阶", "solver": "rhoCentralFoam", "difficulty": "advanced", "story": "从甘肃航天发射联想超声速流动，观察前向台阶前后的激波。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-gansu','badge','甘肃到访章','首次到访甘肃省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-gansu','badge','甘肃省勋章','完成甘肃省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('qinghai','{"id": "qinghai", "name": "青海", "title": "磁场作用下的 Hartmann 流", "solver": "mhdFoam", "difficulty": "advanced", "story": "青海盐湖导电卤水的联想：磁场如何改变通道速度分布？", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-qinghai','badge','青海到访章','首次到访青海省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-qinghai','badge','青海省勋章','完成青海省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('ningxia','{"id": "ningxia", "name": "宁夏", "title": "周期方盒中的衰减湍流", "solver": "dnsFoam", "difficulty": "advanced", "story": "由宁夏风沙中的湍动联想周期方盒，观察涡的衰减。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-ningxia','badge','宁夏到访章','首次到访宁夏省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-ningxia','badge','宁夏省勋章','完成宁夏省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('xinjiang','{"id": "xinjiang", "name": "新疆", "title": "后台阶湍流 · pitzDaily", "solver": "simpleFoam", "difficulty": "basic", "story": "新疆戈壁风越过陡坎的联想：后台阶后的回流与再附着。", "xp": 40, "bamboo": 12}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-xinjiang','badge','新疆到访章','首次到访新疆省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-xinjiang','badge','新疆省勋章','完成新疆省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('taiwan','{"id": "taiwan", "name": "台湾", "title": "斜激波在壁面上的反射", "solver": "rhoCentralFoam", "difficulty": "advanced", "story": "在台湾站探索高速气流：一道斜激波撞上壁面后，波面与压力如何变化？", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-taiwan','badge','台湾到访章','首次到访台湾省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-taiwan','badge','台湾省勋章','完成台湾省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('hongkong','{"id": "hongkong", "name": "香港", "title": "运动锥体驱动的变形网格流动", "solver": "pimpleFoam", "difficulty": "advanced", "story": "香港港湾的运动结构联想：锥体移动，周围网格跟着变形。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-hongkong','badge','香港到访章','首次到访香港省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-hongkong','badge','香港省勋章','完成香港省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into public.town_province_cases(province,question) values ('macao','{"id": "macao", "name": "澳门", "title": "摆动入口与部分重叠网格接口", "solver": "pimpleFoam", "difficulty": "advanced", "story": "澳门水道中的往复运动联想：移动入口经部分重叠接口连接。", "xp": 60, "bamboo": 20}'::jsonb) on conflict(province) do update set question=excluded.question;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('visit-macao','badge','澳门到访章','首次到访澳门省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('province-macao','badge','澳门省勋章','完成澳门省份关卡获得。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('title-nine-regions','title','行遍九州','集齐 34 枚金色省勋章。',1,'{"type":"province_case"}') on conflict(id) do nothing;
insert into foamlab_private.town_training_cases(id,title,theme) values ('wind-buildings','楼群周围的风环境','内外流动') on conflict(id) do update set title=excluded.title,theme=excluded.theme,enabled=true;
insert into foamlab_private.town_training_cases(id,title,theme) values ('mrf-vessel','旋转参考系中的二维搅拌容器','内外流动') on conflict(id) do update set title=excluded.title,theme=excluded.theme,enabled=true;
