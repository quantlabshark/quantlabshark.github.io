-- Account-backed town play. All balances, draws and progress updates are serialized per account.
create table foamlab_private.town_wallet (
 user_id uuid primary key references auth.users on delete cascade,
 balance integer not null default 0 check(balance>=0), earned integer not null default 0,
 updated_at timestamptz not null default now()
);
create table foamlab_private.town_inventory (
 user_id uuid references auth.users on delete cascade, item_id text not null,
 obtained_at timestamptz not null default now(), primary key(user_id,item_id)
);
create table foamlab_private.town_play_events (
 user_id uuid references auth.users on delete cascade, event_key text not null,
 kind text not null, item text, amount integer not null default 0,
 day date not null default ((now() at time zone 'Asia/Shanghai')::date),
 created_at timestamptz not null default now(), primary key(user_id,event_key)
);
create index town_play_events_day on foamlab_private.town_play_events(user_id,day,kind);
create table foamlab_private.town_training_cases (
 id text primary key, theme text not null, title text not null, enabled boolean not null default true
);
insert into foamlab_private.town_training_cases(id,theme,title) values
 ('cavity','层流入门','顶盖驱动方腔 · Re = 10'),('cavity-re100','层流入门','细网格方腔 · Re = 100'),
 ('pitzdaily','湍流','后台阶湍流 · pitzDaily'),('flange','传热','法兰瞬态导热'),
 ('scalar','标量输运','后台阶被动标量输运'),('dambreak','多相流','水柱溃坝 · damBreak');
create table foamlab_private.town_training_runs (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users on delete cascade,
 case_id text not null references foamlab_private.town_training_cases, step integer not null default 0 check(step between 0 and 5),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), finished_at timestamptz,
 request_id uuid not null, unique(user_id,request_id)
);
create index town_training_user on foamlab_private.town_training_runs(user_id,created_at desc);
create table foamlab_private.town_shop (
 id text primary key references foamlab_private.pet_items(id),price integer not null check(price>0),rare boolean not null default false
);
insert into foamlab_private.town_shop values
 ('flower',8,false),('strawhat',12,false),('redscarf',16,false),('goggles',18,false),('backpack',24,false),('headphones',30,false),
 ('meadow',12,false),('bamboo-grove',18,false),('pond',24,false),('lantern',36,false),
 ('wizard',60,true),('spacesuit',90,true),('observatory',75,true),('blossom',48,true);
alter table foamlab_private.town_wallet enable row level security;
alter table foamlab_private.town_inventory enable row level security;
alter table foamlab_private.town_play_events enable row level security;
alter table foamlab_private.town_training_cases enable row level security;
alter table foamlab_private.town_training_runs enable row level security;
alter table foamlab_private.town_shop enable row level security;
revoke all on foamlab_private.town_wallet,foamlab_private.town_inventory,foamlab_private.town_play_events,foamlab_private.town_training_cases,foamlab_private.town_training_runs,foamlab_private.town_shop from public,anon,authenticated;

create function foamlab_private.town_card_ids() returns text[] language sql immutable set search_path='' as $$
 select array['blockmesh','checkmesh','snappy','decompose','reconstruct','setfields','icofoam','simplefoam','pimplefoam','interfoam','foamtovtk','postprocess','mapfields','toposet','foamdict','foammonitor','controldict','fvschemes','fvsolution','courant','yplus','forcecoeffs','probes','fieldaverage','q','wallshear','kinematic','zero','parallel','converge']::text[] $$;

