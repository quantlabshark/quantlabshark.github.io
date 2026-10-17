begin;
-- Resolve the small directory tree once per SELECT, rather than walking its
-- ancestors separately for every row of the article catalog or search index.
create function foamlab_private.section_read_levels() returns jsonb
 language sql stable security definer set search_path='' as $function$
 with recursive rules as (
  select id,coalesce((' {"public":0,"member":1,"supporter":2,"admin":3}'::jsonb->>read_access)::int,1) as level
  from public.foamlab_sections where parent_id is null
  union all
  select child.id,coalesce((' {"public":0,"member":1,"supporter":2,"admin":3}'::jsonb->>child.read_access)::int,parent.level)
  from public.foamlab_sections child join rules parent on child.parent_id=parent.id
 ) select coalesce(jsonb_object_agg(id::text,level),'{}'::jsonb) from rules;
$function$;
revoke all on function foamlab_private.section_read_levels() from public;
grant execute on function foamlab_private.section_read_levels() to anon,authenticated;

create function foamlab_private.reader_access_level() returns integer
 language sql stable security definer set search_path='' as $function$
 select case when auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' then 0
 else coalesce((select case role when 'admin' then 3 when 'supporter' then 2 else 1 end
 from public.foamlab_roles where user_id=auth.uid()),1) end;
$function$;
revoke all on function foamlab_private.reader_access_level() from public;
grant execute on function foamlab_private.reader_access_level() to anon,authenticated;

create function foamlab_private.required_access_level(mode text,placements uuid[],attributes jsonb,section_levels jsonb)
 returns integer language sql immutable security invoker set search_path='' as $function$
 select case when coalesce(attributes->>'admin_only','false')='true' then 3
 else coalesce(('{"public":0,"member":1,"supporter":2,"admin":3}'::jsonb->>mode)::int,
 (select max(coalesce((section_levels->>id::text)::int,1)) from unnest(placements) p(id)),1) end;
$function$;
revoke all on function foamlab_private.required_access_level(text,uuid[],jsonb,jsonb) from public;
grant execute on function foamlab_private.required_access_level(text,uuid[],jsonb,jsonb) to anon,authenticated;

alter policy content_read_access on public.foamlab_content
 using ((select foamlab_private.reader_access_level())>=
 foamlab_private.required_access_level(read_access,section_ids,metadata,(select foamlab_private.section_read_levels())));
alter policy message_read_access on public.foamlab_messages
 using (content_id is null or exists(select 1 from public.foamlab_content c where c.id=content_id
 and (select foamlab_private.reader_access_level())>=
 foamlab_private.required_access_level(c.read_access,c.section_ids,c.metadata,(select foamlab_private.section_read_levels()))));
notify pgrst,'reload schema';
commit;
