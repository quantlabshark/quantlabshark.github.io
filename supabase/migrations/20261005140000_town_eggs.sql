-- Cosmetic discoveries only. No client-triggered XP, currency or random draws.
create table foamlab_private.town_egg_catalog(id text primary key, reward text not null default '', card text not null default '');
create table foamlab_private.town_eggs(user_id uuid references auth.users on delete cascade,egg_id text references foamlab_private.town_egg_catalog,found_at timestamptz not null default now(),primary key(user_id,egg_id));
create table foamlab_private.town_egg_progress(user_id uuid primary key references auth.users on delete cascade,data jsonb not null default '{}');
alter table foamlab_private.town_egg_catalog enable row level security;
alter table foamlab_private.town_eggs enable row level security;
alter table foamlab_private.town_egg_progress enable row level security;
revoke all on foamlab_private.town_egg_catalog,foamlab_private.town_eggs,foamlab_private.town_egg_progress from public,anon,authenticated;

insert into foamlab_private.town_egg_catalog(id,reward,card) values
('T01','','第一个网格'),
('T02','初次求解者',''),
('T03','',''),
('T04','',''),
('T06','方程守望者',''),
('T07','',''),
('T08','',''),
('T10','',''),
('T11','',''),
('T12','',''),
('T13','',''),
('T14','',''),
('T15','',''),
('T16','',''),
('T17','并行大师',''),
('T18','',''),
('T19','',''),
('T20','',''),
('T21','',''),
('T22','',''),
('T23','',''),
('T24','',''),
('T25','',''),
('T26','',''),
('T27','','Allrun'),
('T28','',''),
('T29','',''),
('C01','复古玩家',''),
('C03','',''),
('C06','',''),
('C10','',''),
('D08','',''),
('P01','',''),
('P02','',''),
('P10','全域探索者',''),
('F04','一次就对',''),
('F07','',''),
('F08','',''),
('F09','普通画卡收藏家',''),
('B04','',''),
('B05','',''),
('S03','',''),
('S04','',''),
('S06','',''),
('S09','',''),
('K03','',''),
('K05','',''),
('K07','',''),
('W06','',''),
('W07','',''),
('W08','',''),
('L02','',''),
('L03','',''),
('L04','',''),
('M05','',''),
('Q04','','');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-t02','title','初次求解者','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-t06','title','方程守望者','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-t17','title','并行大师','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-c01','title','复古玩家','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-p10','title','全域探索者','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-f04','title','一次就对','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-f09','title','普通画卡收藏家','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-20','title','小镇寻宝人','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-40','title','彩蛋探险家','发现小镇彩蛋获得。',1,'{"type":"egg"}');
insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-all','title','小镇百事通','发现小镇彩蛋获得。',1,'{"type":"egg"}');


