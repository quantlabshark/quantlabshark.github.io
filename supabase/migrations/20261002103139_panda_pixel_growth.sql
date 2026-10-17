-- Add cosmetic growth options; existing pets, XP and preferences are retained.
alter table public.foamlab_pets add column decoration text not null default 'no-decor';
alter table foamlab_private.pet_items drop constraint pet_items_category_check;
alter table foamlab_private.pet_items add constraint pet_items_category_check check(category in ('form','outfit','action','decoration'));
insert into foamlab_private.pet_items(id,category,title,description,required_level) values
 ('cub','form','团子鲨鱼','圆脸、短爪，抱着最喜欢的竹子。',1),
 ('explorer','form','探索鲨鱼','背上小挎包，脚步更轻快。',4),
 ('master','form','学者鲨鱼','身形长大，眉间多了一撮浅色绒毛。',8),
 ('engineer','form','工程师鲨鱼','戴好安全帽，穿上蓝色工装。',12),
 ('astronaut','form','航天员鲨鱼','穿上航天服，向更远的地方出发。',18),
 ('none','outfit','原装毛绒','黑白毛色，轻装出发。',1),
 ('scarf','outfit','竹青围巾','一条柔软的小围巾。',2),
 ('goggles','outfit','实验护目镜','透过镜片观察小小流场。',3),
 ('backpack','outfit','探索背包','带上竹子和笔记本。',5),
 ('coat','outfit','实验室白大褂','口袋里放着一支笔。',7),
 ('cap','outfit','毕业帽','给坚持学习的自己一个纪念。',10),
 ('strawhat','outfit','田园草帽','宽宽的帽檐挡住午后阳光。',2),
 ('flower','outfit','小花发饰','耳边别一朵粉色小花。',3),
 ('raincoat','outfit','鹅黄雨衣','准备迎接一场小雨。',4),
 ('redscarf','outfit','枫叶围巾','暖红色围巾，适合秋天。',6),
 ('headphones','outfit','音乐耳机','跟着自己的节拍摇摆。',7),
 ('wizard','outfit','星星巫师帽','尖帽上缀着一颗小星星。',12),
 ('spacesuit','outfit','太空套装','透明面罩和银灰色外套。',15),
 ('wave','action','挥挥爪','抬起爪子，向你打个招呼。',1),
 ('sleep','action','打个盹','闭上眼睛，慢慢呼吸。',1),
 ('jump','action','开心跳跳','蹲一下，跳起来，轻轻落地。',3),
 ('roll','action','团子翻滚','先缩成一团，再滚一圈。',1),
 ('dance','action','踢踏舞','左右踢脚，跟着节奏摆手。',1),
 ('crawl','action','慢慢爬','交替迈动四只爪子。',1),
 ('sing','action','唱首小曲','抱着话筒哼一段旋律。',1),
 ('stretch','action','伸懒腰','举起双爪，舒展身体。',1),
 ('munch','action','吃竹子','抱起竹叶，小口嚼一嚼。',2),
 ('sway','action','摇摆舞','举起双爪，向左向右摇摆。',2),
 ('cheer','action','举爪欢呼','跳起来，为你加油。',4),
 ('spin','action','转圈舞','张开双臂，转两个轻快的圈。',5),
 ('read','action','翻翻书','捧起小书，低头读一会儿。',3),
 ('water','action','给花浇水','拿起水壶，洒出小水滴。',4),
 ('fish','action','池边钓鱼','握住鱼竿，看看浮漂的动静。',6),
 ('meditate','action','安静冥想','盘起腿，放慢呼吸。',8),
 ('experiment','action','小小实验','举起烧瓶，观察上升的小气泡。',12),
 ('no-decor','decoration','清爽背景','只留下鲨鱼和小小的影子。',1),
 ('meadow','decoration','花间草地','脚边长出两朵小花。',2),
 ('bamboo-grove','decoration','迷你竹林','把两株竹子带在身边。',3),
 ('pond','decoration','荷叶池塘','清浅的池水和一片荷叶。',6),
 ('blossom','decoration','樱花小景','一枝粉色花朵，落下几片花瓣。',9),
 ('lantern','decoration','暖灯庭院','一盏小灯照着脚边草地。',12),
 ('observatory','decoration','星空观测台','支起望远镜，看看星星。',16)