create function foamlab_private.town_achievements(who uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with counts as (
 select (select count(distinct case_id) from foamlab_private.town_training_runs where user_id=who and step=5)::integer runs,
 (select count(*) from foamlab_private.town_inventory where user_id=who and item_id like 'card:%')::integer cards,
 (select count(*) from foamlab_private.town_play_events where user_id=who and kind='shoot')::integer shoots,
 (select count(*) from foamlab_private.town_inventory where user_id=who and item_id not like 'card:%')::integer items,
 (select count(*) from foamlab_private.town_play_events where user_id=who and kind='daily')::integer days,
 (select count(*) from foamlab_private.town_inventory i join foamlab_private.town_shop s on s.id=i.item_id where i.user_id=who and s.rare)::integer rare
 ), badges as (
 select v.* from counts c cross join lateral (values
 ('first-run','第一份计算结果','完成 1 个实训算例','🧪',c.runs,1),
 ('three-runs','算例探索者','完成 3 个不同算例','📐',c.runs,3),
 ('all-runs','实训全通关','完成全部 6 个算例','🏆',c.runs,6),
 ('first-card','湖边的发现','收集 1 张知识卡','🐟',c.cards,1),
 ('ten-cards','知识收藏家','收集 10 张知识卡','📚',c.cards,10),
 ('all-cards','完整图鉴','收集 30 张知识卡','🌟',c.cards,30),
 ('bamboo-20','竹林采集员','累计拾取 20 根竹笋','🌱',c.shoots,20),
 ('first-item','小屋焕新','获得 1 件商店收藏','🎁',c.items,1),
 ('rare-item','闪光收藏','获得 1 件稀有收藏','💎',c.rare,1),
 ('daily-3','小镇常客','完成 3 天的全部任务','🏡',c.days,3)
 ) v(id,title,description,icon,progress,goal))
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title,'description',description,'icon',icon,'progress',least(progress,goal),'goal',goal,'unlocked',progress>=goal)),'[]'::jsonb) from badges $$;

create function foamlab_private.town_play_state(who uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
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
 'runs',coalesce((select jsonb_agg(to_jsonb(r)) from (select id,case_id,step,created_at,updated_at,finished_at from foamlab_private.town_training_runs where user_id=who order by created_at desc limit 60) r),'[]'::jsonb),
 'achievements',foamlab_private.town_achievements(who),
 'shop',(select jsonb_agg(jsonb_build_object('id',s.id,'price',s.price,'rare',s.rare,'category',i.category,'title',i.title,'description',i.description)) from foamlab_private.town_shop s join foamlab_private.pet_items i on i.id=s.id),
 'box',jsonb_build_object('price',12,'cardChance',60,'commonChance',30,'rareChance',10,'duplicateRefund',3)) $$;

