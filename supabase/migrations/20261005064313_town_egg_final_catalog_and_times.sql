CREATE OR REPLACE FUNCTION foamlab_private.town_egg_legacy(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

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

end $function$;

create table foamlab_private.egg_calendar(day date primary key, full_moon boolean not null default false, solstice boolean not null default false); alter table foamlab_private.egg_calendar enable row level security; revoke all on foamlab_private.egg_calendar from public,anon,authenticated;

insert into foamlab_private.egg_calendar values ('2026-01-03',true,false),('2026-02-02',true,false),('2026-03-03',true,false),('2026-04-02',true,false),('2026-05-01',true,false),('2026-05-31',true,false),('2026-06-29',true,false),('2026-07-28',true,false),('2026-08-27',true,false),('2026-09-25',true,false),('2026-10-24',true,false),('2026-11-23',true,false),('2026-12-22',false,true),('2026-12-23',true,false),('2027-01-22',true,false),('2027-02-20',true,false),('2027-03-22',true,false),('2027-04-21',true,false),('2027-05-20',true,false),('2027-06-19',true,false),('2027-07-18',true,false),('2027-08-16',true,false),('2027-09-15',true,false),('2027-10-14',true,false),('2027-11-12',true,false),('2027-12-12',true,false),('2027-12-22',false,true),('2028-01-11',true,false),('2028-02-09',true,false),('2028-03-10',true,false),('2028-04-09',true,false),('2028-05-09',true,false),('2028-06-07',true,false),('2028-07-07',true,false),('2028-08-05',true,false),('2028-09-03',true,false),('2028-10-03',true,false),('2028-11-01',true,false),('2028-11-30',true,false),('2028-12-21',false,true),('2028-12-30',true,false),('2029-01-29',true,false),('2029-02-27',true,false),('2029-03-29',true,false),('2029-04-28',true,false),('2029-05-27',true,false),('2029-06-26',true,false),('2029-07-25',true,false),('2029-08-24',true,false),('2029-09-22',true,false),('2029-10-22',true,false),('2029-11-20',true,false),('2029-12-19',true,false),('2029-12-21',false,true),('2030-01-18',true,false),('2030-02-17',true,false),('2030-03-18',true,false),('2030-04-17',true,false),('2030-05-16',true,false),('2030-06-15',true,false),('2030-07-15',true,false),('2030-08-13',true,false),('2030-09-12',true,false),('2030-10-11',true,false),('2030-11-10',true,false),('2030-12-09',true,false),('2030-12-22',false,true),('2031-01-08',true,false),('2031-02-06',true,false),('2031-03-07',true,false),('2031-04-06',true,false),('2031-05-06',true,false),('2031-06-04',true,false),('2031-07-04',true,false),('2031-08-02',true,false),('2031-09-01',true,false),('2031-10-01',true,false),('2031-10-30',true,false),('2031-11-29',true,false),('2031-12-22',false,true),('2031-12-28',true,false),('2032-01-27',true,false),('2032-02-25',true,false),('2032-03-26',true,false),('2032-04-24',true,false),('2032-05-23',true,false),('2032-06-22',true,false),('2032-07-21',true,false),('2032-08-20',true,false),('2032-09-19',true,false),('2032-10-18',true,false),('2032-11-17',true,false),('2032-12-17',true,false),('2032-12-21',false,true),('2033-01-15',true,false),('2033-02-14',true,false),('2033-03-15',true,false),('2033-04-14',true,false),('2033-05-13',true,false),('2033-06-11',true,false),('2033-07-11',true,false),('2033-08-09',true,false),('2033-09-08',true,false),('2033-10-07',true,false),('2033-11-06',true,false),('2033-12-06',true,false),('2033-12-21',false,true),('2034-01-05',true,false),('2034-02-03',true,false),('2034-03-05',true,false),('2034-04-03',true,false),('2034-05-03',true,false),('2034-06-01',true,false),('2034-06-30',true,false),('2034-07-30',true,false),('2034-08-28',true,false),('2034-09-27',true,false),('2034-10-26',true,false),('2034-11-25',true,false),('2034-12-22',false,true),('2034-12-25',true,false),('2035-01-23',true,false),('2035-02-22',true,false),('2035-03-24',true,false),('2035-04-22',true,false),('2035-05-22',true,false),('2035-06-20',true,false),('2035-07-19',true,false),('2035-08-18',true,false),('2035-09-16',true,false),('2035-10-15',true,false),('2035-11-14',true,false),('2035-12-14',true,false),('2035-12-22',false,true),('2036-01-12',true,false),('2036-02-11',true,false),('2036-03-12',true,false),('2036-04-11',true,false),('2036-05-10',true,false),('2036-06-09',true,false),('2036-07-08',true,false),('2036-08-06',true,false),('2036-09-05',true,false),('2036-10-04',true,false),('2036-11-02',true,false),('2036-12-02',true,false),('2036-12-21',false,true),('2036-12-31',true,false);

-- Final Easter egg runtime. Client observations never grant XP; currency and
-- stochastic rewards are decided once on the server under the wallet lock.
create table if not exists foamlab_private.egg_events (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users on delete cascade,
 event_key text not null, kind text not null, item text not null default '',
 province text not null default '', data jsonb not null default '{}',
 created_at timestamptz not null default clock_timestamp(),
 unique(user_id,event_key)
);
create index egg_events_user_kind_time on foamlab_private.egg_events(user_id,kind,created_at desc);
create index egg_events_street_time on foamlab_private.egg_events(province,kind,created_at desc);
alter table foamlab_private.egg_events enable row level security;
revoke all on foamlab_private.egg_events from public,anon,authenticated;
alter table foamlab_private.town_egg_catalog add column if not exists prizes jsonb not null default '[]';
create table if not exists foamlab_private.collection_times (
 user_id uuid references auth.users on delete cascade, scope text, item_id text,
 obtained_at timestamptz, primary key(user_id,scope,item_id)
);
alter table foamlab_private.collection_times enable row level security;
revoke all on foamlab_private.collection_times from public,anon,authenticated;

create or replace function foamlab_private.egg_award(who uuid, egg text) returns boolean
language plpgsql security definer set search_path='' as $$
declare c foamlab_private.town_egg_catalog; n int; prize text;
begin
 select * into c from foamlab_private.town_egg_catalog where id=egg;
 if c.id is null then return false;end if;
 insert into foamlab_private.town_eggs(user_id,egg_id) values(who,egg) on conflict do nothing;
 get diagnostics n=row_count;if n=0 then return false;end if;
 if c.reward<>'' then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-'||lower(egg)) on conflict do nothing;end if;
 if c.card<>'' then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'secret:'||lower(egg)) on conflict do nothing;end if;
 for prize in select jsonb_array_elements_text(c.prizes) loop
  insert into foamlab_private.town_inventory(user_id,item_id) values(who,prize) on conflict do nothing;
 end loop;
 if egg='W03' then
  insert into foamlab_private.town_board_messages(province,author_id,author_name,author_level,author_province,body)
  select r.province,who,p.name,foamlab_private.pet_level(p.xp),r.province,'鲨鱼学者来报到：我已点亮全部公开课程的鲨鱼脚印。'
  from public.foamlab_town_residents r join public.foamlab_pets p on p.user_id=r.user_id where r.user_id=who;
 end if;
 return true;
end $$;

