-- Separate main-site collection inventory and equipment. XP remains shared.
create table if not exists foamlab_private.companion_items (
 id text primary key, category text not null, title text not null, description text not null,
 required_level integer not null check(required_level>0), requirement jsonb
);
create table if not exists foamlab_private.companion_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 look jsonb not null default '{"form":"cub","outfit":"scarf","action":"wave","decoration":"no-decor","ride":"walk","title":"","visible":true,"motion":true}'::jsonb
);
create table if not exists foamlab_private.companion_inventory (
 user_id uuid references auth.users(id) on delete cascade,
 item_id text references foamlab_private.companion_items(id),
 obtained_at timestamptz not null default now(), primary key(user_id,item_id)
);
alter table foamlab_private.companion_items enable row level security;
alter table foamlab_private.companion_profiles enable row level security;
alter table foamlab_private.companion_inventory enable row level security;
revoke all on foamlab_private.companion_items,foamlab_private.companion_profiles,foamlab_private.companion_inventory from public,anon,authenticated;

create or replace function foamlab_private.companion_api(operation text,payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); base jsonb; look jsonb; counts jsonb; i foamlab_private.companion_items; unlocked text[]; k text;
begin
 if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) then
  raise exception using errcode='42501',message='请先使用 GitHub 登录。';
 end if;
 if operation is null or operation not in ('state','checkin','settings','equip') then raise exception '未知操作。';end if;
 base:=foamlab_private.pet_api(case when operation='checkin' then 'checkin' else 'state' end,'{}');
 insert into foamlab_private.companion_profiles(user_id) values(who) on conflict do nothing;
 select c.look into look from foamlab_private.companion_profiles c where user_id=who for update;
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
  look:=look||jsonb_build_object(i.category,i.id);
 elsif operation='settings' then
  if payload ? 'name' then
   if jsonb_typeof(payload->'name')<>'string' or length(trim(payload->>'name')) not between 1 and 20 then raise exception '名字请输入 1–20 个字。';end if;
   look:=look||jsonb_build_object('name',trim(payload->>'name'));
  end if;
  foreach k in array array['motion','visible'] loop
   if payload ? k then
    if jsonb_typeof(payload->k)<>'boolean' then raise exception '显示设置无效。';end if;
    look:=look||jsonb_build_object(k,payload->k);
   end if;
  end loop;
 end if;
 update foamlab_private.companion_profiles c set look=companion_api.look where user_id=who;
 return base||jsonb_build_object('pet',(base->'pet')||look,'level_factor',30,
 'items',(select jsonb_agg(to_jsonb(c)||jsonb_build_object('unlocked',c.id=any(unlocked),'progress',case when c.requirement is not null then coalesce((counts->>(c.requirement->>'type'))::integer,0) else null end) order by c.category,c.required_level,c.id) from foamlab_private.companion_items c));
