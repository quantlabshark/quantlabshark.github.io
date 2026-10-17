-- Panda progression: points are written only by trusted triggers and the check-in RPC.
create table public.foamlab_pets (
 user_id uuid primary key references auth.users(id) on delete cascade,
 xp integer not null default 0 check(xp>=0),
 name text not null default '小鲨' check(char_length(name) between 1 and 20),
 form text not null default 'cub', outfit text not null default 'none', action text not null default 'wave',
 visible boolean not null default true, motion boolean not null default true,
 created_at timestamptz not null default now()
);
alter table public.foamlab_pets enable row level security;
create policy pet_owner_read on public.foamlab_pets for select to authenticated using(user_id=(select auth.uid()));
revoke all on public.foamlab_pets from anon,authenticated;
grant select on public.foamlab_pets to authenticated;

create table public.foamlab_pet_events (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 event_key text not null, kind text not null,
 points integer not null check(points>=0),
 source_id uuid, parent_id uuid, fingerprint text,
 earned_on date not null default (now() at time zone 'Asia/Shanghai')::date,
 created_at timestamptz not null default now(),
 unique(user_id,event_key)
);
create index pet_events_daily on public.foamlab_pet_events(user_id,earned_on,kind);
create index pet_events_source on public.foamlab_pet_events(source_id) where source_id is not null;
create index pet_events_parent on public.foamlab_pet_events(parent_id) where parent_id is not null;
create unique index pet_events_duplicate on public.foamlab_pet_events(user_id,earned_on,kind,fingerprint) where fingerprint is not null;
alter table public.foamlab_pet_events enable row level security;
create policy pet_events_owner_read on public.foamlab_pet_events for select to authenticated using(user_id=(select auth.uid()));
revoke all on public.foamlab_pet_events from anon,authenticated;
grant select on public.foamlab_pet_events to authenticated;

create table foamlab_private.pet_items (
 id text primary key, category text not null check(category in ('form','outfit','action')),
 title text not null, description text not null, required_level integer not null check(required_level>0)
);
alter table foamlab_private.pet_items enable row level security;
revoke all on foamlab_private.pet_items from public,anon,authenticated;
insert into foamlab_private.pet_items values
 ('cub','form','团子鲨鱼','圆滚滚的小伙伴',1),('explorer','form','探索鲨鱼','站起来，去看看新知识',4),('master','form','学者鲨鱼','眉毛弯弯，学识满满',8),
 ('none','outfit','原装毛绒','黑白配色，轻装出发',1),('scarf','outfit','竹青围巾','一条柔软的小围巾',2),('goggles','outfit','实验护目镜','准备观察流场',3),('backpack','outfit','探索背包','带上竹子去学习',5),('coat','outfit','实验室白大褂','口袋里放着一支笔',7),('cap','outfit','毕业帽','今天也学会了新东西',10),
 ('wave','action','挥挥爪','向你打个招呼',1),('sleep','action','打个盹','闭上眼睛休息一下',1),('jump','action','开心跳跳','轻轻跃起再落地',3),('roll','action','团子翻滚','滚一圈，重新坐好',6),('dance','action','竹叶舞','跟着节奏左右摇摆',9);

create function foamlab_private.pet_level(points integer) returns integer
language sql immutable set search_path='' as $$ select floor((1+sqrt(1+greatest(points,0)::numeric/6.25))/2)::integer $$;
revoke all on function foamlab_private.pet_level(integer) from public,anon,authenticated;

create function foamlab_private.pet_award(who uuid, category text, event text, amount integer, daily_limit integer, source uuid default null, parent uuid default null, fingerprint text default null) returns integer
language plpgsql security definer set search_path='' as $$
declare inserted integer;
begin
 if who is null or not exists(select 1 from auth.identities where user_id=who and provider='github')
 or exists(select 1 from public.foamlab_roles where user_id=who and role='blocked') then return 0; end if;
 insert into public.foamlab_pets(user_id) values(who) on conflict do nothing;
 perform 1 from public.foamlab_pets where user_id=who for update;
 if daily_limit>0 and (select count(*) from public.foamlab_pet_events where user_id=who and kind=category and earned_on=(now() at time zone 'Asia/Shanghai')::date)>=daily_limit then return 0; end if;
 insert into public.foamlab_pet_events(user_id,event_key,kind,points,source_id,parent_id,fingerprint)
 values(who,event,category,amount,source,parent,fingerprint) on conflict do nothing;
 get diagnostics inserted=row_count;
 if inserted=1 then update public.foamlab_pets set xp=xp+amount where user_id=who; return amount; end if;
 return 0;
end $$;
revoke all on function foamlab_private.pet_award(uuid,text,text,integer,integer,uuid,uuid,text) from public,anon,authenticated;

