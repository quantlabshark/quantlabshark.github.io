create table public.foamlab_private_notes (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 title text not null check(char_length(title) between 1 and 300),
 body text not null default '' check(octet_length(body)<=1000000),
 page_url text not null check(page_url like '/%' and page_url not like '//%' and position(chr(92) in page_url)=0),
 page_title text not null default '', anchor_id text not null default '', anchor_text text not null default '',
 anchor_offset double precision not null default 0,
 scroll_ratio double precision not null default 0 check(scroll_ratio between 0 and 1),
 word_count integer generated always as (char_length(regexp_replace(body,'[[:space:]]','','g'))) stored,
 revision bigint not null default 1,
 created_at timestamptz not null default clock_timestamp(), updated_at timestamptz not null default clock_timestamp()
);
create index private_notes_owner_updated on public.foamlab_private_notes(owner_id,updated_at desc);
alter table public.foamlab_private_notes enable row level security;
revoke all on public.foamlab_private_notes from public,anon;
grant select,insert,update,delete on public.foamlab_private_notes to authenticated;
create policy private_notes_owner on public.foamlab_private_notes for all to authenticated
 using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create function foamlab_private.private_note_updated() returns trigger language plpgsql set search_path='' as $$
begin
 new.owner_id:=old.owner_id;new.created_at:=old.created_at;new.revision:=old.revision+1;new.updated_at:=clock_timestamp();return new;
end $$;
create trigger private_note_updated before update on public.foamlab_private_notes for each row execute function foamlab_private.private_note_updated();

-- Bind site ownership to the verified GitHub provider ID, never user-editable metadata.
create function foamlab_private.bootstrap_quant_owner() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.provider='github' and new.provider_id='112299157' then
  insert into public.foamlab_roles(user_id,role) values(new.user_id,'admin')
  on conflict(user_id) do update set role='admin';
 end if;
 return new;
end $$;
revoke all on function foamlab_private.bootstrap_quant_owner() from public,anon,authenticated;
create trigger quant_owner_identity after insert or update on auth.identities
 for each row execute function foamlab_private.bootstrap_quant_owner();
insert into public.foamlab_roles(user_id,role)
select user_id,'admin' from auth.identities where provider='github' and provider_id='112299157'
on conflict(user_id) do update set role='admin';
