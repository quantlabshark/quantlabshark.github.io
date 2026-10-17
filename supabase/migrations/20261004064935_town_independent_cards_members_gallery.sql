-- Replace parameter variants in the active draw pool; preserve all existing runs and downloads.
update foamlab_private.town_training_cases set enabled=false;
insert into foamlab_private.town_training_cases(id,theme,title,enabled) values
('cavity','内外流动','顶盖驱动方腔 · Re = 10',true),
('pitzdaily','内外流动','后台阶湍流 · pitzDaily',true),
('flange','传热与输运','法兰瞬态导热',true),
('dambreak','自由液面','水柱溃坝 · damBreak',true),
('elbow','内外流动','双入口弯管中的层流混合',true),
('potential-cylinder','内外流动','圆柱绕流的势流解',true),
('square-bend','内外流动','方形截面弯管的二次流',true),
('airfoil','内外流动','翼型外流与压力分布',true),
('porous-blockage','内外流动','通道中的多孔阻力区',true),
('periodic-pipe','内外流动','周期圆管的充分发展湍流',true),
('rotating-cylinders','内外流动','同轴圆筒旋转剪切流',true),
('planar-contraction','内外流动','黏弹性流体通过收缩通道',true),
('offset-cylinder','内外流动','偏心圆柱周围的非牛顿流动',true),
('srf-mixer','旋转与动网格','旋转坐标系中的搅拌器',true),
('shallow-bump','自由液面','浅水流越过方形底部隆起',true),
('moving-cone','旋转与动网格','运动锥体驱动的变形网格流动',true),
('oscillating-acmi','旋转与动网格','摆动入口与部分重叠网格接口',true),
('shock-tube','可压缩流动','激波管：激波、接触面与膨胀波',true),
('forward-step','可压缩流动','超声速气流越过前向台阶',true),
('supersonic-wedge','可压缩流动','Mach 5 气流绕过 15° 楔体',true),
('oblique-shock','可压缩流动','斜激波在壁面上的反射',true),
('ladenburg-jet','可压缩流动','欠膨胀射流的膨胀与压缩结构',true),
('decompression-tank','可压缩流动','液体储罐的瞬态卸压',true),
('hartmann','多物理场','磁场作用下的 Hartmann 流',true),
('charged-wire','多物理场','带电细线周围的电势分布',true),
('hot-room','传热与输运','热源房间中的自然对流',true),
('benard-cells','传热与输运','上下温差驱动的 Bénard 对流胞',true),
('moving-source','传热与输运','移动标量源的输运与扩散',true),
('sloshing-tank','自由液面','摆动水槽中的自由液面晃荡',true),
('capillary-rise','自由液面','润湿壁面附近的毛细上升',true),
('bubble-column','自由液面','鼓泡塔中的气液两相上升流',true),
('box-turbulence','内外流动','周期方盒中的衰减湍流',true)
on conflict(id) do update set title=excluded.title,theme=excluded.theme,enabled=true;