create function foamlab_private.pet_revoke(source uuid, include_children boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare account uuid; removed integer;
begin
 -- Lock accounts in a fixed order before changing the ledger or its total.
 for account in select distinct user_id from public.foamlab_pet_events where (source_id=source or (include_children and parent_id=source)) and points>0 order by user_id loop
  perform 1 from public.foamlab_pets where user_id=account for update;
  with changed as (update public.foamlab_pet_events set points=0 where user_id=account and (source_id=source or (include_children and parent_id=source)) and points>0 returning id)
  select count(*) into removed from changed;
  update public.foamlab_pets set xp=coalesce((select sum(points) from public.foamlab_pet_events where user_id=account),0) where user_id=account;
 end loop;
end $$;
revoke all on function foamlab_private.pet_revoke(uuid,boolean) from public,anon,authenticated;

create function foamlab_private.pet_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare parent_author uuid;
begin
 if tg_table_name='foamlab_learning_progress' then
  if new.completed and exists(select 1 from public.foamlab_content where id=new.content_id and kind='lesson' and status='published' and coalesce(metadata->>'admin_only','false')<>'true') then
   perform foamlab_private.pet_award(new.user_id,'course','course:'||new.content_id,25,0,new.content_id);
  end if;
 elsif tg_table_name='foamlab_threads' then
  if tg_op='DELETE' then perform foamlab_private.pet_revoke(old.id,true); return old;
  elsif new.status='hidden' then perform foamlab_private.pet_revoke(new.id,true);
  elsif tg_op='INSERT' then perform foamlab_private.pet_award(new.author_id,'topic','topic:'||new.id,15,3,new.id,null,md5(regexp_replace(lower(new.body),'\s','','g')));
  end if;
 elsif tg_table_name='foamlab_messages' then
  if tg_op='DELETE' then perform foamlab_private.pet_revoke(old.id); return old;
  elsif new.status='hidden' then perform foamlab_private.pet_revoke(new.id);
  elsif tg_op='INSERT' and char_length(regexp_replace(new.body,'\s','','g'))>=10 then
   if new.thread_id is not null then
    select author_id into parent_author from public.foamlab_threads where id=new.thread_id and status in ('open','resolved');
    if parent_author is not null and parent_author<>new.author_id then
     perform foamlab_private.pet_award(new.author_id,'reply','reply:'||new.id,5,6,new.id,new.thread_id,md5(regexp_replace(lower(new.body),'\s','','g')));
    end if;
   elsif exists(select 1 from public.foamlab_content where id=new.content_id and status='published' and comments_enabled and author_id is distinct from new.author_id) then
    perform foamlab_private.pet_award(new.author_id,'comment','comment:'||new.id,3,5,new.id,new.content_id,md5(regexp_replace(lower(new.body),'\s','','g')));
   end if;
  end if;
 elsif tg_table_name='foamlab_content' then
  if tg_op='DELETE' then perform foamlab_private.pet_revoke(old.id,true); return old;
  elsif new.status in ('trash','archived') then perform foamlab_private.pet_revoke(new.id,true);
  elsif new.kind in ('article','log') and new.status='published' and (tg_op='INSERT' or old.status<>'published') then
   perform foamlab_private.pet_award(new.author_id,'article','article:'||new.id,30,1,new.id);
  end if;
 end if;
 return new;
end $$;
revoke all on function foamlab_private.pet_activity() from public,anon,authenticated;
create trigger pet_course_award after insert or update on public.foamlab_learning_progress for each row execute function foamlab_private.pet_activity();
create trigger pet_topic_award after insert or update or delete on public.foamlab_threads for each row execute function foamlab_private.pet_activity();
create trigger pet_message_award after insert or update or delete on public.foamlab_messages for each row execute function foamlab_private.pet_activity();
create trigger pet_article_award after insert or update or delete on public.foamlab_content for each row execute function foamlab_private.pet_activity();

create function foamlab_private.pet_api(operation text, payload jsonb) returns jsonb
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
  else update public.foamlab_pets set action=item.id where user_id=who; end if;
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
 if not exists(select 1 from foamlab_private.pet_items where id=p.form and required_level<=lvl) then p.form:='cub'; end if;
 if not exists(select 1 from foamlab_private.pet_items where id=p.outfit and required_level<=lvl) then p.outfit:='none'; end if;
 if not exists(select 1 from foamlab_private.pet_items where id=p.action and required_level<=lvl) then p.action:='wave'; end if;
 update public.foamlab_pets set form=p.form,outfit=p.outfit,action=p.action where user_id=who;
 result:=jsonb_build_object('pet',to_jsonb(p),'level',lvl,'level_start',25*lvl*(lvl-1),'next_level_xp',25*lvl*(lvl+1),'awarded',awarded,
 'checked_in',exists(select 1 from public.foamlab_pet_events where user_id=who and event_key='checkin:'||(now() at time zone 'Asia/Shanghai')::date),
 'items',(select jsonb_agg(to_jsonb(i)||jsonb_build_object('unlocked',required_level<=lvl) order by category,required_level,id) from foamlab_private.pet_items i),
 'events',(select coalesce(jsonb_agg(to_jsonb(e)),'[]'::jsonb) from (select kind,points,created_at from public.foamlab_pet_events where user_id=who order by id desc limit 8) e));
 return result;
end $$;
revoke all on function foamlab_private.pet_api(text,jsonb) from public,anon;
grant execute on function foamlab_private.pet_api(text,jsonb) to authenticated;
create function public.foamlab_pet(operation text default 'state', payload jsonb default '{}'::jsonb) returns jsonb
language sql security invoker set search_path='' as $$ select foamlab_private.pet_api(operation,payload) $$;
revoke all on function public.foamlab_pet(text,jsonb) from public,anon;
grant execute on function public.foamlab_pet(text,jsonb) to authenticated;