on conflict(id) do update set title=excluded.title,description=excluded.description,required_level=excluded.required_level;

create or replace function foamlab_private.pet_api(operation text, payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); p public.foamlab_pets; lvl integer; item foamlab_private.pet_items; awarded integer:=0; lesson uuid; result jsonb;
begin
 if who is null or not foamlab_private.has_github_identity() or not exists(select 1 from auth.users where id=who) then raise exception using errcode='42501',message='请先使用 GitHub 登录。'; end if;
 if foamlab_private.has_role(array['blocked']) then raise exception using errcode='42501',message='此账号的成长功能暂时停用。'; end if;
 if operation not in ('state','checkin','equip','settings') or operation is null then raise exception '未知操作。'; end if;
 insert into public.foamlab_pets(user_id) values(who) on conflict do nothing;
 select * into p from public.foamlab_pets where user_id=who for update;
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
  if not found or item.required_level>lvl then raise exception '这个收藏尚未解锁。'; end if;
  if item.category='form' then update public.foamlab_pets set form=item.id where user_id=who;
  elsif item.category='outfit' then update public.foamlab_pets set outfit=item.id where user_id=who;
  elsif item.category='decoration' then update public.foamlab_pets set decoration=item.id where user_id=who;
  elsif item.category='action' then update public.foamlab_pets set action=item.id where user_id=who; end if;
 elsif operation='settings' then
  if payload ? 'name' and (jsonb_typeof(payload->'name')<>'string' or char_length(trim(payload->>'name')) not between 1 and 20) then raise exception '名字请输入 1–20 个字。'; end if;
  if payload ? 'visible' and jsonb_typeof(payload->'visible')<>'boolean' then raise exception '显示设置无效。'; end if;
  if payload ? 'motion' and jsonb_typeof(payload->'motion')<>'boolean' then raise exception '动画设置无效。'; end if;
  update public.foamlab_pets set name=case when payload ? 'name' then trim(payload->>'name') else name end,
  visible=coalesce((payload->>'visible')::boolean,visible),motion=coalesce((payload->>'motion')::boolean,motion) where user_id=who;
 end if;
 select * into p from public.foamlab_pets where user_id=who;
 lvl:=foamlab_private.pet_level(p.xp);
 -- Moderated/deleted contributions can lower XP; equipment follows the current level.
 if not exists(select 1 from foamlab_private.pet_items where id=p.form and category='form' and required_level<=lvl) then p.form:='cub'; end if;
 if not exists(select 1 from foamlab_private.pet_items where id=p.outfit and category='outfit' and required_level<=lvl) then p.outfit:='none'; end if;
 if not exists(select 1 from foamlab_private.pet_items where id=p.action and category='action' and required_level<=lvl) then p.action:='wave'; end if;
 if not exists(select 1 from foamlab_private.pet_items where id=p.decoration and category='decoration' and required_level<=lvl) then p.decoration:='no-decor'; end if;
 update public.foamlab_pets set form=p.form,outfit=p.outfit,action=p.action,decoration=p.decoration where user_id=who;
 result:=jsonb_build_object('pet',to_jsonb(p),'level',lvl,'level_start',25*lvl*(lvl-1),'next_level_xp',25*lvl*(lvl+1),'awarded',awarded,
 'checked_in',exists(select 1 from public.foamlab_pet_events where user_id=who and event_key='checkin:'||(now() at time zone 'Asia/Shanghai')::date),
 'items',(select jsonb_agg(to_jsonb(i)||jsonb_build_object('unlocked',required_level<=lvl) order by category,required_level,id) from foamlab_private.pet_items i),
 'events',(select coalesce(jsonb_agg(to_jsonb(e)),'[]'::jsonb) from (select kind,points,created_at from public.foamlab_pet_events where user_id=who order by id desc limit 8) e));
 return result;
end $$;
revoke all on function foamlab_private.pet_api(text,jsonb) from public,anon;
grant execute on function foamlab_private.pet_api(text,jsonb) to authenticated;
