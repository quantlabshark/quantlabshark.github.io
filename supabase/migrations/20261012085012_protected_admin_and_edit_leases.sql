begin;

-- Protect the site owner's established account, independently of the UI/RPC.
create function foamlab_private.protected_owner_id() returns uuid language sql stable security definer set search_path='' as $$
 select user_id from auth.identities where provider='github' and provider_id='112299157' limit 1
$$;
revoke all on function foamlab_private.protected_owner_id() from public,anon;
grant execute on function foamlab_private.protected_owner_id() to authenticated;
create function foamlab_private.protect_owner_role() returns trigger
language plpgsql security definer set search_path='' as $function$
begin
 if old.user_id=foamlab_private.protected_owner_id() and old.role='admin'
 and (tg_op='DELETE' or new.role<>'admin' or new.user_id<>old.user_id)
 and auth.uid() is not null then
  raise exception using errcode='42501',message='网站所有者的管理员身份受保护，不能在网站中变更。';
 end if;
 return case when tg_op='DELETE' then old else new end;
end $function$;
revoke all on function foamlab_private.protect_owner_role() from public,anon,authenticated;
create trigger aa_protect_owner_role before update or delete on public.foamlab_roles
 for each row execute function foamlab_private.protect_owner_role();

create or replace function public.foamlab_admin_members(p_query text default '',p_role text default '',p_sort text default 'registered_at',p_direction text default 'desc',p_page integer default 1,p_size integer default 25)
returns jsonb language sql stable security invoker set search_path='' as $function$
 with response as (select foamlab_private.admin_members(p_query,p_role,p_sort,p_direction,p_page,p_size) as data)
 select data||jsonb_build_object('items',coalesce((select jsonb_agg(item||jsonb_build_object('role_protected',item->>'user_id'=foamlab_private.protected_owner_id()::text) order by n)
 from jsonb_array_elements(data->'items') with ordinality as x(item,n)),'[]'::jsonb)) from response;
$function$;
revoke all on function public.foamlab_admin_members(text,text,text,text,integer,integer) from public,anon;
grant execute on function public.foamlab_admin_members(text,text,text,text,integer,integer) to authenticated;

create table foamlab_private.content_edit_leases (
 content_id uuid primary key references public.foamlab_content(id) on delete cascade,
 owner_id uuid not null references auth.users(id) on delete cascade,
 token uuid not null,
 started_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null
);
alter table foamlab_private.content_edit_leases enable row level security;
revoke all on foamlab_private.content_edit_leases from public,anon,authenticated;
create policy edit_leases_closed on foamlab_private.content_edit_leases for all to anon,authenticated using(false) with check(false);

create function foamlab_private.content_edit_lease(content_id_value uuid,token_value uuid,action_value text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare who uuid:=auth.uid(); lease foamlab_private.content_edit_leases; acquired boolean:=false; holder text;
begin
 if who is null or not foamlab_private.has_role(array['admin']) then raise exception using errcode='42501',message='只有管理员可以占用文档编辑。';end if;
 if content_id_value is null or token_value is null or action_value is null or action_value not in ('acquire','renew','release') then raise exception using errcode='22023',message='编辑占用参数无效。';end if;
 -- Same lock order as content writes and directory moves: journal, then rows.
 perform pg_catalog.pg_advisory_xact_lock(7402512);
 if action_value='release' then
  delete from foamlab_private.content_edit_leases where content_id=content_id_value and owner_id=who and token=token_value;
  return jsonb_build_object('released',found);
 end if;
 if not exists(select 1 from public.foamlab_content where id=content_id_value) then raise exception using errcode='22023',message='文档已不存在，请返回列表。';end if;
 if action_value='acquire' then
  insert into foamlab_private.content_edit_leases(content_id,owner_id,token,expires_at)
  values(content_id_value,who,token_value,clock_timestamp()+interval '120 seconds')
  on conflict(content_id) do update set owner_id=excluded.owner_id,token=excluded.token,
   started_at=case when content_edit_leases.owner_id=who and content_edit_leases.token=token_value then content_edit_leases.started_at else clock_timestamp() end,
   expires_at=excluded.expires_at
  where content_edit_leases.expires_at<=clock_timestamp()
   or (content_edit_leases.owner_id=who and content_edit_leases.token=token_value)
   or not exists(select 1 from public.foamlab_roles where user_id=content_edit_leases.owner_id and role='admin');
  acquired:=found;
 else
  update foamlab_private.content_edit_leases set expires_at=clock_timestamp()+interval '120 seconds'
  where content_id=content_id_value and owner_id=who and token=token_value and expires_at>clock_timestamp();
  acquired:=found;
 end if;
 select * into lease from foamlab_private.content_edit_leases where content_id=content_id_value;
 select coalesce(nullif(pp.display_name,''),nullif(u.raw_user_meta_data->>'user_name',''),'另一位管理员') into holder
 from auth.users u left join public.foamlab_public_profiles pp on pp.user_id=u.id where u.id=lease.owner_id;
 return jsonb_build_object('acquired',acquired,'owner_name',coalesce(holder,'另一位管理员'),'started_at',lease.started_at,'expires_at',lease.expires_at);
end $function$;
revoke all on function foamlab_private.content_edit_lease(uuid,uuid,text) from public,anon,authenticated;
grant execute on function foamlab_private.content_edit_lease(uuid,uuid,text) to authenticated;
create function public.foamlab_content_edit_lease(p_content_id uuid,p_token uuid,p_action text default 'acquire')
returns jsonb language sql security invoker set search_path='' as $function$
 select foamlab_private.content_edit_lease(p_content_id,p_token,p_action);
$function$;
revoke all on function public.foamlab_content_edit_lease(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.foamlab_content_edit_lease(uuid,uuid,text) to authenticated;

create function foamlab_private.enforce_content_edit_lease() returns trigger
language plpgsql security definer set search_path='' as $function$
declare who uuid:=auth.uid(); lease foamlab_private.content_edit_leases; request_token text;
begin
 select * into lease from foamlab_private.content_edit_leases
 where content_id=old.id and expires_at>clock_timestamp()
 and exists(select 1 from public.foamlab_roles where user_id=owner_id and role='admin');
 if found and who is not null then
  request_token:=coalesce(nullif(current_setting('request.headers',true),'')::jsonb->>'x-foamlab-edit-token','');
  if who<>lease.owner_id or request_token<>lease.token::text then
   raise exception using errcode='55P03',message='此文档正在由另一编辑窗口占用，暂时不能修改或删除。';
  end if;
 end if;
 return case when tg_op='DELETE' then old else new end;
end $function$;
revoke all on function foamlab_private.enforce_content_edit_lease() from public,anon,authenticated;
create trigger ab_enforce_content_edit_lease before update or delete on public.foamlab_content
 for each row execute function foamlab_private.enforce_content_edit_lease();
notify pgrst,'reload schema';
commit;
