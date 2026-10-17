-- Registered, unblocked authors may publish and edit their own community articles.
drop policy content_create on public.foamlab_content;
create policy content_create on public.foamlab_content for insert to authenticated
with check (
 foamlab_private.has_role(array['admin','editor']) or
 (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid())
  and kind in ('article','log') and status in ('draft','published')
  and coalesce(metadata->>'admin_only','false')<>'true' and not metadata ? 'canonical_path')
);
drop policy content_edit on public.foamlab_content;
create policy content_edit on public.foamlab_content for update to authenticated
using (
 foamlab_private.has_role(array['admin','editor']) or
 (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid())
  and kind in ('article','log') and status in ('draft','published')
  and coalesce(metadata->>'admin_only','false')<>'true')
)
with check (
 foamlab_private.has_role(array['admin','editor']) or
 (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid())
  and kind in ('article','log') and status in ('draft','published')
  and coalesce(metadata->>'admin_only','false')<>'true' and not metadata ? 'canonical_path')
);

alter table public.foamlab_content add column published_at timestamptz;
create function foamlab_private.stamp_publication() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='INSERT' then
  new.published_at:=case when new.status='published' then now() else null end;
 else
  new.created_at:=old.created_at;
  new.published_at:=coalesce(old.published_at,
    case when old.status='published' then old.created_at when new.status='published' then now() else null end);
 end if;
 return new;
end $$;
revoke all on function foamlab_private.stamp_publication() from public,anon,authenticated;
create trigger stamp_publication before insert or update on public.foamlab_content
for each row execute function foamlab_private.stamp_publication();

-- Public author badge only. The experience ledger and pet settings stay private.
create table public.foamlab_author_levels (
 user_id uuid primary key references auth.users(id) on delete cascade,
 level integer not null default 1 check(level>=1)
);
alter table public.foamlab_author_levels enable row level security;
create policy author_levels_read on public.foamlab_author_levels for select using(true);
revoke all on public.foamlab_author_levels from public,anon,authenticated;
grant select on public.foamlab_author_levels to anon,authenticated;
insert into public.foamlab_author_levels(user_id,level)
select user_id,foamlab_private.pet_level(xp) from public.foamlab_pets;
create function foamlab_private.sync_author_level() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.foamlab_author_levels(user_id,level)
 values(new.user_id,foamlab_private.pet_level(new.xp))
 on conflict(user_id) do update set level=excluded.level;
 return new;
end $$;
revoke all on function foamlab_private.sync_author_level() from public,anon,authenticated;
create trigger sync_author_level after insert or update of xp on public.foamlab_pets
for each row execute function foamlab_private.sync_author_level();
