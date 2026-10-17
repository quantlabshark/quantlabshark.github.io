-- Presence is shared only with signed-in GitHub participants. No location or
-- last-seen timestamp is exposed; a resident visiting another town stays online.
create or replace function foamlab_private.town_presence_status(user_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not foamlab_private.has_github_identity()
    or foamlab_private.has_role(array['blocked']) or not foamlab_private.town_enabled() then
  return jsonb_build_object('states','[]'::jsonb);
 end if;
 if coalesce(cardinality(user_ids),0)>30 then raise exception '一次最多查看 30 位邻居。'; end if;
 return jsonb_build_object('states',coalesce((
  select jsonb_agg(jsonb_build_object('user_id',r.user_id,'online',exists(
   select 1 from public.foamlab_town_presence p where p.user_id=r.user_id
    and p.seen_at>now()-interval '2 minutes'
  ))) from public.foamlab_town_residents r where r.user_id=any(user_ids)
  and not exists(select 1 from public.foamlab_roles b where b.user_id=r.user_id and b.role='blocked')
 ),'[]'::jsonb));
end $$;
create or replace function public.foamlab_town_presence_status(user_ids uuid[])
returns jsonb language sql stable set search_path='' as $$
 select foamlab_private.town_presence_status(user_ids)
$$;
revoke all on function foamlab_private.town_presence_status(uuid[]),public.foamlab_town_presence_status(uuid[]) from public,anon,authenticated;
grant execute on function foamlab_private.town_presence_status(uuid[]),public.foamlab_town_presence_status(uuid[]) to authenticated;
