-- Remove the retired course-footprint discovery and its unearned title.
-- Completion milestones use the remaining catalog; historical observations stay in the event log.

CREATE OR REPLACE FUNCTION foamlab_private.egg_award(who uuid, egg text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
 return true;
end $function$;

CREATE OR REPLACE FUNCTION foamlab_private.egg_eligible(who uuid, egg text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare d date:=(now() at time zone 'Asia/Shanghai')::date; midnight timestamptz:=d::timestamp at time zone 'Asia/Shanghai'; h int:=extract(hour from now() at time zone 'Asia/Shanghai'); n int; ok boolean; r public.foamlab_town_residents; p jsonb; v text;
begin
 if not exists(select 1 from foamlab_private.town_egg_catalog where id=egg) then return false;end if;
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
 when 'W05' then return (select count(distinct item) from foamlab_private.egg_events where user_id=who and kind='command_page' and created_at>=midnight)>=10;
 when 'L01' then return foamlab_private.egg_count(who,'copy')>=50;
 when 'L05' then return (select count(distinct item) from foamlab_private.egg_events where user_id=who and kind='formula_page' and created_at>=midnight)>=10;
 when 'Q01' then return coalesce((p->>'quest')::int,0)>=3;
 when 'Q02' then return (select count(distinct item) from foamlab_private.egg_events where user_id=who and kind='talk' and data->>'outfit'='egg-grid-ruler')>=9;
 when 'Q03' then return (select count(distinct (extract(month from created_at at time zone 'Asia/Shanghai')::int%12)/3) from foamlab_private.egg_events where user_id=who and kind='enter')=4;
 else return true;
 end case;
end $function$;

CREATE OR REPLACE FUNCTION foamlab_private.egg_reconcile(who uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare egg text; n int; d date:=(now() at time zone 'Asia/Shanghai')::date;
begin
 foreach egg in array array['C02','C04','C07','C11','N01','N02','N04','N05','N06','N07','N08','N09','N10','D01','D02','D03','D04','D05','D06','D07','D09','D10','D11','P06','P07','P10','F01','F02','F03','F04','F05','F06','F09','B01','B02','B03','B06','K01','K02','K04','K06','K07','S01','S02','S05','S07','S08','S10','M03','W05','L01','L05','Q03'] loop
  if not exists(select 1 from foamlab_private.town_eggs where user_id=who and egg_id=egg) and foamlab_private.egg_eligible(who,egg) then perform foamlab_private.egg_award(who,egg);end if;
 end loop;
 if (select count(distinct (created_at at time zone 'Asia/Shanghai')::date) from foamlab_private.egg_events where user_id=who and kind='enter' and (created_at at time zone 'Asia/Shanghai')::date>=d-29)=30 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-gold-leaf') on conflict do nothing;end if;
 select count(*) into n from foamlab_private.town_eggs t join foamlab_private.town_egg_catalog c on c.id=t.egg_id where t.user_id=who;
 if n>=20 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-20') on conflict do nothing;end if;
 if n>=40 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'secret:milestone40') on conflict do nothing;end if;
 if n>=80 then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-vortex-spirit') on conflict do nothing;end if;
 if n>=(select count(*) from foamlab_private.town_egg_catalog) then insert into foamlab_private.town_inventory(user_id,item_id) values(who,'egg-title-all'),(who,'secret:all-town'),(who,'secret:all-panda') on conflict do nothing;end if;
end $function$;

CREATE OR REPLACE FUNCTION foamlab_private.town_egg_api(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if k not in ('talk','fish_miss','knowledge','readme','pin','map_return','linger_start','linger','gardener_pickup','copy','formula_page','command_page','house','clinic') then raise exception '未知观察。';end if;
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
  elsif k in ('copy','formula_page','command_page') then
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
end $function$;

delete from foamlab_private.town_egg_catalog where id='W03';
delete from foamlab_private.pet_items where id='egg-title-w03';
