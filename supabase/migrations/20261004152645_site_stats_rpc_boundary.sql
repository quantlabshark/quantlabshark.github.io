-- Match the site's existing RPC boundary: elevated access stays in the non-exposed schema.
alter function public.foamlab_site_stats(uuid,uuid,bigint,uuid,boolean) set schema foamlab_private;
create function public.foamlab_site_stats(p_visitor uuid,p_tab uuid,p_seq bigint,p_visit uuid default null,p_active boolean default true)
returns jsonb language sql security invoker set search_path = '' as $$
 select foamlab_private.foamlab_site_stats(p_visitor,p_tab,p_seq,p_visit,p_active)
$$;
revoke all on function public.foamlab_site_stats(uuid,uuid,bigint,uuid,boolean) from public;
grant execute on function public.foamlab_site_stats(uuid,uuid,bigint,uuid,boolean) to anon,authenticated;
