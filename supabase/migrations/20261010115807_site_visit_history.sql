-- Keep aggregate history after individual session IDs are pruned.
create table foamlab_private.site_daily_visits (
 day date primary key,
 visits bigint not null default 0 check (visits >= 0),
 complete boolean not null default true
);
alter table foamlab_private.site_daily_visits enable row level security;
revoke all on foamlab_private.site_daily_visits from public,anon,authenticated;
create policy site_daily_visits_admin on foamlab_private.site_daily_visits
 for select to authenticated using ((select foamlab_private.has_role(array['admin'])));

-- Serialize the initial snapshot and trigger installation with visit inserts.
lock table foamlab_private.site_visits in share row exclusive mode;
insert into foamlab_private.site_daily_visits(day,visits,complete)
 select (created_at at time zone 'Asia/Shanghai')::date,count(*),
  (created_at at time zone 'Asia/Shanghai')::date >
   (select min((created_at at time zone 'Asia/Shanghai')::date) from foamlab_private.site_visits)
 from foamlab_private.site_visits group by 1;

create function foamlab_private.record_site_daily_visit() returns trigger
 language plpgsql security definer set search_path='' as $$
begin
 insert into foamlab_private.site_daily_visits(day,visits)
 values ((new.created_at at time zone 'Asia/Shanghai')::date,1)
 on conflict(day) do update set visits=foamlab_private.site_daily_visits.visits+1;
 return new;
end;
$$;
revoke all on function foamlab_private.record_site_daily_visit() from public,anon,authenticated,service_role;
create trigger site_visit_daily_total after insert on foamlab_private.site_visits
 for each row execute function foamlab_private.record_site_daily_visit();

create function foamlab_private.foamlab_admin_site_stats(p_interval text default 'day',p_count integer default 30)
 returns jsonb language plpgsql security definer set search_path='' as $$
declare
 today date := (statement_timestamp() at time zone 'Asia/Shanghai')::date;
 first_day date; start_day date; current_period date; points jsonb;
begin
 if (select auth.uid()) is null or not foamlab_private.has_role(array['admin']) then
  raise exception 'Administrator access required' using errcode='42501';
 end if;
 if p_interval is null or p_interval not in ('day','month') or p_count is null
  or p_count < 1 or p_count > (case when p_interval='day' then 366 else 60 end) then
  raise exception 'Invalid statistics range' using errcode='22023';
 end if;
 select min(day) into first_day from foamlab_private.site_daily_visits where day<=today;
 if p_interval='day' then
  current_period:=today;
  start_day:=greatest(today-(p_count-1),coalesce(first_day,today));
  select coalesce(jsonb_agg(jsonb_build_object('period',d.day,'visits',coalesce(v.visits,0),
   'complete',coalesce(v.complete,true)) order by d.day),'[]'::jsonb) into points
  from (select s::date as day from generate_series(start_day::timestamp,today::timestamp,interval '1 day') s) d
  left join foamlab_private.site_daily_visits v on v.day=d.day;
 else
  current_period:=date_trunc('month',today::timestamp)::date;
  start_day:=greatest((current_period-(p_count-1)*interval '1 month')::date,
   date_trunc('month',coalesce(first_day,today)::timestamp)::date);
  select coalesce(jsonb_agg(jsonb_build_object('period',d.month,'visits',coalesce(v.visits,0),
   'complete',coalesce(v.complete,true) and (first_day is null or d.month>=first_day)) order by d.month),'[]'::jsonb) into points
  from (select s::date as month from generate_series(start_day::timestamp,current_period::timestamp,interval '1 month') s) d
  left join (
   select date_trunc('month',day::timestamp)::date as month,sum(visits) as visits,bool_and(complete) as complete
   from foamlab_private.site_daily_visits where day>=start_day and day<=today group by 1
  ) v on v.month=d.month;
 end if;
 return jsonb_build_object(
  'interval',p_interval,'timezone','Asia/Shanghai','as_of',statement_timestamp(),
  'first_recorded_day',first_day,'items',points,
  'today_visits',coalesce((select visits from foamlab_private.site_daily_visits where day=today),0),
  'month_visits',coalesce((select sum(visits) from foamlab_private.site_daily_visits where day>=date_trunc('month',today::timestamp)::date and day<=today),0),
  'total_visits',(select visits from foamlab_private.site_counter where singleton),
  'online',(select count(distinct visitor_id) from foamlab_private.site_presence where active and last_seen>statement_timestamp()-interval '90 seconds')
 );
end;
$$;
revoke all on function foamlab_private.foamlab_admin_site_stats(text,integer) from public,anon;
grant execute on function foamlab_private.foamlab_admin_site_stats(text,integer) to authenticated;

create function public.foamlab_admin_site_stats(p_interval text default 'day',p_count integer default 30)
 returns jsonb language sql security invoker set search_path='' as $$
 select foamlab_private.foamlab_admin_site_stats(p_interval,p_count);
$$;
revoke all on function public.foamlab_admin_site_stats(text,integer) from public,anon;
grant execute on function public.foamlab_admin_site_stats(text,integer) to authenticated;
