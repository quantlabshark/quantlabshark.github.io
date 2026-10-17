-- Rewards are claimed explicitly from the journal. Existing awards and progress are retained.
create or replace function foamlab_private.town_story_api(operation text,payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); saved foamlab_private.town_story_progress%rowtype;
 task foamlab_private.town_story_catalog%rowtype;
 task_id text:=payload->>'quest'; scene_id text:=payload->>'scene'; visit_province text;
 conversation jsonb;
 current_step integer; requested_step integer; ok boolean:=true; duplicate boolean:=false;
 achievement foamlab_private.town_story_achievements%rowtype; earned_now jsonb:='[]'; award_list jsonb;
begin
 if who is null or not foamlab_private.has_github_identity() or not exists(select 1 from auth.users where id=who) then
  raise exception using errcode='42501',message='请先使用 GitHub 登录。'; end if;
 if foamlab_private.has_role(array['blocked']) or not foamlab_private.town_enabled() then
  raise exception using errcode='42501',message='小镇暂时无法使用。'; end if;
 if not exists(select 1 from public.foamlab_town_residents where user_id=who) then
  raise exception using errcode='42501',message='先在小镇入住，再保存观测任务进度。'; end if;
 select province into visit_province from public.foamlab_town_residents where user_id=who;
 if operation<>'state' and payload->>'province' is distinct from visit_province then
  raise exception using errcode='42501',message='请回到自己的小镇继续任务，串门时不会推进剧情。'; end if;
 if operation is null or operation not in ('state','visit','discover','accept','consult','arrive','answer','report','claim') then
  raise exception using errcode='22023',message='未知的观测任务操作。'; end if;
 insert into foamlab_private.town_story_progress(user_id) values(who) on conflict do nothing;
 select * into saved from foamlab_private.town_story_progress where user_id=who for update;
 if operation='visit' then
  if scene_id is null or scene_id not in ('village','forest','valley','wetland','summit') then
   raise exception using errcode='22023',message='没有找到这处观测站。'; end if;
  if not (scene_id=any(saved.visited)) then saved.visited:=array_append(saved.visited,scene_id); end if;
 elsif operation='claim' then
  if payload->>'reward' like 'quest:%' then
   task_id:=substr(payload->>'reward',7);
   select * into task from foamlab_private.town_story_catalog where id=task_id;
   if not found or not(task_id=any(saved.completed)) then
    raise exception using errcode='22023',message='先完成调查并向委托人汇报，再来领取奖励。'; end if;
   if foamlab_private.town_story_reward(who,'quest:'||task_id,'quest',task.bamboo,task.xp) then
    earned_now:=jsonb_build_array('quest:'||task_id); else duplicate:=true; end if;
  elsif payload->>'reward' like 'achievement:%' then
   select * into achievement from foamlab_private.town_story_achievements where id=substr(payload->>'reward',13);
   if not found or not(achievement.needs<@saved.completed and achievement.visits<@saved.visited) then
    raise exception using errcode='22023',message='完成对应的观测任务或到访记录后，再来领取成就奖励。'; end if;
   if foamlab_private.town_story_reward(who,'achievement:'||achievement.id,'achievement',achievement.bamboo,achievement.xp) then
    earned_now:=jsonb_build_array('achievement:'||achievement.id); else duplicate:=true; end if;
  else raise exception using errcode='22023',message='没有找到这份奖励。'; end if;
 elsif operation in ('discover','accept','consult','arrive','answer','report') then
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
   if operation='consult' then
    select value into conversation from jsonb_array_elements(task.consultations) where (value->>'step')::int=current_step;
    if conversation is null or payload->>'npc' is distinct from conversation->>'npc' or payload->>'scene' is distinct from conversation->>'scene'
     or not((conversation->>'scene')=any(saved.visited)) then
     raise exception using errcode='22023',message='请在当前调查阶段拜访对应的居民。'; end if;
    saved.consulted:=jsonb_set(saved.consulted,array[task_id],to_jsonb(current_step),true);
   elsif operation='report' then
    if task_id=any(saved.completed) then duplicate:=true;
    elsif current_step<>jsonb_array_length(task.answers) or coalesce((saved.arrived->>task_id)::integer,-1)<>current_step
     or payload->>'npc' is distinct from task.npc then
     raise exception using errcode='22023',message='完成调查步骤后，回到委托人身边汇报。';
    else
     saved.completed:=array_append(saved.completed,task_id);

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
     if exists(select 1 from jsonb_array_elements(task.consultations) c where (c->>'step')::int=current_step)
      and coalesce((saved.consulted->>task_id)::int,-1)<>current_step then
      raise exception using errcode='22023',message='先拜访协作居民，取得这一步需要的观测线索。'; end if;
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
  accepted=saved.accepted,completed=saved.completed,arrived=saved.arrived,discovered=saved.discovered,consulted=saved.consulted,updated_at=now() where user_id=who; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'kind',kind,'bamboo',bamboo,'xp',xp,'at',created_at) order by created_at,id),'[]')
 into award_list from foamlab_private.town_story_awards where user_id=who;
 return jsonb_build_object('version',4,'progress',saved.progress,'visited',saved.visited,'accepted_quests',saved.accepted,'consulted',saved.consulted,
  'completed',saved.completed,'arrived',saved.arrived,'discovered',saved.discovered,'awards',award_list,
  'earned_now',earned_now,'accepted',ok,'duplicate',duplicate);
end $$;
