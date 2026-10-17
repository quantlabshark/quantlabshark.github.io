alter table foamlab_private.town_story_catalog
 add column kind text not null default 'side' check(kind in ('main','side')),
 add column npc text not null default '',
 add column trigger_kind text not null default 'story' check(trigger_kind in ('story','inspect','talk')),
 add column bamboo integer not null default 0 check(bamboo>=0),
 add column xp integer not null default 0 check(xp>=0);
alter table foamlab_private.town_story_progress
 add column accepted text[] not null default '{}',
 add column completed text[] not null default '{}',
 add column arrived jsonb not null default '{}',
 add column discovered text[] not null default '{}';
create table foamlab_private.town_story_achievements(
 id text primary key, needs text[] not null, visits text[] not null,
 bamboo integer not null check(bamboo>=0), xp integer not null check(xp>=0));
create table foamlab_private.town_story_awards(
 user_id uuid not null references auth.users(id) on delete cascade,
 id text not null, kind text not null check(kind in ('quest','achievement')),
 bamboo integer not null check(bamboo>=0), xp integer not null check(xp>=0),
 created_at timestamptz not null default now(), primary key(user_id,id));
alter table foamlab_private.town_story_achievements enable row level security;
alter table foamlab_private.town_story_awards enable row level security;
revoke all on foamlab_private.town_story_achievements,foamlab_private.town_story_awards from public,anon,authenticated;
update foamlab_private.town_story_catalog set kind='main',npc='heng',trigger_kind='story',bamboo=8,xp=15 where id='first-log';
update foamlab_private.town_story_catalog set kind='main',npc='muxi',trigger_kind='story',bamboo=8,xp=15 where id='canal';
update foamlab_private.town_story_catalog set kind='main',npc='lan',trigger_kind='story',bamboo=8,xp=15 where id='wind';
update foamlab_private.town_story_catalog set kind='main',npc='cheng',trigger_kind='story',bamboo=8,xp=15 where id='sluice';
update foamlab_private.town_story_catalog set kind='main',npc='yan',trigger_kind='story',bamboo=8,xp=15 where id='heat-house';
update foamlab_private.town_story_catalog set kind='main',npc='tie',trigger_kind='story',bamboo=8,xp=15 where id='dimension-fair';
update foamlab_private.town_story_catalog set kind='main',npc='yan',trigger_kind='story',bamboo=8,xp=15 where id='star-field';
update foamlab_private.town_story_catalog set kind='main',npc='heng',trigger_kind='story',bamboo=8,xp=15 where id='opening';
update foamlab_private.town_story_catalog set kind='side',npc='heng',trigger_kind='inspect',bamboo=4,xp=8 where id='mesh-note';
update foamlab_private.town_story_catalog set kind='side',npc='muxi',trigger_kind='talk',bamboo=4,xp=8 where id='time-note';
update foamlab_private.town_story_catalog set kind='side',npc='tie',trigger_kind='inspect',bamboo=4,xp=8 where id='pressure-note';
update foamlab_private.town_story_catalog set kind='side',npc='lan',trigger_kind='talk',bamboo=4,xp=8 where id='shock-note';
update foamlab_private.town_story_catalog set kind='side',npc='cheng',trigger_kind='inspect',bamboo=4,xp=8 where id='filter-note';
update foamlab_private.town_story_catalog set kind='side',npc='muxi',trigger_kind='inspect',bamboo=4,xp=8 where id='bubble-note';
update foamlab_private.town_story_catalog set kind='side',npc='yan',trigger_kind='talk',bamboo=4,xp=8 where id='diffusion-note';
update foamlab_private.town_story_catalog set kind='side',npc='tie',trigger_kind='inspect',bamboo=4,xp=8 where id='visual-note';
update foamlab_private.town_story_catalog set kind='side',npc='tie',trigger_kind='talk',bamboo=4,xp=8 where id='fan-note';
update foamlab_private.town_story_catalog set kind='side',npc='lan',trigger_kind='inspect',bamboo=4,xp=8 where id='windmill-note';
update foamlab_private.town_story_catalog set kind='side',npc='heng',trigger_kind='story',bamboo=4,xp=8 where id='airfoil-note';
update foamlab_private.town_story_catalog set kind='side',npc='cheng',trigger_kind='inspect',bamboo=4,xp=8 where id='ship-note';
insert into foamlab_private.town_story_achievements values('begin',array['first-log']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('water',array['canal','sluice']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('boundary',array['wind','pressure-note']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('dimension',array['dimension-fair']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('thermal',array['heat-house','diffusion-note']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('artist',array['star-field','visual-note']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('network',array['opening']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('complete',array['first-log','canal','wind','sluice','heat-house','dimension-fair','star-field','opening','mesh-note','time-note','pressure-note','shock-note','filter-note','bubble-note','diffusion-note','visual-note','fan-note','windmill-note','airfoil-note','ship-note']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('four-stations',array[]::text[],array['forest','valley','wetland','summit']::text[],5,10);
insert into foamlab_private.town_story_achievements values('machines',array['fan-note','windmill-note']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('water-route',array['canal','filter-note','ship-note']::text[],array[]::text[],5,10);
insert into foamlab_private.town_story_achievements values('config-reader',array['first-log','wind','pressure-note']::text[],array[]::text[],5,10);
-- Called only from the account-checked, row-locked story API. The ledger key makes retries safe.
create function foamlab_private.town_story_reward(who uuid,award_id text,award_kind text,bamboo_amount integer,xp_amount integer)
returns boolean language plpgsql security definer set search_path='' as $$
declare inserted integer;
begin
 insert into foamlab_private.town_story_awards(user_id,id,kind,bamboo,xp)
 values(who,award_id,award_kind,bamboo_amount,xp_amount) on conflict do nothing;
 get diagnostics inserted=row_count;
 if inserted=0 then return false; end if;
 insert into foamlab_private.town_wallet(user_id,balance,earned) values(who,bamboo_amount,bamboo_amount)
 on conflict(user_id) do update set balance=foamlab_private.town_wallet.balance+excluded.balance,
 earned=foamlab_private.town_wallet.earned+excluded.earned,updated_at=now();
 perform foamlab_private.pet_award(who,'training','story:'||award_id,xp_amount,0);
 return true;
end $$;
revoke all on function foamlab_private.town_story_reward(uuid,text,text,integer,integer) from public,anon,authenticated;
create or replace function foamlab_private.town_story_api(operation text,payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); saved foamlab_private.town_story_progress%rowtype;
 task foamlab_private.town_story_catalog%rowtype;
 task_id text:=payload->>'quest'; scene_id text:=payload->>'scene';
 current_step integer; requested_step integer; ok boolean:=true; duplicate boolean:=false;
 achievement foamlab_private.town_story_achievements%rowtype; earned_now jsonb:='[]'; award_list jsonb;
begin
 if who is null or not foamlab_private.has_github_identity() or not exists(select 1 from auth.users where id=who) then
  raise exception using errcode='42501',message='请先使用 GitHub 登录。'; end if;
 if foamlab_private.has_role(array['blocked']) or not foamlab_private.town_enabled() then
  raise exception using errcode='42501',message='小镇暂时无法使用。'; end if;
 if not exists(select 1 from public.foamlab_town_residents where user_id=who) then
  raise exception using errcode='42501',message='先在小镇入住，再保存观测任务进度。'; end if;
 if operation is null or operation not in ('state','visit','discover','accept','arrive','answer','report') then
  raise exception using errcode='22023',message='未知的观测任务操作。'; end if;
 insert into foamlab_private.town_story_progress(user_id) values(who) on conflict do nothing;
 select * into saved from foamlab_private.town_story_progress where user_id=who for update;
 if operation='visit' then
  if scene_id is null or scene_id not in ('village','forest','valley','wetland','summit') then
   raise exception using errcode='22023',message='没有找到这处观测站。'; end if;
  if not (scene_id=any(saved.visited)) then saved.visited:=array_append(saved.visited,scene_id); end if;
 elsif operation in ('discover','accept','arrive','answer','report') then
  select * into task from foamlab_private.town_story_catalog where id=task_id;
  if not found then raise exception using errcode='22023',message='没有找到这项任务。'; end if;
  if not (task.scene=any(saved.visited)) then raise exception using errcode='22023',message='先到任务所在的观测站。'; end if;
  if exists(select 1 from jsonb_array_elements_text(task.needs) as p(id) where not (p.id=any(saved.completed))) then
   raise exception using errcode='22023',message='先完成前面的故事并向居民汇报。'; end if;
  current_step:=coalesce((saved.progress->>task_id)::integer,0);
  if operation='discover' then
   if task.kind<>'side' or payload->>'trigger' is distinct from task.trigger_kind
    or (task.trigger_kind='talk' and payload->>'npc' is distinct from task.npc) then
    raise exception using errcode='22023',message='请查看这条委托的线索，或与相关居民交谈。'; end if;
   if not(task_id=any(saved.discovered)) then saved.discovered:=array_append(saved.discovered,task_id); end if;
  elsif operation='accept' then
   if task.kind='side' and task.trigger_kind<>'story' and not(task_id=any(saved.discovered)) then
    raise exception using errcode='22023',message='先在场景中找到这条支线的线索。'; end if;
   if payload->>'npc' is distinct from task.npc then raise exception using errcode='22023',message='请向委托人接取任务。'; end if;
   if task_id=any(saved.accepted) then duplicate:=true;
   else
    if task.kind='main' and exists(select 1 from foamlab_private.town_story_catalog c
     where c.kind='main' and c.id=any(saved.accepted) and not(c.id=any(saved.completed))) then
     raise exception using errcode='22023',message='一次只能接取一条主线。完成当前主线并汇报后，再接下一条。'; end if;
    saved.accepted:=array_append(saved.accepted,task_id);
   end if;
  else
   if not(task_id=any(saved.accepted)) then raise exception using errcode='22023',message='先与居民交谈，接取这项委托。'; end if;
   if operation='report' then
    if task_id=any(saved.completed) then duplicate:=true;
    elsif current_step<>jsonb_array_length(task.answers) or coalesce((saved.arrived->>task_id)::integer,-1)<>current_step
     or payload->>'npc' is distinct from task.npc then
     raise exception using errcode='22023',message='完成调查步骤后，回到委托人身边汇报。';
    else
     saved.completed:=array_append(saved.completed,task_id);
     if foamlab_private.town_story_reward(who,'quest:'||task_id,'quest',task.bamboo,task.xp) then
      earned_now:=earned_now||jsonb_build_array('quest:'||task_id); end if;
    end if;
   else
    if payload->>'step' is null or payload->>'step' !~ '^[0-9]{1,2}$' then
     raise exception using errcode='22023',message='任务步骤不正确，请重新打开任务。'; end if;
    requested_step:=(payload->>'step')::integer;
    if operation='arrive' then
     if requested_step<>current_step or requested_step>jsonb_array_length(task.answers) then
      raise exception using errcode='22023',message='请前往当前步骤的目标位置。'; end if;
     if payload->>'station' is distinct from (case when current_step=jsonb_array_length(task.answers) then 'npc-'||task.npc else task.scene||'-step-'||current_step::text end) then
      raise exception using errcode='22023',message='这不是当前步骤的位置。'; end if;
     saved.arrived:=jsonb_set(saved.arrived,array[task_id],to_jsonb(current_step),true);
    elsif requested_step<current_step then duplicate:=true;
    elsif requested_step<>current_step or current_step>=jsonb_array_length(task.answers) then
     raise exception using errcode='22023',message='进度已变化，请重新打开当前步骤。';
    elsif coalesce((saved.arrived->>task_id)::integer,-1)<>current_step then
     raise exception using errcode='22023',message='先到地图上的任务地点完成这一步。';
    else
     ok:=coalesce(payload->'answer'=task.answers->current_step,false);
     if task.answers->>current_step='painted' then
      ok:=ok and coalesce(payload->>'strokes' ~ '^[0-9]{1,3}$',false);
      if ok then ok:=(payload->>'strokes')::integer>=3; end if;
     end if;
     if ok then saved.progress:=jsonb_set(saved.progress,array[task_id],to_jsonb(current_step+1),true); end if;
    end if;
   end if;
  end if;
 end if;
 if operation<>'state' then update foamlab_private.town_story_progress set progress=saved.progress,visited=saved.visited,
  accepted=saved.accepted,completed=saved.completed,arrived=saved.arrived,discovered=saved.discovered,updated_at=now() where user_id=who; end if;
 if operation in ('visit','report') then
  for achievement in select * from foamlab_private.town_story_achievements where needs<@saved.completed and visits<@saved.visited loop
   if foamlab_private.town_story_reward(who,'achievement:'||achievement.id,'achievement',achievement.bamboo,achievement.xp) then
    earned_now:=earned_now||jsonb_build_array('achievement:'||achievement.id); end if;
  end loop;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'kind',kind,'bamboo',bamboo,'xp',xp,'at',created_at) order by created_at,id),'[]')
 into award_list from foamlab_private.town_story_awards where user_id=who;
 return jsonb_build_object('version',2,'progress',saved.progress,'visited',saved.visited,'accepted_quests',saved.accepted,
  'completed',saved.completed,'arrived',saved.arrived,'discovered',saved.discovered,'awards',award_list,
  'earned_now',earned_now,'accepted',ok,'duplicate',duplicate);
end $$;