create table foamlab_private.town_knowledge_cards(id text primary key,rarity text not null check(rarity in ('common','rare','hidden')));
alter table foamlab_private.town_knowledge_cards enable row level security;
revoke all on foamlab_private.town_knowledge_cards from public,anon,authenticated;
insert into foamlab_private.town_knowledge_cards(id,rarity) values
('blockmesh','common'),
('checkmesh','common'),
('snappy','common'),
('decompose','common'),
('reconstruct','common'),
('setfields','common'),
('icofoam','common'),
('simplefoam','common'),
('pimplefoam','common'),
('interfoam','common'),
('foamtovtk','common'),
('postprocess','common'),
('mapfields','common'),
('toposet','common'),
('foamdict','common'),
('foammonitor','common'),
('controldict','common'),
('fvschemes','common'),
('fvsolution','common'),
('courant','common'),
('yplus','common'),
('forcecoeffs','common'),
('probes','common'),
('fieldaverage','common'),
('q','common'),
('wallshear','common'),
('kinematic','common'),
('zero','common'),
('parallel','common'),
('converge','common'),
('renumber','common'),
('merge','common'),
('transform','common'),
('extrude','common'),
('features','common'),
('surfacecheck','common'),
('subset','common'),
('createpatch','common'),
('listtimes','common'),
('parafoam','common'),
('wmake','common'),
('wclean','common'),
('getdict','common'),
('help','common'),
('search','common'),
('log','common'),
('potential','common'),
('laplacian','common'),
('scalartransport','common'),
('srf','common'),
('rhocentral','common'),
('sonicliquid','common'),
('mhd','common'),
('electrostatic','common'),
('ddtscheme','common'),
('gradient','common'),
('diffusionscheme','common'),
('interpolation','common'),
('upwind','common'),
('limited','common'),
('linearsolver','common'),
('nonorthogonal','common'),
('relaxation','common'),
('residualcontrol','common'),
('writeprecision','common'),
('restart','common'),
('dimensions','common'),
('fixedvalue','common'),
('zerogradient','common'),
('empty','common'),
('symmetry','common'),
('cyclic','common'),
('inletoutlet','common'),
('noslip','common'),
('movingwall','common'),
('codedboundary','rare'),
('codestream','rare'),
('codedsource','rare'),
('overset','rare'),
('ami','rare'),
('mrf','rare'),
('refinement','rare'),
('meshindependence','rare'),
('forces','rare'),
('surfaceintegral','rare'),
('volumeaverage','rare'),
('vorticity','rare'),
('lambda2','rare'),
('gradfo','rare'),
('streamlines','rare'),
('timeaverage','rare'),
('wallunits','rare'),
('massbalance','rare'),
('pressureunits','rare'),
('boundedness','rare'),
('hidden-first-principles','hidden'),
('hidden-observer','hidden'),
('hidden-connections','hidden'),
('hidden-daily','hidden'),
('hidden-library','hidden');
create or replace function foamlab_private.town_card_ids() returns text[] language sql stable set search_path='' as $$
 select array_agg(id order by id) from foamlab_private.town_knowledge_cards $$;
create function foamlab_private.town_draw_card() returns text language sql volatile security definer set search_path='' as $$
 with tier as materialized(select case when random()<0.20 then 'rare' else 'common' end rarity)
 select c.id from foamlab_private.town_knowledge_cards c,tier t where c.rarity=t.rarity order by random() limit 1 $$;
create function foamlab_private.town_hidden_cards(who uuid) returns void language plpgsql security definer set search_path='' as $$
 begin
 insert into foamlab_private.town_inventory(user_id,item_id)
 select who,'card:'||v.id from (values
 ('hidden-first-principles',(select count(distinct r.case_id)>=3 from foamlab_private.town_training_runs r join foamlab_private.town_training_cases c on c.id=r.case_id where r.user_id=who and r.step=5 and c.enabled)),
 ('hidden-observer',(select count(*)>=20 from foamlab_private.town_play_events where user_id=who and kind='fish')),
 ('hidden-connections',(select count(distinct item)>=7 from foamlab_private.town_play_events where user_id=who and kind='visit')),
 ('hidden-daily',exists(select 1 from foamlab_private.town_play_events where user_id=who and kind='daily')),
 ('hidden-library',(select count(*)>=40 from foamlab_private.town_inventory i join foamlab_private.town_knowledge_cards c on i.item_id='card:'||c.id where i.user_id=who and c.rarity<>'hidden'))
 ) v(id,eligible) where v.eligible on conflict do nothing;
 end $$;
