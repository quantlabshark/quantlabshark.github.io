-- Only established accounts contribute to public traffic statistics.
-- Guests retain read access to aggregate totals through the existing RPCs.
create or replace function foamlab_private.foamlab_site_stats(
 p_visitor uuid,p_tab uuid,p_seq bigint,p_visit uuid default null,p_active boolean default true
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 user_id uuid := (select auth.uid());
 signed_in boolean;
 added integer; cleaned integer; total bigint; online bigint; today_visits bigint;
 day_start timestamptz := date_trunc('day',statement_timestamp() at time zone 'Asia/Shanghai') at time zone 'Asia/Shanghai';
begin
 if p_visitor is null or p_tab is null or p_seq is null or p_seq<1 or p_active is null then
  raise exception 'Invalid visit';
 end if;
 signed_in := user_id is not null and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false);
 if signed_in then
  if p_visit is not null and p_active then
   insert into foamlab_private.site_visits(id,created_at)
    values(p_visit,statement_timestamp()) on conflict do nothing;
   get diagnostics added=row_count;
   if added=1 then update foamlab_private.site_counter set visits=visits+1 where singleton; end if;
  end if;
  -- The account identity comes from the verified JWT, never the browser's visitor ID.
  insert into foamlab_private.site_presence(tab_id,visitor_id,seq,active,last_seen)
   values(p_tab,user_id,p_seq,p_active,statement_timestamp())
  on conflict(tab_id) do update set visitor_id=excluded.visitor_id,seq=excluded.seq,
   active=excluded.active,last_seen=excluded.last_seen
   where foamlab_private.site_presence.seq<excluded.seq;
  update foamlab_private.site_counter set pruned_at=statement_timestamp()
   where singleton and pruned_at<statement_timestamp()-interval '1 hour';
  get diagnostics cleaned=row_count;
  if cleaned=1 then
   delete from foamlab_private.site_presence where last_seen<statement_timestamp()-interval '1 day';
   delete from foamlab_private.site_visits where created_at<statement_timestamp()-interval '7 days';
  end if;
 end if;
 select visits into total from foamlab_private.site_counter where singleton;
 select count(distinct visitor_id) into online from foamlab_private.site_presence
  where active and last_seen>statement_timestamp()-interval '90 seconds';
 select count(*) into today_visits from foamlab_private.site_visits
  where created_at>=day_start and created_at<day_start+interval '24 hours';
 return jsonb_build_object('visits',total,'today_visits',today_visits,'online',online);
end $$;

-- Retain the existing content visibility checks and make page increments authenticated.
create or replace function foamlab_private.page_views(p_page text,p_view uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 key text; target uuid; article record;
 total bigint; added integer; cleaned integer;
begin
 if p_page is null or length(p_page)>320 then
  raise exception 'Invalid page' using errcode='22023';
 end if;
 if p_page like 'content:%' then
  select id,status,read_access,section_ids,jsonb_build_object('admin_only',metadata->'admin_only') as metadata
   into article from public.foamlab_content where slug=substr(p_page,9);
  if not found or article.status<>'published' or
   foamlab_private.reader_access_level()<foamlab_private.required_access_level(article.read_access,article.section_ids,article.metadata,foamlab_private.section_read_levels()) then
   return null;
  end if;
  key='content:'||article.id::text;
 elsif p_page ~ '^section:[0-9a-f-]{36}$' then
  select id into target from public.foamlab_sections where id=substr(p_page,9)::uuid
   and (visible or foamlab_private.has_role(array['admin']));
  if not found then return null; end if;
  key='section:'||target::text;
 elsif p_page ~ '^topic:[0-9a-f-]{36}$' then
  select id into target from public.foamlab_threads where id=substr(p_page,7)::uuid and status<>'hidden';
  if not found then return null; end if;
  key='topic:'||target::text;
 elsif p_page ~ '^path:/[a-zA-Z0-9_/-]*([.]html)?$' and p_page not like 'path://%'
   and p_page !~ '^path:/(assets|downloads)/' then
  key=p_page;
 else
  raise exception 'Invalid page' using errcode='22023';
 end if;
 if p_view is not null and (select auth.uid()) is not null
  and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false) then
  insert into foamlab_private.page_view_totals(page_key) values(key) on conflict do nothing;
  insert into foamlab_private.page_view_receipts(page_key,view_id) values(key,p_view) on conflict do nothing;
  get diagnostics added=row_count;
  if added=1 then
   update foamlab_private.page_view_totals set views=views+1 where page_key=key;
  end if;
  update foamlab_private.page_view_totals set pruned_at=statement_timestamp()
   where page_key=key and pruned_at<statement_timestamp()-interval '1 hour';
  get diagnostics cleaned=row_count;
  if cleaned=1 then
   delete from foamlab_private.page_view_receipts
    where page_key=key and created_at<statement_timestamp()-interval '7 days';
  end if;
 end if;
 select views into total from foamlab_private.page_view_totals where page_key=key;
 return jsonb_build_object('page',key,'views',coalesce(total,0));
end $$;

-- Clear both aggregate history and per-session deduplication records together.
lock table foamlab_private.site_counter,foamlab_private.site_visits,
 foamlab_private.site_presence,foamlab_private.site_daily_visits,
 foamlab_private.page_view_receipts,foamlab_private.page_view_totals in access exclusive mode;
truncate table foamlab_private.site_visits,foamlab_private.site_presence,
 foamlab_private.site_daily_visits,foamlab_private.page_view_receipts,
 foamlab_private.page_view_totals;
update foamlab_private.site_counter set visits=0,pruned_at=statement_timestamp() where singleton;
