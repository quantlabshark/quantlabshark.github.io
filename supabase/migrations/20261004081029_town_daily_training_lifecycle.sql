-- Draws are previews; a run starts only after explicit confirmation.
-- All write operations retain the existing per-account wallet lock.
alter table foamlab_private.town_training_runs add column expired_at timestamptz;
alter table foamlab_private.town_training_runs add column is_replay boolean not null default false;
update foamlab_private.town_training_runs set expired_at=now()
-- Legacy step-zero rows were created by drawing, before the Start button was pressed.
where step<5 and (step=0 or (created_at at time zone 'Asia/Shanghai')::date<>(now() at time zone 'Asia/Shanghai')::date);
with ranked as (
 select id,row_number() over(partition by user_id order by updated_at desc,created_at desc,id desc) n
 from foamlab_private.town_training_runs where step<5 and expired_at is null
)
update foamlab_private.town_training_runs r set expired_at=now() from ranked q where r.id=q.id and q.n>1;
create unique index town_training_one_active on foamlab_private.town_training_runs(user_id) where step<5 and expired_at is null;
create index town_training_completed on foamlab_private.town_training_runs(user_id,case_id,finished_at desc) where step=5;
create table foamlab_private.town_training_draws (
 user_id uuid primary key references auth.users on delete cascade,
 case_id text not null references foamlab_private.town_training_cases,
 request_id uuid not null, day date not null, drawn_at timestamptz not null default now()
);
alter table foamlab_private.town_training_draws enable row level security;
revoke all on foamlab_private.town_training_draws from public,anon,authenticated;

create function foamlab_private.town_training_records(who uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 with completed as (
  select distinct on(case_id) * from foamlab_private.town_training_runs where user_id=who and step=5
  order by case_id,finished_at desc,created_at desc,id desc
 ), visible as (
  select * from completed union all
  select * from foamlab_private.town_training_runs where user_id=who and step<5 and expired_at is null
   and (created_at at time zone 'Asia/Shanghai')::date=(now() at time zone 'Asia/Shanghai')::date
 )
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'case_id',case_id,'step',step,'created_at',created_at,
 'updated_at',updated_at,'finished_at',finished_at,'is_replay',is_replay,
 'expires_at',(((created_at at time zone 'Asia/Shanghai')::date+1)::timestamp at time zone 'Asia/Shanghai'))
 order by (step<5) desc,coalesce(finished_at,created_at) desc,id),'[]'::jsonb) from visible
$$;
revoke all on function foamlab_private.town_training_records(uuid) from public,anon,authenticated;

do $migration$
declare def text; old_runs text; start_at integer; end_at integer;
begin
 select pg_get_functiondef('foamlab_private.town_play_state(uuid)'::regprocedure) into def;
 old_runs:='''runs'',coalesce((select jsonb_agg(to_jsonb(r)) from (select id,case_id,step,created_at,updated_at,finished_at from foamlab_private.town_training_runs where user_id=who order by created_at desc limit 60) r),''[]''::jsonb)';
 if position(old_runs in def)=0 then raise exception 'Review town_play_state before changing run visibility';end if;
 def:=replace(def,old_runs,$new$'runs',foamlab_private.town_training_records(who),
 'completed_cases',coalesce((select jsonb_agg(distinct case_id) from foamlab_private.town_training_runs where user_id=who and step=5),'[]'::jsonb),
 'server_now',now(),'day_reset_at',(((now() at time zone 'Asia/Shanghai')::date+1)::timestamp at time zone 'Asia/Shanghai')$new$);
 execute def;

 select pg_get_functiondef('foamlab_private.town_play_api(text,jsonb)'::regprocedure) into def;
 def:=replace(def,'reward_rare boolean:=false;','reward_rare boolean:=false; draft foamlab_private.town_training_draws;');
 def:=replace(def,'if operation=''state'' then',$new$update foamlab_private.town_training_runs set expired_at=clock_timestamp()
 where user_id=who and step<5 and expired_at is null and (created_at at time zone 'Asia/Shanghai')::date<>d;
 if operation='state' then$new$);
 start_at:=position('elsif operation=''training_start'' then' in def);
 end_at:=position('elsif operation=''activity'' then' in def);
 if start_at=0 or end_at<=start_at then raise exception 'Review town_play_api before changing training lifecycle';end if;
 def:=left(def,start_at-1)||$new$
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
 $new$||substr(def,end_at);
 execute def;
end $migration$;