revoke all on function foamlab_private.town_draw_card(),foamlab_private.town_hidden_cards(uuid) from public,anon,authenticated;
do $$ declare def text; old_draw text:='ids:=foamlab_private.town_card_ids();item:=''card:''||ids[1+floor(random()*array_length(ids,1))::integer]';begin
 select pg_get_functiondef('foamlab_private.town_play_api(text,jsonb)'::regprocedure) into def;
 if position(old_draw in def)=0 or position('item=any(foamlab_private.town_card_ids())' in def)=0 then raise exception 'Review town play before migration';end if;
 def:=replace(def,old_draw,'item:=''card:''||foamlab_private.town_draw_card()');
 -- The legacy one-time browser import accepts only cards that existed before rarity was introduced.
 def:=replace(def,'item=any(foamlab_private.town_card_ids())',
 'item=any(array[''blockmesh'',''checkmesh'',''snappy'',''decompose'',''reconstruct'',''setfields'',''icofoam'',''simplefoam'',''pimplefoam'',''interfoam'',''foamtovtk'',''postprocess'',''mapfields'',''toposet'',''foamdict'',''foammonitor'',''controldict'',''fvschemes'',''fvsolution'',''courant'',''yplus'',''forcecoeffs'',''probes'',''fieldaverage'',''q'',''wallshear'',''kinematic'',''zero'',''parallel'',''converge'']::text[])');
 def:=replace(def,'if operation=''state'' then return','if operation=''state'' then perform foamlab_private.town_hidden_cards(who);return');
 def:=replace(def,'return foamlab_private.town_play_state(who)||jsonb_build_object(''reward'',reward);','perform foamlab_private.town_hidden_cards(who);return foamlab_private.town_play_state(who)||jsonb_build_object(''reward'',reward);');
 execute def;
end $$;
create or replace function foamlab_private.town_achievements(who uuid) returns jsonb language sql stable security definer set search_path='' as $$
 with counts as (
 select (select count(distinct case_id) from foamlab_private.town_training_runs where user_id=who and step=5)::integer runs,
 (select count(distinct r.case_id) from foamlab_private.town_training_runs r join foamlab_private.town_training_cases c on c.id=r.case_id where r.user_id=who and r.step=5 and c.enabled)::integer independent_runs,
 (select count(*) from foamlab_private.town_training_cases where enabled)::integer all_runs,
 (select count(*) from foamlab_private.town_inventory i join foamlab_private.town_knowledge_cards c on i.item_id='card:'||c.id where i.user_id=who)::integer cards,
 (select count(*) from foamlab_private.town_play_events where user_id=who and kind='shoot')::integer shoots,
 (select count(*) from foamlab_private.town_inventory where user_id=who and item_id not like 'card:%')::integer items,
 (select count(*) from foamlab_private.town_play_events where user_id=who and kind='daily')::integer days,
 (select count(*) from foamlab_private.town_inventory i join foamlab_private.town_shop s on s.id=i.item_id where i.user_id=who and s.rare)::integer rare
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
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title,'description',description,'icon',icon,'progress',least(progress,goal),'goal',goal,'unlocked',progress>=goal)),'[]'::jsonb) from badges $$;
-- Stable, account-owned member numbers survive moves and leaving/rejoining.
create table foamlab_private.town_member_numbers (
 user_id uuid primary key references auth.users on delete cascade,
 member_number bigint generated always as identity unique not null,
 joined_at timestamptz not null default now()
);
alter table foamlab_private.town_member_numbers enable row level security;
revoke all on foamlab_private.town_member_numbers from public,anon,authenticated;
revoke all on sequence foamlab_private.town_member_numbers_member_number_seq from public,anon,authenticated;
insert into foamlab_private.town_member_numbers(user_id,joined_at)
 select user_id,created_at from public.foamlab_town_residents order by created_at,user_id;
create function foamlab_private.town_member_number_assign() returns trigger language plpgsql security definer set search_path='' as $$
 begin insert into foamlab_private.town_member_numbers(user_id,joined_at) values(new.user_id,new.created_at) on conflict(user_id) do nothing;return new;end $$;
revoke all on function foamlab_private.town_member_number_assign() from public,anon,authenticated;
create trigger town_member_number_assign after insert on public.foamlab_town_residents for each row execute function foamlab_private.town_member_number_assign();
do $$ declare def text;begin
 select pg_get_functiondef('foamlab_private.town_card(uuid)'::regprocedure) into def;
 if position('''pet_name'',p.name' in def)=0 then raise exception 'Review town_card before applying';end if;
 def:=replace(def,'''pet_name'',p.name','''resident_number'',(select member_number from foamlab_private.town_member_numbers where user_id=who),''pet_name'',p.name');execute def;
 select pg_get_functiondef('foamlab_private.town_map()'::regprocedure) into def;
 def:=replace(def,'case when x.n>=3 then x.n end','x.n');
 def:=replace(def,'case when x.n>=3 then (select','(select');
 def:=replace(def,'''2 minutes'') end','''2 minutes'')');
 def:=replace(def,'''month'',now())) end','''month'',now()))');
 if position('x.n>=3' in def)>0 then raise exception 'Review town_map before applying';end if;execute def;