create or replace function foamlab_private.egg_log(who uuid, k text, v text default '', info jsonb default '{}', nonce text default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare n int;
begin
 insert into foamlab_private.egg_events(user_id,event_key,kind,item,province,data)
 values(who,coalesce(nonce,gen_random_uuid()::text),k,coalesce(v,''),coalesce((select province from public.foamlab_town_presence where user_id=who),''),coalesce(info,'{}')) on conflict do nothing;
 get diagnostics n=row_count;return n=1;
end $$;

create or replace function foamlab_private.egg_count(who uuid,k text,v text default null,since timestamptz default '-infinity') returns int
language sql stable security definer set search_path='' as $$
select count(*)::int from foamlab_private.egg_events where user_id=who and kind=k and (v is null or item=v) and created_at>=since
$$;

create or replace function foamlab_private.egg_streak(who uuid,k text,v text) returns int
language sql stable security definer set search_path='' as $$
select count(*)::int from foamlab_private.egg_events where user_id=who and kind=k and item=v and id>coalesce((select max(id) from foamlab_private.egg_events where user_id=who and kind=k and item<>v),0)
$$;

create or replace function foamlab_private.egg_eligible(who uuid,egg text) returns boolean
language plpgsql security definer set search_path='' as $$
declare d date:=(now() at time zone 'Asia/Shanghai')::date; midnight timestamptz:=d::timestamp at time zone 'Asia/Shanghai'; h int:=extract(hour from now() at time zone 'Asia/Shanghai'); n int; ok boolean; r public.foamlab_town_residents; p jsonb; v text;
begin
 select * into r from public.foamlab_town_residents where user_id=who;
 select data into p from foamlab_private.town_egg_progress where user_id=who;
 case egg
 when 'C02' then return foamlab_private.egg_streak(who,'action','wave:mayor')>=3;
 when 'C04' then return foamlab_private.egg_streak(who,'fishing','miss')>=3;
 when 'C07' then return exists(select 1 from foamlab_private.egg_events where user_id=who and kind='group' and item='dance');
 when 'C11' then return foamlab_private.egg_count(who,'equip',null,clock_timestamp()-interval '1 minute')>=10;
 when 'N01' then return foamlab_private.egg_count(who,'action','wave:mayor')>=100;
 when 'N02' then return foamlab_private.egg_count(who,'gardener_pickup',null,midnight)>0;
 when 'N04' then return foamlab_private.egg_count(who,'linger','merchant')>0;
 when 'N05' then return foamlab_private.egg_count(who,'knowledge')>=20;
 when 'N06' then return (select count(*) from foamlab_private.egg_events where user_id=who and kind='talk' and item='engineer' and data->>'outfit'='basket')>=3;
 when 'N07' then return foamlab_private.egg_count(who,'linger','tea')>0;
 when 'N08' then return foamlab_private.egg_count(who,'reagents','complete')>0;
 when 'N09' then return (select count(distinct item) from foamlab_private.egg_events where user_id=who and kind='talk' and created_at>=midnight)>=9;
 when 'N10' then return extract(isodow from d)=7;
 when 'D01' then return to_char(d,'MM-DD')='03-14';
 when 'D02' then return to_char(d,'MM-DD')='04-01';
 when 'D03' then return to_char(d,'MM-DD')='02-10';
 when 'D04' then return to_char(d,'MM-DD')='08-13';
 when 'D05' then return to_char(d,'MM-DD')='08-23';
 when 'D06' then return extract(month from d) in (6,12);
 when 'D07' then return to_char(d,'MM-DD')='10-24';
 when 'D08' then return (now() at time zone 'Asia/Shanghai')::time between '12:00'::time and '12:30'::time;
 when 'D09' then return exists(select 1 from foamlab_private.egg_calendar where day=d and solstice);
 when 'D10' then return (select count(distinct (created_at at time zone 'Asia/Shanghai')::date) from foamlab_private.egg_events where user_id=who and kind='night')>=7;
 when 'D11' then return d=(r.created_at at time zone 'Asia/Shanghai')::date+interval '1 year';
 when 'P06' then return (select count(distinct item) from foamlab_private.egg_events where user_id=who and kind='enter' and item not in ('plaza','overseas') and created_at>=midnight)>=3;
 when 'P07' then return foamlab_private.egg_count(who,'overseas_home')>0;
 when 'P10' then return not exists(select 1 from unnest(foamlab_private.town_provinces()) t where not t=any(r.visited_provinces));
 when 'F01' then return exists(select 1 from public.town_case_attempts where user_id=who and not passed);
 when 'F02' then return foamlab_private.egg_count(who,'time_step_error')>=3;
 when 'F03' then return exists(select 1 from public.town_case_attempts a where a.user_id=who and a.passed and (select count(*) from public.town_case_attempts b where b.user_id=who and b.province=a.province and not b.passed and b.submitted_at<a.submitted_at)>=3);
 when 'F04' then return exists(select 1 from public.town_case_attempts a join public.town_province_cases c on c.province=a.province where a.user_id=who and a.passed and c.question->>'difficulty'='advanced' and not exists(select 1 from public.town_case_attempts b where b.user_id=who and b.province=a.province and b.submitted_at<a.submitted_at));
 when 'F05' then return exists(select item from foamlab_private.egg_events where user_id=who and kind='clinic_wrong' and created_at>now()-interval '7 days' group by item having count(*)>=3);
 when 'F06' then return (select count(distinct (created_at at time zone 'Asia/Shanghai')::date) from foamlab_private.egg_events where user_id=who and kind='enter' and created_at>=midnight-interval '6 days')=7;
 when 'F07' then return coalesce((select balance>999 from foamlab_private.town_wallet where user_id=who),false);
 when 'F09' then return not exists(select 1 from foamlab_private.town_art_cards c where c.rarity='common' and not exists(select 1 from foamlab_private.town_inventory i where i.user_id=who and i.item_id='art:'||c.id));
 when 'B01' then return foamlab_private.egg_count(who,'gold_bamboo')>0;
 when 'B02' then return foamlab_private.egg_count(who,'bottle')>0;
 when 'B03' then return foamlab_private.egg_count(who,'disk')>0;
 when 'B04' then return coalesce((select balance=0 from foamlab_private.town_wallet where user_id=who),true);
 when 'B05' then return coalesce((select balance=3141 from foamlab_private.town_wallet where user_id=who),false);
 when 'B06' then return foamlab_private.egg_count(who,'moonfish')>0;
 when 'K01' then return exists(select item from foamlab_private.egg_events where user_id=who and kind='art_draw' group by item having count(*)>=4);
 when 'K02' then return (select count(*) from foamlab_private.town_inventory where user_id=who and item_id in ('art:spring-blossom','art:summer-fireflies','art:autumn-leaves','art:snow-day'))=4;
 when 'K04' then return exists(select 1 from foamlab_private.town_inventory where user_id=who and item_id='art:zodiac-'||(array['rat','ox','tiger','rabbit','dragon','snake','horse','sheep','monkey','rooster','dog','pig'])[mod(extract(year from r.created_at)::int-4,12)+1]);
 when 'K06' then return foamlab_private.egg_count(who,'pity')>0;
 when 'K07' then return not exists(select 1 from foamlab_private.town_art_cards c where not exists(select 1 from foamlab_private.town_inventory i where i.user_id=who and i.item_id='art:'||c.id));
 when 'S01' then return exists(select 1 from foamlab_private.town_member_numbers where user_id=who and member_number in (1,1024,2512,3141));
 when 'S02' then return exists(select 1 from foamlab_private.egg_events a join foamlab_private.egg_events b on a.item=b.user_id::text and b.item=a.user_id::text where a.user_id=who and a.kind='house' and b.kind='house' and a.created_at>now()-interval '10 minutes' and b.created_at>now()-interval '10 minutes');
 when 'S03' then return (select count(*) from public.foamlab_town_photos where who in (a_id,b_id) and not who=any(hidden_by))>=100;
 when 'S04' then return exists(select 1 from public.foamlab_town_mail where author_id=who and status='visible' and length(regexp_replace(body,'[[:space:][:punct:]]','','g'))>=2 and regexp_replace(body,'[[:space:][:punct:]]','','g')=reverse(regexp_replace(body,'[[:space:][:punct:]]','','g')));
 when 'S05' then return exists(select 1 from public.foamlab_town_residents s where s.user_id<>who and (s.created_at at time zone 'Asia/Shanghai')::date=(r.created_at at time zone 'Asia/Shanghai')::date);
 when 'S06' then return exists(select 1 from public.foamlab_town_mail where author_id=who and author_id<>owner_id and status='visible' and extract(hour from created_at at time zone 'Asia/Shanghai')<5);
 when 'S07' then return foamlab_private.egg_count(who,'group','highfive')>0;
 when 'S08' then return foamlab_private.egg_count(who,'group','hug')>0;
 when 'S09' then return exists(select 1 from foamlab_private.town_gallery g where g.owner_id=who and not g.hidden and (select count(*) from foamlab_private.town_gallery_likes l where l.image_id=g.id)>=100);
 when 'S10' then return r.group_key<>'' and (select count(*) from public.foamlab_town_residents where group_key=r.group_key)>=10;
 when 'M03' then return foamlab_private.egg_count(who,'map_return','overseas')>0;
 when 'M05' then return extract(month from d) in (12,1,2) and exists(select 1 from public.foamlab_town_presence where user_id=who and province in ('heilongjiang','jilin','neimenggu') and seen_at>now()-interval '2 minutes');
 when 'W03' then return not exists(select 1 from public.foamlab_content c where c.kind='lesson' and c.status='published' and coalesce(c.metadata->>'admin_only','false')<>'true' and not exists(select 1 from foamlab_private.egg_events e where e.user_id=who and e.kind='footprint' and e.item=c.slug));
 when 'W05' then return (select count(distinct item) from foamlab_private.egg_events where user_id=who and kind='command_page' and created_at>=midnight)>=10;
 when 'L01' then return foamlab_private.egg_count(who,'copy')>=50;
 when 'L05' then return (select count(distinct item) from foamlab_private.egg_events where user_id=who and kind='formula_page' and created_at>=midnight)>=10;
 when 'Q01' then return coalesce((p->>'quest')::int,0)>=3;
 when 'Q02' then return (select count(distinct item) from foamlab_private.egg_events where user_id=who and kind='talk' and data->>'outfit'='egg-grid-ruler')>=9;
 when 'Q03' then return (select count(distinct (extract(month from created_at at time zone 'Asia/Shanghai')::int%12)/3) from foamlab_private.egg_events where user_id=who and kind='enter')=4;
 else return true;
 end case;
end $$;

create or replace function foamlab_private.egg_reconcile(who uuid) returns void
language plpgsql security definer set search_path='' as $$
declare egg text; n int; d date:=(now() at time zone 'Asia/Shanghai')::date;
begin
 foreach egg in array array['C02','C04','C07','C11','N01','N02','N04','N05','N06','N07','N08','N09','N10','D01','D02','D03','D04','D05','D06','D07','D09','D10','D11','P06','P07','P10','F01','F02','F03','F04','F05','F06','F09','B01','B02','B03','B06','K01','K02','K04','K06','K07','S01','S02','S05','S07','S08','S10','M03','W03','W05','L01','L05','Q03'] loop
  if not exists(select 1 from foamlab_private.town_eggs where user_id=who and egg_id=egg) and foamlab_private.egg_eligible(who,egg) then perform foamlab_private.egg_award(who,egg);end if;
 end loop;
 if (select count(distinct (created_at at time zone 'Asia/Shanghai')::date) from foamlab_private.egg_events where user_id=who and kind='enter' and (created_at at time zone 'Asia/Shanghai')::date>=d-29)=30 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-gold-leaf') on conflict do nothing;end if;
 select count(*) into n from foamlab_private.town_eggs t join foamlab_private.town_egg_catalog c on c.id=t.egg_id where t.user_id=who;
 if n>=20 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-20') on conflict do nothing;end if;
 if n>=40 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'secret:milestone40') on conflict do nothing;end if;
 if n>=80 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-vortex-spirit') on conflict do nothing;end if;
 if n>=(select count(*) from foamlab_private.town_egg_catalog) then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-all'),(who,'secret:all-town'),(who,'secret:all-panda') on conflict do nothing;end if;
end $$;