create function foamlab_private.town_play_api(operation text,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
 declare who uuid:=auth.uid(); d date:=(now() at time zone 'Asia/Shanghai')::date;
 k text; item text; event text; n integer; added integer:=0; spent integer:=0; reward jsonb:='{}';
 w foamlab_private.town_wallet; run foamlab_private.town_training_runs; request uuid; next_step integer; case_name text; roll float; ids text[]; reward_rare boolean:=false;
 begin
 if who is null or not foamlab_private.has_github_identity() or not exists(select 1 from auth.users where id=who) then raise exception using errcode='42501',message='请先使用 GitHub 登录。';end if;
 if foamlab_private.has_role(array['blocked']) or not foamlab_private.town_enabled() then raise exception using errcode='42501',message='小镇暂时无法使用。';end if;
 if not exists(select 1 from public.foamlab_town_residents where user_id=who) then raise exception '请先选择小镇入住。';end if;
 insert into foamlab_private.town_wallet(user_id) values(who) on conflict do nothing;
 select * into w from foamlab_private.town_wallet where user_id=who for update;
 if operation='state' then return foamlab_private.town_play_state(who);end if;
 if operation='import_cards' then
   if not exists(select 1 from foamlab_private.town_play_events where user_id=who and event_key='import:cards') then
    for item in select distinct jsonb_array_elements_text(payload->'cards') loop
     if item=any(foamlab_private.town_card_ids()) then insert into foamlab_private.town_inventory values(who,'card:'||item,now()) on conflict do nothing;end if;
    end loop;
    insert into foamlab_private.town_play_events(user_id,event_key,kind) values(who,'import:cards','import');
   end if;
 elsif operation='training_start' then
   request:=(payload->>'request_id')::uuid;if request is null then raise exception '缺少请求编号。';end if;
   select * into run from foamlab_private.town_training_runs where user_id=who and request_id=request;
   if run.id is null then
    if (select count(*) from foamlab_private.town_training_runs where user_id=who and created_at>now()-interval '1 hour')>=30 then raise exception '先完成已有实训，稍后再抽取。';end if;
    select c.id into case_name from foamlab_private.town_training_cases c where enabled and (coalesce(payload->>'theme','全部')='全部' or c.theme=payload->>'theme') order by random() limit 1;
    if case_name is null then raise exception '该主题暂无可运行算例。';end if;
    insert into foamlab_private.town_training_runs(user_id,case_id,request_id) values(who,case_name,request) returning * into run;
   end if;
   reward:=jsonb_build_object('run_id',run.id);
 elsif operation='training_step' then
   select * into run from foamlab_private.town_training_runs where id=(payload->>'run_id')::uuid and user_id=who for update;
   if run.id is null then raise exception '未找到这次实训。';end if;
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
    ids:=foamlab_private.town_card_ids();item:='card:'||ids[1+floor(random()*array_length(ids,1))::integer];added:=2;
    insert into foamlab_private.town_inventory values(who,item,now()) on conflict do nothing;
    reward:=jsonb_build_object('item',item);
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
    if roll<0.6 then ids:=foamlab_private.town_card_ids();item:='card:'||ids[1+floor(random()*array_length(ids,1))::integer];
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
  get diagnostics n=row_count;if n=1 then update foamlab_private.town_wallet set balance=balance+10,earned=earned+10 where user_id=who;end if;
 end if;
 return foamlab_private.town_play_state(who)||jsonb_build_object('reward',reward);
 end $$;

create function public.foamlab_town_play(operation text default 'state',payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select foamlab_private.town_play_api(operation,payload) $$;
create function foamlab_private.town_public_achievements(owner uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select case when foamlab_private.town_enabled() and exists(select 1 from public.foamlab_town_residents where user_id=owner)
 then (select coalesce(jsonb_agg(b),'[]'::jsonb) from jsonb_array_elements(foamlab_private.town_achievements(owner)) b where (b->>'unlocked')::boolean or owner=auth.uid()) else '[]'::jsonb end $$;
create function public.foamlab_town_achievements(owner uuid) returns jsonb language sql security invoker set search_path='' as $$ select foamlab_private.town_public_achievements(owner) $$;
revoke all on function foamlab_private.town_card_ids(),foamlab_private.town_achievements(uuid),foamlab_private.town_play_state(uuid),foamlab_private.town_play_api(text,jsonb),foamlab_private.town_public_achievements(uuid),public.foamlab_town_play(text,jsonb),public.foamlab_town_achievements(uuid) from public,anon,authenticated;
grant execute on function foamlab_private.town_play_api(text,jsonb),public.foamlab_town_play(text,jsonb) to authenticated;
grant execute on function foamlab_private.town_public_achievements(uuid),public.foamlab_town_achievements(uuid) to anon,authenticated;

-- Purchased items are an additional permanent unlock route; the original level and achievement rules remain.
do $$ declare definition text;begin
 select replace(pg_get_functiondef('foamlab_private.pet_unlocked(uuid)'::regprocedure),chr(13),'') into definition;
 definition:=replace(definition,'return next i.id;','if not exists(select 1 from foamlab_private.town_inventory where user_id=who and item_id=i.id) then return next i.id; end if;');
 definition:=replace(definition,'end loop;'||chr(10)||' end', 'end loop;'||chr(10)||' return query select v.item_id from foamlab_private.town_inventory v join foamlab_private.pet_items p on p.id=v.item_id where v.user_id=who;'||chr(10)||' end');
 if position('return query select v.item_id' in definition)=0 then raise exception 'pet_unlocked definition changed; review before migration';end if;
 execute definition;
end $$;

alter table public.foamlab_town_residents add column town_name text not null default '' check(char_length(town_name)<=24);
do $$ declare definition text;begin
 select pg_get_functiondef('foamlab_private.town_card(uuid)'::regprocedure) into definition;
 definition:=replace(definition,'''name'',coalesce(','''name'',coalesce(nullif(r.town_name,''''),');
 execute definition;
 select pg_get_functiondef('foamlab_private.town_api(text,jsonb)'::regprocedure) into definition;
 definition:=replace(definition,'group_name=case when payload', 'town_name=case when payload ? ''town_name'' then case when trim(coalesce(payload->>''town_name'',''''))='''' then '''' else foamlab_private.town_text(payload->>''town_name'',24) end else town_name end,'||chr(10)||' group_name=case when payload');
 if position('town_name=case' in definition)=0 then raise exception 'Review town settings definition';end if;
 execute definition;
end $$;

-- Province boards have their own storage and never write to site discussion/message tables.
create table foamlab_private.town_board_messages (
 id uuid primary key default gen_random_uuid(), province text not null,
 author_id uuid references auth.users on delete set null, author_name text not null,
 author_level integer not null, author_province text not null,
 body text not null check(char_length(body) between 1 and 500),
 created_at timestamptz not null default now(), hidden boolean not null default false,
 request_id uuid not null, unique(author_id,request_id)
);
alter table foamlab_private.town_board_messages enable row level security;
revoke all on foamlab_private.town_board_messages from public,anon,authenticated;
create index town_board_province_time on foamlab_private.town_board_messages(province,created_at desc) where not hidden;
create index town_board_author on foamlab_private.town_board_messages(author_id,created_at desc);
create function foamlab_private.town_board_api(operation text,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
 declare who uuid:=auth.uid(); target text:=payload->>'province'; p integer:=greatest(0,least(coalesce((payload->>'page')::integer,0),10000));
 card jsonb; body_text text; mod boolean:=foamlab_private.has_role(array['admin','moderator']); request uuid; total bigint;
 begin
 if not foamlab_private.town_enabled() then raise exception '小镇暂未开放。';end if;
 if target is null or not target=any(foamlab_private.town_provinces()) then raise exception '请选择小镇。';end if;
 if operation<>'list' then
  if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) then raise exception using errcode='42501',message='请使用 GitHub 登录后留言。';end if;
  card:=foamlab_private.town_card(who);if card is null then raise exception '请先入住小镇。';end if;
  -- Serialize this author's writes to enforce the posting limit across tabs.
  perform 1 from public.foamlab_town_residents where user_id=who for update;
  if operation='post' then
   request:=(payload->>'request_id')::uuid;if request is null then raise exception '缺少请求编号。';end if;
   if not exists(select 1 from foamlab_private.town_board_messages where author_id=who and request_id=request) then
    if (select count(*) from foamlab_private.town_board_messages where author_id=who and created_at>now()-interval '1 hour')>=10 then raise exception '每小时可发布 10 条小镇留言。';end if;
    body_text:=foamlab_private.town_text(payload->>'body',500);
    insert into foamlab_private.town_board_messages(province,author_id,author_name,author_level,author_province,body,request_id)
     values(target,who,card->>'name',(card->>'level')::integer,card->>'province',body_text,request);
   end if;
  elsif operation='delete' then
   update foamlab_private.town_board_messages set hidden=true where id=(payload->>'id')::uuid and province=target and (author_id=who or mod);
   if not found then raise exception using errcode='42501',message='仅作者和管理员可以删除留言。';end if;
  else raise exception '未知操作。';end if;
 end if;
 select count(*) into total from foamlab_private.town_board_messages where province=target and not hidden;
 p:=least(p,greatest(0,ceil(total/20.0)::integer-1));
 return jsonb_build_object('total',total,'page',p,'items',coalesce((select jsonb_agg(to_jsonb(m)) from
 (select id,author_id,author_name,author_level,author_province,body,created_at,(author_id=who or mod) can_delete
 from foamlab_private.town_board_messages where province=target and not hidden order by created_at desc,id offset p*20 limit 20) m),'[]'::jsonb));
 end $$;
create function public.foamlab_town_board(operation text default 'list',payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select foamlab_private.town_board_api(operation,payload) $$;
revoke all on function foamlab_private.town_board_api(text,jsonb),public.foamlab_town_board(text,jsonb) from public,anon,authenticated;
grant execute on function foamlab_private.town_board_api(text,jsonb),public.foamlab_town_board(text,jsonb) to anon,authenticated;