create function foamlab_private.town_egg_api(operation text,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid();item text:=payload->>'id';spec foamlab_private.town_egg_catalog;resident public.foamlab_town_residents;progress jsonb;fresh boolean:=false;n integer;stamp timestamp:=(now() at time zone 'Asia/Shanghai');ok boolean:=true;
begin
 if who is null then raise exception '请先登录。';end if;
 select * into resident from public.foamlab_town_residents where user_id=who;
 if resident.user_id is null then return jsonb_build_object('resident',false,'found','[]'::jsonb);end if;
 if operation not in ('state','find') then raise exception '未知彩蛋操作。';end if;
 if operation='find' then
  select * into spec from foamlab_private.town_egg_catalog where id=item;
  if spec.id is null then raise exception '这个彩蛋尚未开放。';end if;
  -- Match the existing reward lock order; concurrent discoveries cannot duplicate rewards.
  perform 1 from public.foamlab_pets where user_id=who for update;
  insert into foamlab_private.town_egg_progress(user_id) values(who) on conflict do nothing;
  select data into progress from foamlab_private.town_egg_progress where user_id=who for update;
  if item='T16' then progress:=progress||jsonb_build_object('split',clock_timestamp());
  elsif item='T17' then ok:=coalesce((progress->>'split')::timestamptz>clock_timestamp()-interval '60 seconds',false);progress:=progress-'split';
  elsif item='P02' then progress:=progress||jsonb_build_object('boundaryStart',clock_timestamp(),'boundaryStage',1);
  elsif item='P01' and progress->>'boundaryStage'='1' then progress:=progress||jsonb_build_object('boundaryStage',2);
  elsif item='Q04' then ok:=coalesce(progress->>'boundaryStage'='2' and (progress->>'boundaryStart')::timestamptz>clock_timestamp()-interval '10 minutes',false);progress:=progress-'boundaryStage'-'boundaryStart';
  elsif item='D08' then ok:=stamp::time between time '12:00' and time '12:30';
  elsif item='M05' then ok:=extract(month from stamp) in (12,1,2) and exists(select 1 from public.foamlab_town_presence where user_id=who and province in ('heilongjiang','jilin','neimenggu') and seen_at>now()-interval '2 minutes');
  elsif item in ('F07','B04','B05') then select coalesce((select balance from foamlab_private.town_wallet where user_id=who),0) into n;ok:=case item when 'F07' then n>999 when 'B04' then n=0 else n=3141 end;
  elsif item in ('F09','K07') then ok:=not exists(select 1 from foamlab_private.town_art_cards c where (item='K07' or c.rarity='common') and not exists(select 1 from foamlab_private.town_inventory i where i.user_id=who and i.item_id='art:'||c.id));
  elsif item='P10' then ok:=not exists(select 1 from public.town_province_cases c where c.enabled and not c.province=any(resident.visited_provinces));
  elsif item='F04' then ok:=exists(select 1 from public.town_case_attempts a join public.town_province_cases c on c.province=a.province where a.user_id=who and a.passed and c.question->>'difficulty'='advanced' and not exists(select 1 from public.town_case_attempts b where b.user_id=who and b.province=a.province and (b.submitted_at,b.id)<(a.submitted_at,a.id)));
  elsif item='S09' then ok:=exists(select 1 from foamlab_private.town_gallery g where g.owner_id=who and not g.hidden and (select count(*) from foamlab_private.town_gallery_likes l where l.image_id=g.id)>=100);
  elsif item='S03' then ok:=(select count(*) from public.foamlab_town_photos where who in (a_id,b_id) and not who=any(hidden_by))>=100;
  elsif item='S04' then ok:=exists(select 1 from public.foamlab_town_mail where author_id=who and status='visible' and length(regexp_replace(body,'[[:space:][:punct:]]','','g'))>=2 and regexp_replace(body,'[[:space:][:punct:]]','','g')=reverse(regexp_replace(body,'[[:space:][:punct:]]','','g')));
  elsif item='S06' then ok:=exists(select 1 from public.foamlab_town_mail where author_id=who and author_id<>owner_id and status='visible' and extract(hour from created_at at time zone 'Asia/Shanghai')<5);
  end if;
  if not ok then return jsonb_build_object('eligible',false);end if;
  update foamlab_private.town_egg_progress set data=progress where user_id=who;
  insert into foamlab_private.town_eggs(user_id,egg_id) values(who,item) on conflict do nothing;
  get diagnostics n=row_count;fresh:=n=1;
  if spec.reward<>'' then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-'||lower(item)) on conflict do nothing;end if;
  if spec.card<>'' then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'secret:'||lower(item)) on conflict do nothing;end if;
  select count(*) into n from foamlab_private.town_eggs where user_id=who;
  if n>=20 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-20') on conflict do nothing;end if;
  if n>=40 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-40') on conflict do nothing;end if;
  if n=(select count(*) from foamlab_private.town_egg_catalog) then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-all') on conflict do nothing;end if;
 end if;
 return jsonb_build_object('resident',true,'fresh',fresh,'eligible',true,
  'found',coalesce((select jsonb_agg(jsonb_build_object('id',egg_id,'at',found_at) order by found_at) from foamlab_private.town_eggs where user_id=who),'[]'::jsonb),
  'homePage',(select count(*)/10 from public.foamlab_town_residents r where r.province=resident.province and (r.created_at,r.user_id)<(resident.created_at,resident.user_id)),'joined',resident.created_at,
  'photos',(select count(*) from public.foamlab_town_photos where who in(a_id,b_id) and not who=any(hidden_by)),
  'milestones',coalesce((select jsonb_agg(x) from (select created_at,kind,points from public.foamlab_pet_events where user_id=who order by created_at desc limit 20)x),'[]'::jsonb));
end $$;
revoke all on function foamlab_private.town_egg_api(text,jsonb) from public,anon,authenticated;
grant execute on function foamlab_private.town_egg_api(text,jsonb) to authenticated;
create function public.foamlab_town_eggs(operation text default 'state',payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$select foamlab_private.town_egg_api(operation,payload)$$;
revoke all on function public.foamlab_town_eggs(text,jsonb) from public,anon,authenticated;
grant execute on function public.foamlab_town_eggs(text,jsonb) to authenticated;
