-- Aggregate page views; no account, visitor, search text or note position is stored.
create table foamlab_private.page_view_totals (
 page_key text primary key check (length(page_key) between 1 and 320),
 views bigint not null default 0 check (views >= 0),
 pruned_at timestamptz not null default now()
);
create table foamlab_private.page_view_receipts (
 page_key text not null references foamlab_private.page_view_totals(page_key) on delete cascade,
 view_id uuid not null,
 created_at timestamptz not null default now(),
 primary key (page_key,view_id)
);
create index page_view_receipts_expiry on foamlab_private.page_view_receipts(page_key,created_at);
alter table foamlab_private.page_view_totals enable row level security;
alter table foamlab_private.page_view_receipts enable row level security;
revoke all on foamlab_private.page_view_totals,foamlab_private.page_view_receipts from public,anon,authenticated;

create function foamlab_private.page_views(p_page text,p_view uuid default null)
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
 if p_view is not null then
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
revoke all on function foamlab_private.page_views(text,uuid) from public,anon,authenticated;
grant execute on function foamlab_private.page_views(text,uuid) to anon,authenticated;

-- Public RPC exposes only the aggregate and retains the existing private boundary.
create function public.foamlab_page_views(p_page text,p_view uuid default null)
returns jsonb language sql security invoker set search_path='' as $$
 select foamlab_private.page_views(p_page,p_view);
$$;
revoke all on function public.foamlab_page_views(text,uuid) from public,anon,authenticated;
grant execute on function public.foamlab_page_views(text,uuid) to anon,authenticated;
notify pgrst,'reload schema';