end $$;
revoke all on function foamlab_private.companion_api(text,jsonb) from public,anon,authenticated;
grant execute on function foamlab_private.companion_api(text,jsonb) to authenticated;
create or replace function public.foamlab_companion(operation text default 'state',payload jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$select foamlab_private.companion_api(operation,payload)$$;
revoke all on function public.foamlab_companion(text,jsonb) from public,anon;
grant execute on function public.foamlab_companion(text,jsonb) to authenticated;

insert into foamlab_private.companion_items(id,category,title,description,required_level,requirement) values
('cub','form','团子鲨鱼','圆脸、短爪，抱着最喜欢的竹子。',1,null),
('explorer','form','探索鲨鱼','背上小挎包，脚步更轻快。',4,null),
('master','form','学者鲨鱼','身形长大，眉间多了一撮浅色绒毛。',8,null),
('engineer','form','工程师鲨鱼','戴好安全帽，穿上蓝色工装。',12,null),
('astronaut','form','航天员鲨鱼','穿上航天服，向更远的地方出发。',18,null),
('none','outfit','原装毛绒','黑白毛色，轻装出发。',1,null),
('scarf','outfit','竹青围巾','一条柔软的小围巾。',2,null),
('goggles','outfit','实验护目镜','透过镜片观察小小流场。',3,null),
('backpack','outfit','探索背包','带上竹子和笔记本。',5,null),
('coat','outfit','实验室白大褂','口袋里放着一支笔。',7,null),
('cap','outfit','毕业帽','给坚持学习的自己一个纪念。',10,null),
('strawhat','outfit','田园草帽','宽宽的帽檐挡住午后阳光。',2,null),
('flower','outfit','小花发饰','耳边别一朵粉色小花。',3,null),
('raincoat','outfit','鹅黄雨衣','准备迎接一场小雨。',4,null),
('redscarf','outfit','枫叶围巾','暖红色围巾，适合秋天。',6,null),
('headphones','outfit','音乐耳机','跟着自己的节拍摇摆。',7,null),
('wizard','outfit','星星巫师帽','尖帽上缀着一颗小星星。',12,null),
('spacesuit','outfit','太空套装','透明面罩和银灰色外套。',15,null),
('wave','action','挥挥爪','抬起爪子，向你打个招呼。',1,null),
('sleep','action','打个盹','闭上眼睛，慢慢呼吸。',1,null),
('jump','action','开心跳跳','蹲一下，跳起来，轻轻落地。',3,null),
('roll','action','团子翻滚','先缩成一团，再滚一圈。',1,null),
('dance','action','踢踏舞','左右踢脚，跟着节奏摆手。',1,null),
('crawl','action','慢慢爬','交替迈动四只爪子。',1,null),
('sing','action','唱首小曲','抱着话筒哼一段旋律。',1,null),
('stretch','action','伸懒腰','举起双爪，舒展身体。',1,null),
('munch','action','吃竹子','抱起竹叶，小口嚼一嚼。',2,null),
('sway','action','摇摆舞','举起双爪，向左向右摇摆。',2,null),
('cheer','action','举爪欢呼','跳起来，为你加油。',4,null),
('spin','action','转圈舞','张开双臂，转两个轻快的圈。',5,null),
('read','action','翻翻书','捧起小书，低头读一会儿。',3,null),
('water','action','给花浇水','拿起水壶，洒出小水滴。',4,null),
('fish','action','池边钓鱼','握住鱼竿，看看浮漂的动静。',6,null),
('meditate','action','安静冥想','盘起腿，放慢呼吸。',8,null),
('experiment','action','小小实验','举起烧瓶，观察上升的小气泡。',12,null),
('no-decor','decoration','清爽背景','只留下鲨鱼和小小的影子。',1,null),
('meadow','decoration','花间草地','脚边长出两朵小花。',2,null),
('bamboo-grove','decoration','迷你竹林','把两株竹子带在身边。',3,null),
('pond','decoration','荷叶池塘','清浅的池水和一片荷叶。',6,null),
('blossom','decoration','樱花小景','一枝粉色花朵，落下几片花瓣。',9,null),
('lantern','decoration','暖灯庭院','一盏小灯照着脚边草地。',12,null),
('observatory','decoration','星空观测台','支起望远镜，看看星星。',16,null),
('sailor','form','水手鲨鱼','海魂衫、水手帽，还有肩上的小海鸥。',22,null),
('pilot','form','飞行员鲨鱼','戴上飞行帽和风镜，围巾随风飘动。',26,null),
('polar','form','极地科考鲨鱼','穿好厚羽绒服，帽檐缀着小小的霜花。',30,null),
('beanie','outfit','毛线帽','帽顶有一颗软软的绒球。',9,null),
('overalls','outfit','背带裤','胸前口袋插着小扳手。',11,null),
('bowtie','outfit','小领结','合影时系上红色领结。',13,null),
('sunglasses','outfit','圆框墨镜','准备晒一会儿太阳。',16,null),
('typing','action','敲键盘','双爪在小键盘上轻快敲动。',5,null),
('kite','action','放风筝','牵着风筝，看它随着气流摆动。',7,null),
('bubbles','action','吹小鲨','小鲨慢慢升起，在空中散开。',9,null),
('photo','action','拍张照','举起相机，留下这一刻。',10,null),
('taichi','action','打太极','慢慢推手，脚下画出一个圆。',14,null),
('streamline','action','画流线','用爪子画出几条彩色流线。',16,null),
('walk','ride','走路','迈着轻快的小步。',1,null),
('jog','ride','小跑','耳朵一颠一颠地向前跑。',3,null),
('skateboard','ride','滑板','脚下的滑板带起几道风线。',8,null),
('bicycle','ride','自行车','车筐里放着一根竹子。',12,null),
('balloon','ride','气球飘行','抓着三只气球慢慢飘。',20,null),
('study-first-lesson','badge','初见流动','完成 1 节课程',1,'{"type": "lessons", "count": 1}'::jsonb),
('study-ten-lessons','badge','求知之路','完成 10 节课程',1,'{"type": "lessons", "count": 10}'::jsonb),
('study-thirty-lessons','badge','学海拾光','完成 30 节课程',1,'{"type": "lessons", "count": 30}'::jsonb),
('study-seven-checkins','badge','日日精进','累计签到 7 天',1,'{"type": "checkins", "count": 7}'::jsonb),
('study-first-question','badge','善问者','提出第一个问题',1,'{"type": "questions", "count": 1}'::jsonb),
('study-five-replies','badge','答疑伙伴','发布 5 条有效回复',1,'{"type": "replies", "count": 5}'::jsonb),
('study-first-article','badge','笔耕者','发表第一篇文章',1,'{"type": "articles", "count": 1}'::jsonb),
('study-scholar','title','勤学者','完成 10 节课程',1,'{"type": "lessons", "count": 10}'::jsonb),
('scientist','form','科学家鲨鱼','戴上圆框眼镜，穿好白色实验服，探索未知。',14,null)
on conflict(id) do update set category=excluded.category,title=excluded.title,description=excluded.description,required_level=excluded.required_level,requirement=excluded.requirement;
