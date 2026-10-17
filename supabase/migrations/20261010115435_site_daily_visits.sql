-- Daily visits use the same session ledger as the cumulative counter.
-- A day runs from 00:00 to 24:00 in Asia/Shanghai (UTC+8).
-- The public invoker wrapper and existing permissions remain in place.

CREATE OR REPLACE FUNCTION foamlab_private.foamlab_site_stats(p_visitor uuid, p_tab uuid, p_seq bigint, p_visit uuid DEFAULT NULL::uuid, p_active boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 added integer; cleaned integer; total bigint; online bigint; today_visits bigint;
 day_start timestamptz := date_trunc('day', statement_timestamp() at time zone 'Asia/Shanghai') at time zone 'Asia/Shanghai';
begin
 if p_visitor is null or p_tab is null or p_seq is null or p_seq < 1 or p_active is null then
  raise exception 'Invalid visit';
 end if;
 -- Retries, navigation and heartbeats cannot count the same visit twice.
 if p_visit is not null and p_active then
  insert into foamlab_private.site_visits(id,created_at) values(p_visit,statement_timestamp()) on conflict do nothing;
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
 -- Bound the timestamp column directly so the existing index can serve today's count.
 select count(*) into today_visits from foamlab_private.site_visits
 where created_at >= day_start and created_at < day_start + interval '24 hours';
 return jsonb_build_object('visits',total,'today_visits',today_visits,'online',online);
end;
$function$
;
