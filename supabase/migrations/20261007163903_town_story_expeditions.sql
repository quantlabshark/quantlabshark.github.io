-- Additive story progress, separate from existing town inventory and daily tasks.
create table foamlab_private.town_story_catalog (
  id text primary key,
  scene text not null,
  needs jsonb not null,
  answers jsonb not null
);
create table foamlab_private.town_story_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  progress jsonb not null default '{}',
  visited text[] not null default '{}',
  updated_at timestamptz not null default now()
);
alter table foamlab_private.town_story_catalog enable row level security;
alter table foamlab_private.town_story_progress enable row level security;
revoke all on foamlab_private.town_story_catalog,foamlab_private.town_story_progress from public,anon,authenticated;

insert into foamlab_private.town_story_catalog(id,scene,needs,answers) values
('first-log','village','[]'::jsonb,'[1, 2, 0]'::jsonb),
('canal','forest','["first-log"]'::jsonb,'[1, 2, 1]'::jsonb),
('wind','valley','["canal"]'::jsonb,'[0, 1, 2]'::jsonb),
('sluice','wetland','["wind"]'::jsonb,'[1, 2, 0]'::jsonb),
('heat-house','summit','["sluice"]'::jsonb,'[0, 1, 2]'::jsonb),
('dimension-fair','valley','["heat-house"]'::jsonb,'[[2, 0, 3, 1], 2, 0]'::jsonb),
('star-field','summit','["dimension-fair"]'::jsonb,'["painted", 1, 2]'::jsonb),
('opening','village','["star-field"]'::jsonb,'[1, 0, 2]'::jsonb),
('mesh-note','forest','["first-log"]'::jsonb,'[0, 1, 2]'::jsonb),
('time-note','forest','["canal"]'::jsonb,'[1, 0, 2]'::jsonb),
('pressure-note','valley','["wind"]'::jsonb,'[1, 0, 2]'::jsonb),
('shock-note','valley','["dimension-fair"]'::jsonb,'[0, 1, 2]'::jsonb),
('filter-note','wetland','["sluice"]'::jsonb,'[1, 2, 0]'::jsonb),
('bubble-note','wetland','["sluice"]'::jsonb,'[1, 0, 2]'::jsonb),
('diffusion-note','summit','["heat-house"]'::jsonb,'[1, 0, 2]'::jsonb),
('visual-note','summit','["star-field"]'::jsonb,'[0, 1, 2]'::jsonb),
('fan-note','valley','["wind"]'::jsonb,'[1, 2, 0]'::jsonb),
('windmill-note','valley','["wind"]'::jsonb,'[2, 0, 1]'::jsonb),
('airfoil-note','summit','["wind"]'::jsonb,'[1, 0, 2]'::jsonb),
('ship-note','wetland','["sluice"]'::jsonb,'[0, 1, 2]'::jsonb);

create function foamlab_private.town_story_api(operation text, payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  who uuid := auth.uid();
  saved foamlab_private.town_story_progress%rowtype;
  task foamlab_private.town_story_catalog%rowtype;
  task_id text := payload->>'quest';
  scene_id text := payload->>'scene';
  current_step integer;
  requested_step integer;
  ok boolean := true;
  duplicate boolean := false;
begin
  if who is null or not foamlab_private.has_github_identity()
    or not exists(select 1 from auth.users where id=who) then
    raise exception using errcode='42501',message='请先使用 GitHub 登录。';
  end if;
  if foamlab_private.has_role(array['blocked']) or not foamlab_private.town_enabled() then
    raise exception using errcode='42501',message='小镇暂时无法使用。';
  end if;
  if not exists(select 1 from public.foamlab_town_residents where user_id=who) then
    raise exception using errcode='42501',message='先在小镇入住，再保存观测任务进度。';
  end if;
  if operation not in ('state','visit','answer') or operation is null then
    raise exception using errcode='22023',message='未知的观测任务操作。';
  end if;
  insert into foamlab_private.town_story_progress(user_id) values(who) on conflict do nothing;
  select * into saved from foamlab_private.town_story_progress where user_id=who for update;
  if operation='visit' then
    if scene_id is null or scene_id not in ('village','forest','valley','wetland','summit') then
      raise exception using errcode='22023',message='没有找到这处观测站。';
    end if;
    if not (scene_id=any(saved.visited)) then saved.visited:=array_append(saved.visited,scene_id); end if;
  elsif operation='answer' then
    select * into task from foamlab_private.town_story_catalog where id=task_id;
    if not found then raise exception using errcode='22023',message='没有找到这项任务。'; end if;
    if not (task.scene=any(saved.visited)) then
      raise exception using errcode='22023',message='先到任务所在的观测站与居民见面。';
    end if;
    if exists(select 1 from jsonb_array_elements_text(task.needs) as p(id)
      join foamlab_private.town_story_catalog c on c.id=p.id
      where coalesce((saved.progress->>c.id)::integer,0)<jsonb_array_length(c.answers)) then
      raise exception using errcode='22023',message='先完成前面的故事，再继续这项任务。';
    end if;
    if payload->>'step' is null or payload->>'step' !~ '^[0-9]{1,2}$' then
      raise exception using errcode='22023',message='任务步骤不正确，请重新打开任务。';
    end if;
    requested_step:=(payload->>'step')::integer;
    current_step:=coalesce((saved.progress->>task_id)::integer,0);
    if requested_step<current_step then duplicate:=true;
    elsif requested_step<>current_step or current_step>=jsonb_array_length(task.answers) then
      raise exception using errcode='22023',message='进度已变化，请重新打开当前步骤。';
    else
      ok:=coalesce(payload->'answer'=task.answers->current_step,false);
      if task.answers->>current_step='painted' then
        ok:=ok and coalesce(payload->>'strokes' ~ '^[0-9]{1,3}$',false);
        if ok then ok:=(payload->>'strokes')::integer>=3; end if;
      end if;
      if ok then saved.progress:=jsonb_set(saved.progress,array[task_id],to_jsonb(current_step+1),true); end if;
    end if;
  end if;
  if operation<>'state' then
    update foamlab_private.town_story_progress set progress=saved.progress,visited=saved.visited,updated_at=now() where user_id=who;
  end if;
  return jsonb_build_object('version',1,'progress',saved.progress,'visited',saved.visited,'accepted',ok,'duplicate',duplicate);
end $$;
create function public.foamlab_town_story(operation text default 'state',payload jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$
  select foamlab_private.town_story_api(operation,payload)
$$;
revoke all on function foamlab_private.town_story_api(text,jsonb),public.foamlab_town_story(text,jsonb) from public,anon,authenticated;
grant execute on function foamlab_private.town_story_api(text,jsonb),public.foamlab_town_story(text,jsonb) to authenticated;
