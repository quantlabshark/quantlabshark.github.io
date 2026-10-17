-- Aggregate public site traffic without storing names, account IDs, IPs or page URLs.
create table foamlab_private.site_counter (
 singleton boolean primary key default true check(singleton),
 visits bigint not null default 0 check(visits >= 0),
 pruned_at timestamptz not null default now()
);
insert into foamlab_private.site_counter(singleton) values(true);
create table foamlab_private.site_visits (
 id uuid primary key,
 created_at timestamptz not null default now()
);
create index site_visits_created on foamlab_private.site_visits(created_at);
create table foamlab_private.site_presence (
 tab_id uuid primary key,
 visitor_id uuid not null,
 seq bigint not null,
 active boolean not null,
 last_seen timestamptz not null default now()
);
create index site_presence_recent on foamlab_private.site_presence(last_seen,visitor_id) where active;
alter table foamlab_private.site_counter enable row level security;
alter table foamlab_private.site_visits enable row level security;
alter table foamlab_private.site_presence enable row level security;
revoke all on foamlab_private.site_counter,foamlab_private.site_visits,foamlab_private.site_presence from anon,authenticated;

create function public.foamlab_site_stats(p_visitor uuid,p_tab uuid,p_seq bigint,p_visit uuid default null,p_active boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare added integer; cleaned integer; total bigint; online bigint;
begin
 if p_visitor is null or p_tab is null or p_seq is null or p_seq < 1 or p_active is null then
  raise exception 'Invalid visit';
 end if;
 -- Retries and heartbeats cannot count the same page load twice.
 if p_visit is not null and p_active then
  insert into foamlab_private.site_visits(id) values(p_visit) on conflict do nothing;
  get diagnostics added = row_count;
  if added = 1 then update foamlab_private.site_counter set visits=visits+1 where singleton; end if;
 end if;
 -- A delayed heartbeat cannot bring a closed tab back online.
 insert into foamlab_private.site_presence(tab_id,visitor_id,seq,active,last_seen)
 values(p_tab,p_visitor,p_seq,p_active,statement_timestamp())
 on conflict(tab_id) do update set visitor_id=excluded.visitor_id,seq=excluded.seq,
 active=excluded.active,last_seen=excluded.last_seen
 where foamlab_private.site_presence.seq < excluded.seq;
 update foamlab_private.site_counter set pruned_at=statement_timestamp()
 where singleton and pruned_at < statement_timestamp()-interval '1 hour';
 get diagnostics cleaned = row_count;
 if cleaned = 1 then
  delete from foamlab_private.site_presence where last_seen < statement_timestamp()-interval '1 day';
  delete from foamlab_private.site_visits where created_at < statement_timestamp()-interval '7 days';
 end if;
 select visits into total from foamlab_private.site_counter where singleton;
 select count(distinct visitor_id) into online from foamlab_private.site_presence
 where active and last_seen > statement_timestamp()-interval '90 seconds';
 return jsonb_build_object('visits',total,'online',online);
end;
$$;
revoke all on function public.foamlab_site_stats(uuid,uuid,bigint,uuid,boolean) from public;
grant execute on function public.foamlab_site_stats(uuid,uuid,bigint,uuid,boolean) to anon,authenticated;