create or replace function foamlab_private.town_egg_api(operation text,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); k text:=payload->>'kind'; v text:=coalesce(payload->>'id',''); p jsonb; r jsonb; look public.foamlab_pets; presence public.foamlab_town_presence; n int; entry text; at timestamptz:=clock_timestamp(); note text:=''; minutes int; answer int;
begin
 if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) then raise exception '请登录后再发现彩蛋。';end if;
 if not exists(select 1 from public.foamlab_town_residents where user_id=who) then return jsonb_build_object('resident',false,'found','[]'::jsonb);end if;
 if not foamlab_private.town_enabled() then raise exception '小镇暂时未开放。';end if;
 perform 1 from public.foamlab_pets where user_id=who for update;
 insert into foamlab_private.town_egg_progress(user_id) values(who) on conflict do nothing;
 select data into p from foamlab_private.town_egg_progress where user_id=who for update;
 select * into look from public.foamlab_pets where user_id=who;
 select * into presence from public.foamlab_town_presence where user_id=who and seen_at>now()-interval '2 minutes';
 if operation='event' then
  if k not in ('talk','fish_miss','knowledge','readme','pin','map_return','linger_start','linger','gardener_pickup','footprint','copy','formula_page','command_page','house','clinic') then raise exception '未知观察。';end if;
  if k in ('talk','fish_miss','knowledge','linger_start','linger','gardener_pickup','house','clinic') and presence.user_id is null then raise exception '请先进入街道。';end if;
  if exists(select 1 from foamlab_private.egg_events where user_id=who and event_key=payload->>'request_id') then return foamlab_private.town_egg_api('state','{}');end if;
  if foamlab_private.egg_count(who,k,null,at-interval '1 minute')>=65 then raise exception '稍等一会儿再试。';end if;
  if k='talk' then
   if v not in ('mayor','gardener','fisher','postman','merchant','librarian','engineer','tea','researcher') then raise exception '未知居民。';end if;
   if foamlab_private.egg_count(who,k,v,at-interval '1 second')>0 then raise exception '等对方说完再聊。';end if;
   perform foamlab_private.egg_log(who,k,v,jsonb_build_object('outfit',look.outfit),payload->>'request_id');
   if look.outfit='egg-grid-ruler' then note:='小镇九字诀 · '||(array['流','体','力','学','小','镇','欢','迎','你'])[array_position(array['mayor','gardener','fisher','postman','merchant','librarian','engineer','tea','researcher'],v)];end if;
  elsif k='fish_miss' then
   if foamlab_private.egg_count(who,'fishing',null,at-interval '3 seconds')=0 then perform foamlab_private.egg_log(who,'fishing','miss','{}',payload->>'request_id');end if;
  elsif k='knowledge' then
   if exists(select 1 from foamlab_private.town_inventory where user_id=who and item_id='card:'||v) then perform foamlab_private.egg_log(who,k,v,'{}',payload->>'request_id');end if;
  elsif k='readme' then p:=p||jsonb_build_object('quest',greatest(1,coalesce((p->>'quest')::int,0)));
  elsif k='pin' then if coalesce((p->>'quest')::int,0)>=1 then p:=p||jsonb_build_object('quest',greatest(2,(p->>'quest')::int));end if;
  elsif k='map_return' then
   if p->>'last_town'='overseas' then perform foamlab_private.egg_log(who,k,'overseas','{}',payload->>'request_id');end if;
  elsif k='linger_start' then
   if v in ('tea','merchant') then p:=p||jsonb_build_object('linger_'||v,at);end if;
  elsif k='linger' then
   if v not in ('tea','merchant') then raise exception '未知停留地点。';end if;
   minutes:=case v when 'tea' then 5 else 3 end;
   if (p->>('linger_'||v))::timestamptz<=at-make_interval(mins=>minutes) then
    if foamlab_private.egg_log(who,k,v,'{}','linger:'||v||':'||(now() at time zone 'Asia/Shanghai')::date) then
     if v='merchant' and not exists(select 1 from foamlab_private.town_eggs where user_id=who and egg_id='N04') then update foamlab_private.town_wallet set balance=balance+1,earned=earned+1 where user_id=who;end if;
     if v='tea' then insert into foamlab_private.town_board_messages(province,author_id,author_name,author_level,author_province,body) select presence.province,who,look.name,foamlab_private.pet_level(look.xp),province,'茶摊打卡：坐了片刻，续一杯茶，再继续今天的学习。' from public.foamlab_town_residents where user_id=who;end if;
    end if;
   end if;
  elsif k='gardener_pickup' then
   if foamlab_private.egg_count(who,'action','water:gardener',at-interval '1 minute')>0 and foamlab_private.egg_log(who,k,'','{}','gardener:'||(now() at time zone 'Asia/Shanghai')::date) then update foamlab_private.town_wallet set balance=balance+1,earned=earned+1 where user_id=who;note:='阿竹送你 1 根竹笋。';end if;
  elsif k in ('footprint','copy','formula_page','command_page') then
   if length(v)>200 or not exists(select 1 from public.foamlab_content where slug=v and status='published' and coalesce(metadata->>'admin_only','false')<>'true' and (case when k='command_page' then kind='reference' else kind='lesson' end)) then raise exception '请从公开课程或命令页面触发。';end if;
   if k='formula_page' and not exists(select 1 from public.foamlab_content where slug=v and (body like '%$%' or body like '%\\(%')) then raise exception '这节课没有公式。';end if;
   perform foamlab_private.egg_log(who,k,v,'{}',case when k='copy' then payload->>'request_id' else k||':'||v||':'||(now() at time zone 'Asia/Shanghai')::date end);
  elsif k='house' then
   if exists(select 1 from public.foamlab_town_residents where user_id::text=v and province=presence.province and user_id<>who) then perform foamlab_private.egg_log(who,k,v,'{}',payload->>'request_id');end if;
  elsif k='clinic' then
   answer:=case v when 'missing-field' then 0 when 'patch-entry' then 1 when 'bc-typo' then 0 when 'schemes' then 1 when 'courant' then 0 when 'quality' then 0 when 'parallel' then 0 when 'bounding' then 0 when 'no-env' then 0 end;
   if answer is not null and answer<>(payload->>'choice')::int and foamlab_private.egg_count(who,'clinic_wrong',v,at-interval '5 seconds')=0 then perform foamlab_private.egg_log(who,'clinic_wrong',v,'{}',payload->>'request_id');end if;
  end if;
 elsif operation='find' then
  if not exists(select 1 from foamlab_private.town_egg_catalog where id=v) then raise exception '未知彩蛋。';end if;
  if not foamlab_private.egg_eligible(who,v) then return jsonb_build_object('eligible',false);end if;
  if v='T16' then p:=p||jsonb_build_object('split',at);
  elsif v='T17' then if not coalesce((p->>'split')::timestamptz>at-interval '60 seconds',false) then return jsonb_build_object('eligible',false);end if;p:=p-'split';
  elsif v='P02' then p:=p||jsonb_build_object('boundaryStart',at,'boundaryStage',1);
  elsif v='P01' and p->>'boundaryStage'='1' then p:=p||jsonb_build_object('boundaryStage',2);
  elsif v='Q04' then if not coalesce(p->>'boundaryStage'='2' and (p->>'boundaryStart')::timestamptz>at-interval '10 minutes',false) then return jsonb_build_object('eligible',false);end if;p:=p-'boundaryStage'-'boundaryStart';
  end if;
  perform foamlab_private.egg_award(who,v);
 elsif operation<>'state' then raise exception '未知彩蛋操作。';
 end if;
 update foamlab_private.town_egg_progress set data=p where user_id=who;
 perform foamlab_private.egg_reconcile(who);
 r:=foamlab_private.town_egg_legacy('state','{}');
 return r||jsonb_build_object('eligible',true,'calendar',(select to_jsonb(c) from foamlab_private.egg_calendar c where day=(now() at time zone 'Asia/Shanghai')::date),'party_today',(select count(distinct item)>=9 from foamlab_private.egg_events where user_id=who and kind='talk' and created_at>=date_trunc('day',now() at time zone 'Asia/Shanghai') at time zone 'Asia/Shanghai'),
 'anniversary_today',foamlab_private.egg_eligible(who,'D11'),
 'same_day_users',(select coalesce(jsonb_agg(a.user_id),'[]') from public.foamlab_town_residents a join public.foamlab_town_residents b on b.user_id=who and (a.created_at at time zone 'Asia/Shanghai')::date=(b.created_at at time zone 'Asia/Shanghai')::date),
 'visit_links',(select coalesce(jsonb_agg(jsonb_build_object('user',t.partner,'expires',t.last_visit+interval '1 day')),'[]') from (select a.item partner,max(greatest(a.created_at,b.created_at)) last_visit from foamlab_private.egg_events a join foamlab_private.egg_events b on a.item=b.user_id::text and b.item=a.user_id::text where a.user_id=who and a.kind='house' and b.kind='house' and abs(extract(epoch from a.created_at-b.created_at))<=600 and a.created_at>now()-interval '1 day' and b.created_at>now()-interval '1 day' group by a.item)t),'group_count',(select count(*) from public.foamlab_town_residents a where a.group_key<>'' and a.group_key=(select group_key from public.foamlab_town_residents where user_id=who)),'notice',note,'quest',coalesce((p->>'quest')::int,0),'week_colors',to_jsonb(case mod(extract(week from now() at time zone 'Asia/Shanghai')::int,3) when 0 then array['amber','blue','rose'] when 1 then array['blue','rose','amber'] else array['rose','amber','blue'] end),'inventory',(select jsonb_object_agg(item_id,obtained_at) from foamlab_private.town_inventory where user_id=who),'mirrors',coalesce((select jsonb_agg(item) from (select item from foamlab_private.egg_events where user_id=who and kind='art_draw' group by item having count(*)>=4)t),'[]'::jsonb),'fresh',operation='find');