end $$;

-- Public exhibition metadata and likes stay independent from the main discussion system.
create table foamlab_private.town_gallery (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users on delete cascade,
 object_path text unique not null,
 title text not null check(char_length(title) between 1 and 100),
 description text not null default '' check(char_length(description)<=500),
 author_name text not null, author_level integer not null, province text not null,
 created_at timestamptz not null default now(), hidden boolean not null default false
);
create table foamlab_private.town_gallery_likes (
 image_id uuid not null references foamlab_private.town_gallery on delete cascade,
 user_id uuid not null references auth.users on delete cascade,
 created_at timestamptz not null default now(), primary key(image_id,user_id)
);
create index town_gallery_owner_time on foamlab_private.town_gallery(owner_id,created_at desc);
create index town_gallery_visible_time on foamlab_private.town_gallery(created_at desc,id) where not hidden;
create index town_gallery_likes_user on foamlab_private.town_gallery_likes(user_id);
alter table foamlab_private.town_gallery enable row level security;
alter table foamlab_private.town_gallery_likes enable row level security;
revoke all on foamlab_private.town_gallery,foamlab_private.town_gallery_likes from public,anon,authenticated;

create function foamlab_private.town_gallery_can_upload() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and foamlab_private.has_github_identity() and foamlab_private.town_enabled()
 and not foamlab_private.has_role(array['blocked']) and exists(select 1 from public.foamlab_town_residents where user_id=auth.uid()) $$;
create function foamlab_private.town_gallery_can_remove(path text) returns boolean language sql stable security definer set search_path='' as $$
 select foamlab_private.town_gallery_can_upload() and
 (split_part(path,'/',1)=auth.uid()::text or foamlab_private.has_role(array['admin','moderator']))
 and not exists(select 1 from foamlab_private.town_gallery where object_path=path and not hidden) $$;
revoke all on function foamlab_private.town_gallery_can_upload(),foamlab_private.town_gallery_can_remove(text) from public,anon,authenticated;
grant execute on function foamlab_private.town_gallery_can_upload(),foamlab_private.town_gallery_can_remove(text) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('foamlab-town-gallery','foamlab-town-gallery',true,6291456,array['image/png','image/jpeg','image/webp']);
create policy town_gallery_upload on storage.objects for insert to authenticated with check(
 bucket_id='foamlab-town-gallery' and (storage.foldername(name))[1]=(select auth.uid()::text)
 and (select foamlab_private.town_gallery_can_upload())
);
create policy town_gallery_manage_read on storage.objects for select to authenticated using(
 bucket_id='foamlab-town-gallery' and ((storage.foldername(name))[1]=(select auth.uid()::text) or (select foamlab_private.has_role(array['admin','moderator'])))
);
create policy town_gallery_remove on storage.objects for delete to authenticated using(
 bucket_id='foamlab-town-gallery' and foamlab_private.town_gallery_can_remove(name)
);