end $$;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C02','','飞走的礼帽','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C04','','','["egg-old-boots"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-old-boots','outfit','老靴子','发现彩蛋「老靴子」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C06','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C07','','涡街舞会','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C09','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N01','','','["egg-mini-hat"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-mini-hat','outfit','迷你礼帽','发现彩蛋「老朋友」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N08','','试剂配色','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P05','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S07','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S08','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C05','网格质量检查员','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-c05','title','网格质量检查员','发现彩蛋「网格师的强迫症」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C08','','一封旧信','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P01','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P03','','跟着涡转','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P04','','','["egg-waterweed"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-waterweed','outfit','水草头饰','发现彩蛋「溃坝幸存者」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P08','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P09','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N07','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('Q04','二维鲨鱼','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-q04','title','二维鲨鱼','发现彩蛋「三个边界」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T01','','第一个网格','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T02','入门求解者','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-t02','title','入门求解者','发现彩蛋「开始求解」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T05','','贴体网格','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T06','方程爱好者','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-t06','title','方程爱好者','发现彩蛋「方程黑板」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T07','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T08','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T09','色图警察','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-t09','title','色图警察','发现彩蛋「彩虹色图」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T10','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T11','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T12','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T13','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T14','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T15','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T16','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T17','并行大师','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-t17','title','并行大师','发现彩蛋「并行重组」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T18','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T19','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T20','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T21','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T22','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T23','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T24','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T25','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T26','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T27','','Allrun','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T28','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('T29','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C01','老玩家','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-c01','title','老玩家','发现彩蛋「经典密码」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('M04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('W07','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('W08','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('L04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('Q01','','完整算例','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C10','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('K03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N05','书虫','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-n05','title','书虫','发现彩蛋「书虫」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('W01','','迷路的鲨鱼','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('W02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('W03','读完整本书','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-w03','title','读完整本书','发现彩蛋「课程脚印」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('W04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('L01','Ctrl+C 工程师','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-l01','title','Ctrl+C 工程师','发现彩蛋「复制工程师」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('L03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('M01','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('M02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D01','','圆周率的派','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D05','','雷诺的管子','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D06','','','["egg-release-shirt"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-release-shirt','outfit','新版纪念 T 恤','发现彩蛋「新版发布月」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D07','','','["egg-plaid-shirt"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-plaid-shirt','outfit','格子衫','发现彩蛋「程序员节」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D08','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D09','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D10','深夜调参人','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-d10','title','深夜调参人','发现彩蛋「夜猫子」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('D11','','一周年','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F01','浮点异常幸存者','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-f01','title','浮点异常幸存者','发现彩蛋「浮点异常幸存者」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F02','时间步莽夫','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-f02','title','时间步莽夫','发现彩蛋「时间步莽夫」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F03','','浪子回头','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F04','一次收敛','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-f04','title','一次收敛','发现彩蛋「一次就对」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F05','','','["egg-medical-card"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-medical-card','decoration','病历卡','发现彩蛋「病历卡」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F06','','','["egg-little-flower"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-little-flower','outfit','小红花','发现彩蛋「小红花」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F07','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F08','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('F09','画卡收藏家','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-f09','title','画卡收藏家','发现彩蛋「全图鉴」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P06','小镇串门王','','["egg-travel-pack"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-p06','title','小镇串门王','发现彩蛋「小镇串门王」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-travel-pack','outfit','旅行包','发现彩蛋「小镇串门王」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P07','','海外明信片','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('P10','走遍全国','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-p10','title','走遍全国','发现彩蛋「走遍全国」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('C11','换装狂人','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-c11','title','换装狂人','发现彩蛋「换装狂人」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N06','','','["egg-grid-ruler"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-grid-ruler','outfit','网格尺','发现彩蛋「网格尺」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N09','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('N10','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('K01','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('K02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('K04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('K05','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('K06','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('K07','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S01','幸运门牌','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-s01','title','幸运门牌','发现彩蛋「幸运门牌」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S05','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S06','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S09','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('S10','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('B01','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('B02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('B03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('B04','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('B05','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('B06','','','["egg-moonfish"]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-moonfish','decoration','月亮鱼','发现彩蛋「满月夜钓」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('M03','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('M05','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('M06','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('W05','命令行派','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-w05','title','命令行派','发现彩蛋「命令达人」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('W06','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('L02','','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('L05','','方程之树','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('Q02','小镇知音','','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-q02','title','小镇知音','发现彩蛋「九字诀」获得。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_egg_catalog(id,reward,card,prizes) values ('Q03','','四季年历','[]') on conflict(id) do update set reward=excluded.reward,card=excluded.card,prizes=excluded.prizes;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-gold-leaf','outfit','金竹叶胸针','连续 30 天进入小镇。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-vortex-spirit','decoration','小涡旋精灵','发现 80 个彩蛋后，它会陪你在小镇散步。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-20','title','小镇侦探','发现 20 个彩蛋。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.pet_items(id,category,title,description,required_level,requirement) values ('egg-title-all','title','彩蛋终结者','发现全部 126 个可用彩蛋。',1,'{"type":"egg"}') on conflict(id) do update set title=excluded.title,description=excluded.description;

insert into foamlab_private.town_shop(id,price,rare) values('basket',36,false) on conflict do nothing;

create table foamlab_private.egg_time_step_gaps(province text,gap text,primary key(province,gap));alter table foamlab_private.egg_time_step_gaps enable row level security;revoke all on foamlab_private.egg_time_step_gaps from public,anon,authenticated;
insert into foamlab_private.egg_time_step_gaps values ('anhui','o2a18fc22e9fd'),('beijing','o2a18fc22e9fd'),('chongqing','o2a18fc22e9fd'),('fujian','o2a18fc22e9fd'),('gansu','o2a18fc22e9fd'),('guangdong','o2a18fc22e9fd'),('guangxi','o2a18fc22e9fd'),('guizhou','o2a18fc22e9fd'),('hainan','o2a18fc22e9fd'),('hebei','o2a18fc22e9fd'),('heilongjiang','o2a18fc22e9fd'),('henan','o2a18fc22e9fd'),('hongkong','o2a18fc22e9fd'),('hunan','o2a18fc22e9fd'),('jiangxi','o2a18fc22e9fd'),('jilin','o2a18fc22e9fd'),('liaoning','o2a18fc22e9fd'),('macao','o2a18fc22e9fd'),('neimenggu','o2a18fc22e9fd'),('ningxia','o2a18fc22e9fd'),('qinghai','o2a18fc22e9fd'),('shandong','o2a18fc22e9fd'),('shanghai','o2a18fc22e9fd'),('shanxi','o2a18fc22e9fd'),('sichuan','o2a18fc22e9fd'),('taiwan','o2a18fc22e9fd'),('xinjiang','o2a18fc22e9fd'),('xizang','o2a18fc22e9fd'),('zhejiang','o2a18fc22e9fd');
create or replace function foamlab_private.egg_presence_hook() returns trigger
language plpgsql security definer set search_path='' as $$
declare p jsonb; d date:=(now() at time zone 'Asia/Shanghai')::date;
begin
 insert into foamlab_private.town_egg_progress(user_id) values(new.user_id) on conflict do nothing;
 select data into p from foamlab_private.town_egg_progress where user_id=new.user_id for update;
 perform foamlab_private.egg_log(new.user_id,'enter',new.province,'{}','enter:'||d||':'||new.province);
 if extract(hour from now() at time zone 'Asia/Shanghai')<5 then perform foamlab_private.egg_log(new.user_id,'night','','{}','night:'||d);end if;
 if p->>'last_town'='overseas' and new.province=(select province from public.foamlab_town_residents where user_id=new.user_id) then
  if foamlab_private.egg_log(new.user_id,'overseas_home','','{}','overseas_home') then insert into public.foamlab_town_mail(owner_id,author_id,body) values(new.user_id,new.user_id,'海外明信片：越过海面，风也带回了熟悉的小镇气息。愿你在每一个新的计算域里，都找到回家的边界。');end if;
 end if;
 update foamlab_private.town_egg_progress set data=p||jsonb_build_object('last_town',new.province) where user_id=new.user_id;
 return new;
end $$;
create trigger egg_presence after insert or update of seen_at on public.foamlab_town_presence for each row execute function foamlab_private.egg_presence_hook();

create or replace function foamlab_private.egg_pet_hook() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.outfit is distinct from old.outfit or new.form is distinct from old.form or new.decoration is distinct from old.decoration or new.ride is distinct from old.ride then
 perform foamlab_private.egg_log(new.user_id,'equip',new.outfit);end if;
 return new;
end $$;
create trigger egg_pet after update on public.foamlab_pets for each row execute function foamlab_private.egg_pet_hook();

create or replace function foamlab_private.egg_play_hook() returns trigger
language plpgsql security definer set search_path='' as $$
declare p jsonb; night boolean:=extract(hour from now() at time zone 'Asia/Shanghai') not between 5 and 18; prize text;
begin
 if new.kind='shoot' and random()<.01 then
  update foamlab_private.town_wallet set balance=balance+9,earned=earned+9 where user_id=new.user_id;
  perform foamlab_private.egg_log(new.user_id,'gold_bamboo',new.item);perform foamlab_private.egg_award(new.user_id,'B01');
 end if;
 if new.item like 'art:%' then perform foamlab_private.egg_log(new.user_id,'art_draw',substr(new.item,5),'{}','art:'||new.event_key);end if;
 if new.kind='fish' then
  perform foamlab_private.egg_log(new.user_id,'fishing','caught','{}',new.event_key);
  select data into p from foamlab_private.town_egg_progress where user_id=new.user_id for update;
  if (night and p->>'quest'='2') or random()<.01 then
   perform foamlab_private.egg_log(new.user_id,'bottle',floor(random()*50)::int::text);
   perform foamlab_private.egg_award(new.user_id,'B02');
   if night and p->>'quest'='2' then update foamlab_private.town_egg_progress set data=p||'{"quest":3}'::jsonb where user_id=new.user_id;end if;
  end if;
  if random()<.005 then perform foamlab_private.egg_log(new.user_id,'disk');perform foamlab_private.egg_award(new.user_id,'B03');end if;
  if night and exists(select 1 from foamlab_private.egg_calendar where day=(now() at time zone 'Asia/Shanghai')::date and full_moon) and random()<.2 then
   perform foamlab_private.egg_log(new.user_id,'moonfish');perform foamlab_private.egg_award(new.user_id,'B06');
  end if;
 end if;
 return new;
end $$;
create trigger egg_play after insert on foamlab_private.town_play_events for each row execute function foamlab_private.egg_play_hook();

create or replace function foamlab_private.egg_action_hook(payload jsonb,evt jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); target uuid; a text:=payload->>'action'; npc text:=coalesce(payload->>'npc',''); street text; n int; person uuid; people uuid[]; colors text[]; got text[];
begin
 select province into street from public.foamlab_town_presence where user_id=who;
 if npc not in ('mayor','gardener','fisher','postman','merchant','librarian','engineer','tea','researcher') then npc:='';end if;
 if payload->>'type'='act' then
  perform foamlab_private.egg_log(who,'action',a||':'||npc,payload-'user_id',evt->>'nonce');
  if a='dance' then
   select array_agg(distinct user_id) into people from foamlab_private.egg_events where province=street and kind='action' and item like 'dance:%' and created_at>clock_timestamp()-interval '10 seconds';
   if cardinality(people)>=5 then foreach person in array people loop perform foamlab_private.egg_log(person,'group','dance');perform foamlab_private.egg_award(person,'C07');end loop;perform realtime.send(jsonb_build_object('type','egg','id','C07','users',people),'town','town:'||street,true);end if;
  elsif a='experiment' and npc='researcher' then
   colors:=case mod(extract(week from now() at time zone 'Asia/Shanghai')::int,3) when 0 then array['amber','blue','rose'] when 1 then array['blue','rose','amber'] else array['rose','amber','blue'] end;
   select array_agg(data->>'color' order by id) into got from (select id,data from foamlab_private.egg_events where user_id=who and kind='action' and item='experiment:researcher' order by id desc limit 3)t;
   if got=colors then perform foamlab_private.egg_log(who,'reagents','complete');perform foamlab_private.egg_award(who,'N08');end if;
  end if;
 elsif payload->>'type'='duo-accept' then
  target:=(payload->>'user_id')::uuid;
  perform foamlab_private.egg_log(who,'duo',a||':'||target, jsonb_build_object('target',target),evt->>'nonce');
  perform foamlab_private.egg_log(target,'duo',a||':'||who,jsonb_build_object('target',who),evt->>'nonce');
  if a='highfive' and foamlab_private.egg_streak(who,'duo',a||':'||target)>=10 then
   foreach person in array array[who,target] loop perform foamlab_private.egg_log(person,'group','highfive');perform foamlab_private.egg_award(person,'S07');end loop;
   perform realtime.send(jsonb_build_object('type','egg','id','S07','users',array[who,target]),'town','town:'||street,true);
  elsif a='hug' then
   select array_agg(distinct (data->>'target')::uuid) into people from foamlab_private.egg_events where user_id=who and kind='duo' and item like 'hug:%' and created_at>clock_timestamp()-interval '10 seconds';
   if cardinality(people)>=3 then people:=people||who;foreach person in array people loop perform foamlab_private.egg_log(person,'group','hug');perform foamlab_private.egg_award(person,'S08');end loop;perform realtime.send(jsonb_build_object('type','egg','id','S08','users',people),'town','town:'||street,true);end if;
  end if;
 end if;
end $$;

create or replace function foamlab_private.egg_case_hook() returns trigger
language plpgsql security definer set search_path='' as $$
declare bad boolean;
begin
 -- Evaluate only time-step blanks against the private key and the saved submission.
 select exists(select 1 from foamlab_private.case_answers a cross join lateral jsonb_array_elements(a.data->'answers') s join public.town_case_drafts d on d.user_id=new.user_id and d.province=new.province where a.province=new.province and exists(select 1 from foamlab_private.egg_time_step_gaps t where t.province=new.province and t.gap=s->>'id') and not coalesce(foamlab_private.case_match(d.answers->(s->>'id'),s),false)) into bad;
 if bad then
  perform foamlab_private.egg_log(new.user_id,'time_step_error',new.province,'{}','step-error:'||new.id);
 else delete from foamlab_private.egg_events where user_id=new.user_id and kind='time_step_error';end if;
 return new;
end $$;
create trigger egg_case after insert on public.town_case_attempts for each row execute function foamlab_private.egg_case_hook();

-- First-unlock times do not change when equipment is switched or records reloaded.
create or replace function foamlab_private.collection_snapshot(who uuid,scope_name text,items jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare x jsonb; known timestamptz;
begin
 for x in select * from jsonb_array_elements(items) where value->>'unlocked'='true' loop
  select obtained_at into known from foamlab_private.town_inventory where user_id=who and item_id=x->>'id';
  if known is null and x->>'requirement' is null then
   select min(created_at) into known from (select created_at,sum(points) over(order by created_at,id) xp from public.foamlab_pet_events where user_id=who)t where xp>=30*coalesce((x->>'required_level')::int,1)*(coalesce((x->>'required_level')::int,1)-1);
  end if;
  if known is null and coalesce((x->>'required_level')::int,0)=1 and x->>'requirement' is null then select created_at into known from public.foamlab_pets where user_id=who;end if;
  insert into foamlab_private.collection_times(user_id,scope,item_id,obtained_at) values(who,scope_name,x->>'id',coalesce(known,clock_timestamp())) on conflict do nothing;
  if known is not null then update foamlab_private.collection_times set obtained_at=known where user_id=who and scope=scope_name and item_id=x->>'id' and obtained_at is null;end if;
 end loop;
 return (select coalesce(jsonb_agg(a.value||jsonb_build_object('obtained_at',c.obtained_at)),'[]'::jsonb) from jsonb_array_elements(items) a left join foamlab_private.collection_times c on c.user_id=who and c.scope=scope_name and c.item_id=a.value->>'id');
end $$;

CREATE OR REPLACE FUNCTION foamlab_private.town_action(payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

 declare who uuid:=auth.uid(); p public.foamlab_town_presence; target uuid; item foamlab_private.pet_items;

 typ text:=payload->>'type'; action_id text:=payload->>'action'; epoch double precision:=extract(epoch from now()); evt jsonb; recent jsonb; invite jsonb;

 begin

 if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) or not foamlab_private.town_enabled() then raise exception using errcode='42501',message='请登录后进入小镇。'; end if;

 if exists(select 1 from public.foamlab_settings where key='town_options' and value->>'interactions'='false') then raise exception '街道互动暂时关闭。'; end if;

 select * into p from public.foamlab_town_presence where user_id=who and seen_at>now()-interval '2 minutes' for update;

 if not found or not exists(select 1 from public.foamlab_town_residents where user_id=who) then raise exception '请先进入街道。'; end if;

 select coalesce(jsonb_agg(x),'[]') into recent from jsonb_array_elements(p.recent_actions) x where (x->>'t')::double precision>epoch-60;

 if (select count(*) from jsonb_array_elements(recent) x where (x->>'t')::double precision>epoch-10)>=3 then raise exception '动作太快啦，稍等几秒。'; end if;

 if typ not in ('act','emote','duo-invite','duo-accept','duo-decline') or typ is null then raise exception '动作类型无效。'; end if;

 select * into item from foamlab_private.pet_items where id=action_id;

 if typ in ('act','emote','duo-invite') and (item.id is null or not foamlab_private.town_unlocked(who,action_id) or (typ='act' and item.category<>'action') or (typ='emote' and item.category<>'emote') or (typ='duo-invite' and (item.category<>'duo' or item.id in ('selfie','give-bamboo')))) then raise exception '这个动作尚未解锁或请使用专用互动按钮。'; end if;

 if typ like 'duo-%' then

 target:=(payload->>'user_id')::uuid;

 if target=who or not exists(select 1 from public.foamlab_town_presence where user_id=target and province=p.province and seen_at>now()-interval '2 minutes') then raise exception '这位邻居已离开街道。'; end if;

 if typ='duo-invite' then

 if (select count(*) from jsonb_array_elements(recent) x where x->>'target'=target::text)>=3 then raise exception '请稍后再邀请这位邻居。'; end if;

 invite:=jsonb_build_object('to',target,'action',action_id,'t',epoch);

 update public.foamlab_town_presence set invitations=coalesce((select jsonb_agg(x) from jsonb_array_elements(invitations) x where (x->>'t')::double precision>epoch-15 and x->>'to'<>target::text),'[]')||jsonb_build_array(invite) where user_id=who;

 else

 select x into invite from public.foamlab_town_presence s cross join lateral jsonb_array_elements(s.invitations) x where s.user_id=target and x->>'to'=who::text and x->>'action'=action_id and (x->>'t')::double precision>epoch-15 limit 1;

 if invite is null then raise exception '邀请已过期，请重新发起。'; end if;

 -- The recipient's recent event records reject replay while the invitation is live.

 if exists(select 1 from jsonb_array_elements(recent) x where x->>'invite'=md5(invite::text)) then raise exception '这个邀请已处理。'; end if;

 end if;

 end if;

 recent:=recent||jsonb_build_array(jsonb_build_object('t',epoch,'target',target,'invite',case when typ in ('duo-accept','duo-decline') then md5(invite::text) end));

 update public.foamlab_town_presence set recent_actions=recent where user_id=who;

 evt:=jsonb_build_object('type',typ,'from',who,'to',target,'action',action_id,'nonce',substr(md5(random()::text),1,8));

 perform realtime.send(evt,'town','town:'||p.province,true);

 perform foamlab_private.egg_action_hook(payload,evt);
 return evt;

 end $function$;

CREATE OR REPLACE FUNCTION foamlab_private.town_play_api(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 declare who uuid:=auth.uid(); d date:=(now() at time zone 'Asia/Shanghai')::date;
 k text; item text; event text; n integer; added integer:=0; spent integer:=0; reward jsonb:='{}';
 w foamlab_private.town_wallet; run foamlab_private.town_training_runs; request uuid; next_step integer; case_name text; roll float; ids text[]; reward_rare boolean:=false; art text; draft foamlab_private.town_training_draws;
 begin
 if who is null or not foamlab_private.has_github_identity() or not exists(select 1 from auth.users where id=who) then raise exception using errcode='42501',message='请先使用 GitHub 登录。';end if;
 if foamlab_private.has_role(array['blocked']) or not foamlab_private.town_enabled() then raise exception using errcode='42501',message='小镇暂时无法使用。';end if;
 if not exists(select 1 from public.foamlab_town_residents where user_id=who) then raise exception '请先选择小镇入住。';end if;
 insert into foamlab_private.town_wallet(user_id) values(who) on conflict do nothing;
 select * into w from foamlab_private.town_wallet where user_id=who for update;
 update foamlab_private.town_training_runs set expired_at=clock_timestamp()

 where user_id=who and step<5 and expired_at is null and (created_at at time zone 'Asia/Shanghai')::date<>d;

 if operation='state' then perform foamlab_private.town_hidden_cards(who);return foamlab_private.town_play_state(who);end if;
 if operation='import_cards' then
   if not exists(select 1 from foamlab_private.town_play_events where user_id=who and event_key='import:cards') then
    for item in select distinct jsonb_array_elements_text(payload->'cards') loop
     if item=any(array['blockmesh','checkmesh','snappy','decompose','reconstruct','setfields','icofoam','simplefoam','pimplefoam','interfoam','foamtovtk','postprocess','mapfields','toposet','foamdict','foammonitor','controldict','fvschemes','fvsolution','courant','yplus','forcecoeffs','probes','fieldaverage','q','wallshear','kinematic','zero','parallel','converge']::text[]) then insert into foamlab_private.town_inventory values(who,'card:'||item,now()) on conflict do nothing;end if;
    end loop;
    insert into foamlab_private.town_play_events(user_id,event_key,kind) values(who,'import:cards','import');
   end if;
 

 elsif operation in ('training_draw','training_start','training_replay') then

   request:=(payload->>'request_id')::uuid;if request is null then raise exception '缺少请求编号。';end if;

   -- A retried start must return the same run, never create another attempt.

   if operation<>'training_draw' then

    select * into run from foamlab_private.town_training_runs where user_id=who and request_id=request;

    if found then

     if run.expired_at is not null then raise exception '这次实训已过期，请重新抽取。';end if;

     return foamlab_private.town_play_state(who)||jsonb_build_object('reward',jsonb_build_object('run_id',run.id));

    end if;

   end if;

   if exists(select 1 from foamlab_private.town_training_runs where user_id=who and step<5 and expired_at is null) then

    raise exception '今天已有正在进行的实训，请先完成；未完成实训会在北京时间零点作废。';

   end if;

   if operation='training_draw' then

    select * into draft from foamlab_private.town_training_draws where user_id=who and request_id=request and day=d;

    if not found then

     select c.id into case_name from foamlab_private.town_training_cases c where c.enabled

      and (coalesce(payload->>'theme','全部')='全部' or c.theme=payload->>'theme')

      and not exists(select 1 from foamlab_private.town_training_runs r where r.user_id=who and r.case_id=c.id and r.step=5)

      order by random() limit 1;

     if case_name is null then raise exception '该主题的算例已全部完成，可从已完成目录中重复运行，或选择其他主题。';end if;

     insert into foamlab_private.town_training_draws(user_id,case_id,request_id,day) values(who,case_name,request,d)

      on conflict(user_id) do update set case_id=excluded.case_id,request_id=excluded.request_id,day=excluded.day,drawn_at=now()

      returning * into draft;

    end if;

    reward:=jsonb_build_object('case_id',draft.case_id,'draw_id',draft.request_id);

   else

    if operation='training_replay' then

     case_name:=payload->>'case_id';

     if not exists(select 1 from foamlab_private.town_training_runs where user_id=who and case_id=case_name and step=5) then

      raise exception '只能重复运行已经完成的算例。';

     end if;

    else

     select * into draft from foamlab_private.town_training_draws where user_id=who and request_id=(payload->>'draw_id')::uuid and day=d;

     if not found then raise exception '抽取预览已失效，请重新抽取后开始。';end if;

     case_name:=draft.case_id;

     if not exists(select 1 from foamlab_private.town_training_cases where id=case_name and enabled)

      or exists(select 1 from foamlab_private.town_training_runs where user_id=who and case_id=case_name and step=5) then

      raise exception '这个算例已不在待完成池中，请重新抽取。';end if;

    end if;

    if (select count(*) from foamlab_private.town_training_runs where user_id=who and created_at>now()-interval '1 hour')>=30 then

     raise exception '今天运行较频繁，请稍后再开始。';end if;

    insert into foamlab_private.town_training_runs(user_id,case_id,request_id,is_replay) values(who,case_name,request,operation='training_replay') returning * into run;

    delete from foamlab_private.town_training_draws where user_id=who;

    reward:=jsonb_build_object('run_id',run.id);

   end if;

 elsif operation='training_step' then

   select * into run from foamlab_private.town_training_runs where id=(payload->>'run_id')::uuid and user_id=who for update;

   if run.id is null then raise exception '未找到这次实训。';end if;

   if run.step<5 and (run.expired_at is not null or (run.created_at at time zone 'Asia/Shanghai')::date<>d) then

    raise exception '这次未完成实训已过期，请重新抽取。';end if;

   next_step:=(payload->>'step')::integer;

   if next_step is null or next_step<0 or next_step>4 or next_step>run.step then raise exception '请按顺序完成实训。';end if;

   if next_step=run.step then

    if clock_timestamp()<run.updated_at+interval '1 second' then raise exception '请先阅读当前步骤的运行结果。';end if;

    update foamlab_private.town_training_runs set step=step+1,updated_at=clock_timestamp(),finished_at=case when step=4 then clock_timestamp() else null end where id=run.id;

    if next_step=4 then

     insert into foamlab_private.town_play_events(user_id,event_key,kind,item,amount) values(who,'training:'||d||':'||run.case_id,'training',run.case_id,8) on conflict do nothing;

     get diagnostics n=row_count;if n=1 then added:=8;end if;

     perform foamlab_private.pet_award(who,'training','training:'||run.case_id,20,0);

    end if;

   end if;

 elsif operation='activity' then
   k:=payload->>'kind';item:=payload->>'item';
   if k='shoot' then
    if item is null or item !~ '^[a-z]+:[0-7]$' or not split_part(item,':',1)=any(foamlab_private.town_provinces()) then raise exception '竹笋位置无效。';end if;
    if (select count(*) from foamlab_private.town_play_events where user_id=who and kind=k and day=d)>=8 then raise exception '今天已收集 8 根竹笋，明天再来。';end if;
    event:=k||':'||d||':'||item;added:=1;
   elsif k='visit' then
    if item is null or item not in ('school','workshop','hospital','library','gallery','notice','spot','institute','house') then raise exception '建筑无效。';end if;
    event:=k||':'||d||':'||item;
   elsif k in ('greet','learn') then
    select count(*) into n from foamlab_private.town_play_events where user_id=who and kind=k and day=d;
    if n>=(case when k='greet' then 2 else 1 end) then return foamlab_private.town_play_state(who);end if;
    event:=k||':'||d||':'||n;added:=case when k='learn' then 2 else 0 end;
   elsif k='fish' then
    request:=(payload->>'request_id')::uuid;if request is null then raise exception '缺少请求编号。';end if;
    event:='fish:'||request;
    select e.item into item from foamlab_private.town_play_events e where user_id=who and event_key=event;
    if found then return foamlab_private.town_play_state(who)||jsonb_build_object('reward',jsonb_build_object('item',item));end if;
    if exists(select 1 from foamlab_private.town_play_events where user_id=who and kind=k and created_at>clock_timestamp()-interval '5 seconds') then raise exception '休息一下，再抛竿。';end if;
    if (select count(*) from foamlab_private.town_play_events where user_id=who and kind=k and day=d)>=20 then raise exception '今天已收竿 20 次，明天再来。';end if;
    item:='card:'||foamlab_private.town_draw_card();added:=2;
    insert into foamlab_private.town_inventory values(who,item,now()) on conflict do nothing;
    if random()<0.25 then art:='art:'||foamlab_private.town_draw_art_card();perform foamlab_private.egg_log(who,'art_draw',substr(art,5));insert into foamlab_private.town_inventory values(who,art,now()) on conflict do nothing;end if;reward:=jsonb_build_object('item',item,'art',art);
   else raise exception '未知活动。';end if;
   insert into foamlab_private.town_play_events(user_id,event_key,kind,item,amount) values(who,event,k,item,added) on conflict do nothing;
   get diagnostics n=row_count;if n=0 then added:=0;end if;
 elsif operation in ('buy','box') then
   request:=(payload->>'request_id')::uuid;if request is null then raise exception '缺少请求编号。';end if;
   event:='purchase:'||request;
   select e.item into item from foamlab_private.town_play_events e where user_id=who and event_key=event;
   if found then return foamlab_private.town_play_state(who)||jsonb_build_object('reward',jsonb_build_object('item',item,'repeated',true));end if;
   if operation='buy' then
    item:=payload->>'item';select price,s.rare into spent,reward_rare from foamlab_private.town_shop s where id=item;
    if spent is null then raise exception '商品不存在。';end if;
    if item in (select foamlab_private.pet_unlocked(who)) then raise exception '这件收藏已解锁，可以直接使用。';end if;
   else
    spent:=12;roll:=random();
    if (select count(*) from (select item from foamlab_private.town_play_events where user_id=who and kind='box' order by created_at desc limit 5)t)=5 and not exists(select 1 from (select item from foamlab_private.town_play_events where user_id=who and kind='box' order by created_at desc limit 5)t where item like 'art:%') then roll:=.5;perform foamlab_private.egg_log(who,'pity');end if;
    if roll<0.4 then item:='card:'||foamlab_private.town_draw_card();elsif roll<0.65 then item:='art:'||foamlab_private.town_draw_art_card();
    else reward_rare:=roll>=0.9;select id into item from foamlab_private.town_shop s where s.rare=reward_rare order by random() limit 1;end if;
   end if;
   if w.balance<spent then raise exception '竹笋不足，还差 % 根。',spent-w.balance;end if;
   if exists(select 1 from foamlab_private.town_inventory where user_id=who and item_id=item) or (item not like 'card:%' and item in(select foamlab_private.pet_unlocked(who))) then added:=3;
   else insert into foamlab_private.town_inventory values(who,item,now());end if;
   insert into foamlab_private.town_play_events(user_id,event_key,kind,item,amount) values(who,event,operation,item,added-spent);
   reward:=jsonb_build_object('item',item,'rare',reward_rare,'duplicate',added=3,'refund',added);
 else raise exception '未知操作。';end if;
 update foamlab_private.town_wallet set balance=balance+added-spent,earned=earned+case when spent=0 then added else 0 end,updated_at=now() where user_id=who;
 if (select count(*) from foamlab_private.town_play_events where user_id=who and day=d and kind='shoot')>=5
 and (select count(*) from foamlab_private.town_play_events where user_id=who and day=d and kind='visit')>=3
 and (select count(*) from foamlab_private.town_play_events where user_id=who and day=d and kind='greet')>=2
 and exists(select 1 from foamlab_private.town_play_events where user_id=who and day=d and kind='fish')
 and exists(select 1 from foamlab_private.town_play_events where user_id=who and day=d and kind='learn')
 and exists(select 1 from foamlab_private.town_play_events where user_id=who and day=d and kind='training') then
  insert into foamlab_private.town_play_events(user_id,event_key,kind,amount) values(who,'daily:'||d,'daily',10) on conflict do nothing;
  get diagnostics n=row_count;if n=1 then update foamlab_private.town_wallet set balance=balance+10,earned=earned+10 where user_id=who;art:='art:'||foamlab_private.town_draw_art_card();perform foamlab_private.egg_log(who,'art_draw',substr(art,5));insert into foamlab_private.town_inventory values(who,art,now()) on conflict do nothing;reward:=reward||jsonb_build_object('daily_art',art);end if;
 end if;
 perform foamlab_private.town_hidden_cards(who);return foamlab_private.town_play_state(who)||jsonb_build_object('reward',reward);
 end $function$;

CREATE OR REPLACE FUNCTION foamlab_private.town_play_state(who uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jsonb_build_object(
 'obtained_at',(select coalesce(jsonb_object_agg(item_id,obtained_at),'{}') from foamlab_private.town_inventory where user_id=who),
 'balance',coalesce((select balance from foamlab_private.town_wallet where user_id=who),0),
 'earned',coalesce((select earned from foamlab_private.town_wallet where user_id=who),0),
 'inventory',coalesce((select jsonb_agg(item_id) from foamlab_private.town_inventory where user_id=who),'[]'::jsonb),
 'day',jsonb_build_object('date',(now() at time zone 'Asia/Shanghai')::date,
 'shoots',coalesce((select jsonb_agg(item) from foamlab_private.town_play_events where user_id=who and kind='shoot' and day=(now() at time zone 'Asia/Shanghai')::date),'[]'::jsonb),
 'visits',coalesce((select jsonb_agg(item) from foamlab_private.town_play_events where user_id=who and kind='visit' and day=(now() at time zone 'Asia/Shanghai')::date),'[]'::jsonb),
 'fish',(select count(*) from foamlab_private.town_play_events where user_id=who and kind='fish' and day=(now() at time zone 'Asia/Shanghai')::date),
 'greet',(select count(*) from foamlab_private.town_play_events where user_id=who and kind='greet' and day=(now() at time zone 'Asia/Shanghai')::date),
 'learn',(select count(*) from foamlab_private.town_play_events where user_id=who and kind='learn' and day=(now() at time zone 'Asia/Shanghai')::date),
 'training',(select count(*) from foamlab_private.town_play_events where user_id=who and kind='training' and day=(now() at time zone 'Asia/Shanghai')::date),
 'done',exists(select 1 from foamlab_private.town_play_events where user_id=who and kind='daily' and day=(now() at time zone 'Asia/Shanghai')::date)),
 'runs',foamlab_private.town_training_records(who),

 'completed_cases',coalesce((select jsonb_agg(distinct case_id) from foamlab_private.town_training_runs where user_id=who and step=5),'[]'::jsonb),

 'server_now',now(),'day_reset_at',(((now() at time zone 'Asia/Shanghai')::date+1)::timestamp at time zone 'Asia/Shanghai'),
 'achievements',foamlab_private.town_achievements(who),
 'shop',(select jsonb_agg(jsonb_build_object('id',s.id,'price',s.price,'rare',s.rare,'category',i.category,'title',i.title,'description',i.description)) from foamlab_private.town_shop s join foamlab_private.pet_items i on i.id=s.id),
 'box',jsonb_build_object('price',12,'cardChance',40,'artChance',25,'commonChance',25,'rareChance',10,'duplicateRefund',3)) $function$;

CREATE OR REPLACE FUNCTION foamlab_private.pet_api(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare who uuid:=auth.uid(); p public.foamlab_pets; lvl integer; item foamlab_private.pet_items; awarded integer:=0; lesson uuid; result jsonb; unlocked text[]; favorite text; festival_item foamlab_private.pet_items; festival_key text; calendar jsonb; dates jsonb;
begin
 if who is null or not foamlab_private.has_github_identity() or not exists(select 1 from auth.users where id=who) then raise exception using errcode='42501',message='请先使用 GitHub 登录。'; end if;
 if foamlab_private.has_role(array['blocked']) then raise exception using errcode='42501',message='此账号的成长功能暂时停用。'; end if;
 if operation not in ('state','checkin','equip','settings') or operation is null then raise exception '未知操作。'; end if;
 insert into public.foamlab_pets(user_id) values(who) on conflict do nothing;
 select * into p from public.foamlab_pets where user_id=who for update;
 -- Permanent claims are recorded only inside the configured festival window.
 select value->to_char(now() at time zone 'Asia/Shanghai','YYYY') into calendar from public.foamlab_settings where key='town_festivals';
 for festival_item in select * from foamlab_private.pet_items where festival is not null loop
 foreach festival_key in array string_to_array(festival_item.festival,',') loop
 dates:=calendar->festival_key;
 if jsonb_typeof(dates)='array' and jsonb_array_length(dates)=2 then
 begin
 if (now() at time zone 'Asia/Shanghai')::date between (dates->>0)::date and (dates->>1)::date then
 perform foamlab_private.pet_award(who,'festival','claim:'||festival_item.id,0,0);
 end if;
 exception when invalid_datetime_format or datetime_field_overflow then null;
 end;
 end if;
 end loop;
 end loop;
 -- Import existing completed lessons once. The unique ledger key also handles undo/redo.
 for lesson in select lp.content_id from public.foamlab_learning_progress lp join public.foamlab_content c on c.id=lp.content_id
 where lp.user_id=who and lp.completed and c.kind='lesson' and c.status='published' and coalesce(c.metadata->>'admin_only','false')<>'true'
 and not exists(select 1 from public.foamlab_pet_events e where e.user_id=who and e.event_key='course:'||lp.content_id) loop
  perform foamlab_private.pet_award(who,'course','course:'||lesson,25,0,lesson);
 end loop;
 select * into p from public.foamlab_pets where user_id=who;
 lvl:=foamlab_private.pet_level(p.xp);
 if operation='checkin' then
  awarded:=foamlab_private.pet_award(who,'checkin','checkin:'||(now() at time zone 'Asia/Shanghai')::date,10,1);
 elsif operation='equip' then
  select * into item from foamlab_private.pet_items where id=payload->>'id';
  if not found or not foamlab_private.town_unlocked(who,item.id) then raise exception '这个收藏尚未解锁。'; end if;
  if item.category='form' then update public.foamlab_pets set form=item.id where user_id=who;
  elsif item.category='outfit' then update public.foamlab_pets set outfit=item.id where user_id=who;
  elsif item.category='decoration' then update public.foamlab_pets set decoration=item.id where user_id=who;
  elsif item.category='action' then update public.foamlab_pets set action=item.id where user_id=who;
  elsif item.category='ride' then update public.foamlab_pets set ride=item.id where user_id=who;
  elsif item.category in ('house','title') then perform foamlab_private.town_api('settings',jsonb_build_object(case when item.category='house' then 'house_style' else 'title_id' end,item.id));
  else raise exception '请在小镇动作栏中选择表情或互动；纪念章会自动展示。'; end if;
 elsif operation='settings' then
  if payload ? 'quickbar' then
   if jsonb_typeof(payload->'quickbar')<>'array' or jsonb_array_length(payload->'quickbar')<>6 then raise exception '快捷栏包含六个动作。'; end if;
   for favorite in select jsonb_array_elements_text(payload->'quickbar') loop
    if not exists(select 1 from foamlab_private.pet_items where id=favorite and category in ('action','duo','emote')) or not foamlab_private.town_unlocked(who,favorite) then raise exception '快捷栏中有尚未解锁的动作。'; end if;
   end loop;
   update public.foamlab_pets set quickbar=array(select jsonb_array_elements_text(payload->'quickbar')) where user_id=who;
  end if;
  if payload ? 'show_town_entry' then update public.foamlab_pets set show_town_entry=(payload->>'show_town_entry')::boolean where user_id=who; end if;
  if payload ? 'name' and (jsonb_typeof(payload->'name')<>'string' or char_length(trim(payload->>'name')) not between 1 and 20) then raise exception '名字请输入 1–20 个字。'; end if;
  if payload ? 'visible' and jsonb_typeof(payload->'visible')<>'boolean' then raise exception '显示设置无效。'; end if;
  if payload ? 'motion' and jsonb_typeof(payload->'motion')<>'boolean' then raise exception '动画设置无效。'; end if;
  update public.foamlab_pets set name=case when payload ? 'name' then trim(payload->>'name') else name end,
  visible=coalesce((payload->>'visible')::boolean,visible),motion=coalesce((payload->>'motion')::boolean,motion) where user_id=who;
 end if;
 select * into p from public.foamlab_pets where user_id=who;
 lvl:=foamlab_private.pet_level(p.xp);
 select array_agg(id) into unlocked from foamlab_private.pet_unlocked(who) id;
 -- Moderated/deleted contributions can lower XP; equipment follows current unlocks.
 if not exists(select 1 from foamlab_private.pet_items where id=p.form and category='form' and id=any(unlocked)) then p.form:='cub'; end if;
 if not exists(select 1 from foamlab_private.pet_items where id=p.outfit and category='outfit' and id=any(unlocked)) then p.outfit:='none'; end if;
 if not exists(select 1 from foamlab_private.pet_items where id=p.action and category='action' and id=any(unlocked)) then p.action:='wave'; end if;
 if not exists(select 1 from foamlab_private.pet_items where id=p.decoration and category='decoration' and id=any(unlocked)) then p.decoration:='no-decor'; end if;
 if not p.ride=any(unlocked) then p.ride:='walk'; end if;
 if exists(select 1 from unnest(p.quickbar) id where not id=any(unlocked)) then p.quickbar:=array['wave','highfive','smile','heart','thumb','give-bamboo']; end if;
 update public.foamlab_pets set ride=p.ride,quickbar=p.quickbar,form=p.form,outfit=p.outfit,action=p.action,decoration=p.decoration where user_id=who;
 result:=jsonb_build_object('pet',to_jsonb(p),'level',lvl,'level_start',30*lvl*(lvl-1),'next_level_xp',30*lvl*(lvl+1),'awarded',awarded,
 'checked_in',exists(select 1 from public.foamlab_pet_events where user_id=who and event_key='checkin:'||(now() at time zone 'Asia/Shanghai')::date),
 'items',(select jsonb_agg(to_jsonb(i)||jsonb_build_object('unlocked',i.id=any(unlocked)) order by category,required_level,id) from foamlab_private.pet_items i),
 'events',(select coalesce(jsonb_agg(to_jsonb(e)),'[]'::jsonb) from (select kind,points,created_at from public.foamlab_pet_events where user_id=who order by id desc limit 8) e));
 result:=jsonb_set(result,'{items}',foamlab_private.collection_snapshot(who,'town',result->'items'));
 return result;
end $function$;

CREATE OR REPLACE FUNCTION foamlab_private.companion_api(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$

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

 'items',(select jsonb_agg(to_jsonb(c)||jsonb_build_object('unlocked',c.id=any(unlocked),'obtained_at',(select obtained_at from foamlab_private.companion_inventory where user_id=who and item_id=c.id),'progress',case when c.requirement is not null then coalesce((counts->>(c.requirement->>'type'))::integer,0) else null end) order by c.category,c.required_level,c.id) from foamlab_private.companion_items c));

end $function$;

CREATE OR REPLACE FUNCTION foamlab_private.case_medals(owner uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$

 select coalesce(jsonb_agg(jsonb_build_object('province',province,'visited',true,'completed',completed_at is not null,'visited_at',visited_at,'completed_at',completed_at)),'[]')

 from foamlab_private.case_progress where user_id=coalesce(owner,auth.uid())

 and exists(select 1 from public.foamlab_town_residents where user_id=coalesce(owner,auth.uid())) $function$;

create or replace function foamlab_private.achievement_time(who uuid,badge text,goal int) returns timestamptz language plpgsql stable security definer set search_path='' as $$
declare result timestamptz;
begin
 if badge in ('first-run','three-runs','all-runs') then select at into result from (select min(finished_at) at from foamlab_private.town_training_runs where user_id=who and step=5 group by case_id)t order by at offset greatest(goal-1,0) limit 1;
 elsif badge in ('first-card','ten-cards','all-cards') then select obtained_at into result from foamlab_private.town_inventory where user_id=who and item_id like 'card:%' order by obtained_at offset greatest(goal-1,0) limit 1;
 elsif badge in ('bamboo-20','daily-3') then select created_at into result from foamlab_private.town_play_events where user_id=who and kind=case badge when 'bamboo-20' then 'shoot' else 'daily' end order by created_at offset greatest(goal-1,0) limit 1;
 else select min(t.obtained_at) into result from foamlab_private.collection_times t join foamlab_private.town_shop s on s.id=t.item_id where t.user_id=who and t.scope='town' and (badge<>'rare-item' or s.rare);end if;
 return result;end $$;

CREATE OR REPLACE FUNCTION foamlab_private.town_achievements(who uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$

 with counts as (

 select (select count(distinct case_id) from foamlab_private.town_training_runs where user_id=who and step=5)::integer runs,

 (select count(distinct r.case_id) from foamlab_private.town_training_runs r join foamlab_private.town_training_cases c on c.id=r.case_id where r.user_id=who and r.step=5 and c.enabled)::integer independent_runs,

 (select count(*) from foamlab_private.town_training_cases where enabled)::integer all_runs,

 (select count(*) from foamlab_private.town_inventory i join foamlab_private.town_knowledge_cards c on i.item_id='card:'||c.id where i.user_id=who)::integer cards,

 (select count(*) from foamlab_private.town_play_events where user_id=who and kind='shoot')::integer shoots,

 (select count(*) from foamlab_private.town_shop s where s.id in (select foamlab_private.pet_unlocked(who)))::integer items,

 (select count(*) from foamlab_private.town_play_events where user_id=who and kind='daily')::integer days,

 (select count(*) from foamlab_private.town_shop s where s.rare and s.id in (select foamlab_private.pet_unlocked(who)))::integer rare

 ), badges as (

 select v.* from counts c cross join lateral (values

 ('first-run','第一份计算结果','完成 1 个实训算例','',c.runs,1),

 ('three-runs','算例探索者','完成 3 个不同算例','',c.runs,3),

 ('all-runs','实训全通关','完成全部 '||c.all_runs||' 个独立算例','',c.independent_runs,c.all_runs),

 ('first-card','湖边的发现','收集 1 张知识卡','',c.cards,1),

 ('ten-cards','知识收藏家','收集 10 张知识卡','',c.cards,10),

 ('all-cards','完整图鉴','收集 100 张知识卡','',c.cards,100),

 ('bamboo-20','竹林采集员','累计拾取 20 根竹笋','',c.shoots,20),

 ('first-item','小屋焕新','获得 1 件商店收藏','',c.items,1),

 ('rare-item','闪光收藏','获得 1 件稀有收藏','',c.rare,1),

 ('daily-3','小镇常客','完成 3 天的全部任务','',c.days,3)

 ) v(id,title,description,icon,progress,goal))

 select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title,'description',description,'icon',icon,'progress',least(progress,goal),'goal',goal,'unlocked',progress>=goal,'obtained_at',case when progress>=goal then foamlab_private.achievement_time(who,id,goal) end)),'[]'::jsonb) from badges $function$;

insert into foamlab_private.collection_times(user_id,scope,item_id,obtained_at) select p.user_id,'town',u.id,v.obtained_at from public.foamlab_pets p cross join lateral foamlab_private.pet_unlocked(p.user_id) u(id) left join foamlab_private.town_inventory v on v.user_id=p.user_id and v.item_id=u.id on conflict do nothing;

delete from foamlab_private.town_egg_catalog where id='P11';

revoke all on function foamlab_private.egg_award(uuid,text) from public,anon,authenticated;

revoke all on function foamlab_private.egg_log(uuid,text,text,jsonb,text) from public,anon,authenticated;

revoke all on function foamlab_private.egg_count(uuid,text,text,timestamp with time zone) from public,anon,authenticated;

revoke all on function foamlab_private.egg_streak(uuid,text,text) from public,anon,authenticated;

revoke all on function foamlab_private.egg_eligible(uuid,text) from public,anon,authenticated;

revoke all on function foamlab_private.egg_reconcile(uuid) from public,anon,authenticated;

revoke all on function foamlab_private.egg_presence_hook() from public,anon,authenticated;

revoke all on function foamlab_private.egg_pet_hook() from public,anon,authenticated;

revoke all on function foamlab_private.egg_play_hook() from public,anon,authenticated;

revoke all on function foamlab_private.egg_action_hook(jsonb,jsonb) from public,anon,authenticated;

revoke all on function foamlab_private.egg_case_hook() from public,anon,authenticated;

revoke all on function foamlab_private.collection_snapshot(uuid,text,jsonb) from public,anon,authenticated;

revoke all on function foamlab_private.achievement_time(uuid,text,integer) from public,anon,authenticated;

revoke all on function foamlab_private.town_egg_legacy(text,jsonb) from public,anon,authenticated;