create function foamlab_private.town_gallery_api(operation text,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
 declare who uuid:=auth.uid(); target uuid:=nullif(payload->>'owner','')::uuid;
 p integer:=greatest(0,least(coalesce((payload->>'page')::integer,0),10000)); total integer; likes_total bigint;
 pic foamlab_private.town_gallery; card jsonb; path text; title_text text; body text; liked boolean;
 mod boolean:=foamlab_private.has_role(array['admin','moderator']);
 begin
 if not foamlab_private.town_enabled() then raise exception '小镇暂未开放。';end if;
 if operation='list' then
  select count(*),coalesce(sum((select count(*) from foamlab_private.town_gallery_likes l where l.image_id=g.id)),0)
  into total,likes_total from foamlab_private.town_gallery g where not hidden and (target is null or owner_id=target);
  p:=least(p,greatest(0,ceil(total/12.0)::integer-1));
  return jsonb_build_object('total',total,'total_likes',likes_total,'page',p,'items',coalesce((select jsonb_agg(to_jsonb(v)) from (
   select g.id,g.owner_id,g.object_path,g.title,g.description,g.created_at,
   coalesce(c.card->>'name',g.author_name) author_name,coalesce((c.card->>'level')::integer,g.author_level) author_level,
   coalesce(c.card->>'province',g.province) province,
   (select count(*) from foamlab_private.town_gallery_likes l where l.image_id=g.id) likes,
   exists(select 1 from foamlab_private.town_gallery_likes l where l.image_id=g.id and l.user_id=who) liked,
   coalesce(g.owner_id=who or mod,false) can_delete
   from foamlab_private.town_gallery g left join lateral(select foamlab_private.town_card(g.owner_id) card) c on true
   where not g.hidden and (target is null or g.owner_id=target)
   order by case when payload->>'sort'='popular' then (select count(*) from foamlab_private.town_gallery_likes l where l.image_id=g.id) else 0 end desc,g.created_at desc,g.id
   offset p*12 limit 12) v),'[]'::jsonb));
 end if;
 if not foamlab_private.town_gallery_can_upload() then raise exception using errcode='42501',message='请使用 GitHub 登录并入住后操作。';end if;
 if operation='publish' then
  perform 1 from public.foamlab_town_residents where user_id=who for update;
  path:=payload->>'object_path';
  if path is null or split_part(path,'/',1)<>who::text or path!~ '^[a-f0-9-]+/[a-f0-9-]+\.(png|jpg|webp)$' then raise exception using errcode='42501',message='图片路径无效。';end if;
  select * into pic from foamlab_private.town_gallery where object_path=path;
  if found then
   if pic.hidden then raise exception '这件作品已删除，请重新上传。';end if;
   return jsonb_build_object('id',pic.id);
  end if;
  if not exists(select 1 from storage.objects where bucket_id='foamlab-town-gallery' and name=path and metadata->>'mimetype' in ('image/png','image/jpeg','image/webp') and (metadata->>'size')::bigint between 1 and 6291456) then raise exception '请先上传有效图片。';end if;
  if (select count(*) from foamlab_private.town_gallery where owner_id=who and created_at>now()-interval '1 day')>=20 then raise exception '每天最多发布 20 张计算图片。';end if;
  title_text:=foamlab_private.town_text(payload->>'title',100);body:=btrim(coalesce(payload->>'description',''));
  if char_length(body)>500 then raise exception '计算说明最多 500 字。';end if;
  card:=foamlab_private.town_card(who);
  insert into foamlab_private.town_gallery(owner_id,object_path,title,description,author_name,author_level,province)
   values(who,path,title_text,body,card->>'name',(card->>'level')::integer,card->>'province') returning * into pic;
  return jsonb_build_object('id',pic.id);
 elsif operation in ('like','delete') then
  select * into pic from foamlab_private.town_gallery where id=(payload->>'id')::uuid and not hidden for update;
  if pic.id is null then raise exception '作品不存在或已删除。';end if;
  if operation='like' then
   liked:=coalesce((payload->>'liked')::boolean,true);
   if liked then insert into foamlab_private.town_gallery_likes(image_id,user_id) values(pic.id,who) on conflict do nothing;
   else delete from foamlab_private.town_gallery_likes where image_id=pic.id and user_id=who;end if;
   return jsonb_build_object('id',pic.id,'liked',liked,'likes',(select count(*) from foamlab_private.town_gallery_likes where image_id=pic.id));
  end if;
  if pic.owner_id<>who and not mod then raise exception using errcode='42501',message='只有作者或管理员可以删除作品。';end if;
  update foamlab_private.town_gallery set hidden=true where id=pic.id;
  return jsonb_build_object('object_path',pic.object_path);
 else raise exception '未知操作。';end if;
 end $$;
create function public.foamlab_town_gallery(operation text default 'list',payload jsonb default '{}') returns jsonb language sql security invoker set search_path='' as $$ select foamlab_private.town_gallery_api(operation,payload) $$;
revoke all on function foamlab_private.town_gallery_api(text,jsonb),public.foamlab_town_gallery(text,jsonb) from public,anon,authenticated;
grant execute on function foamlab_private.town_gallery_api(text,jsonb),public.foamlab_town_gallery(text,jsonb) to anon,authenticated;
