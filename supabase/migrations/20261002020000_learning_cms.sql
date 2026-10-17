-- QuantLab content, community and administration. Public content is readable without an account.
create schema if not exists foamlab_private;
revoke all on schema foamlab_private from public;
grant usage on schema foamlab_private to authenticated, anon;

create table public.foamlab_roles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check(role in ('admin','editor','moderator','blocked')),
 created_at timestamptz not null default now()
);
alter table public.foamlab_roles enable row level security;
create function foamlab_private.has_role(allowed text[]) returns boolean language sql stable security definer
set search_path = '' as $$ select exists(select 1 from public.foamlab_roles where user_id=(select auth.uid()) and role=any(allowed)) $$;
revoke all on function foamlab_private.has_role(text[]) from public;
grant execute on function foamlab_private.has_role(text[]) to authenticated,anon;
create policy roles_read on public.foamlab_roles for select to authenticated using(user_id=(select auth.uid()) or foamlab_private.has_role(array['admin']));
create policy roles_admin on public.foamlab_roles for all to authenticated using(foamlab_private.has_role(array['admin'])) with check(foamlab_private.has_role(array['admin']));
insert into public.foamlab_roles(user_id,role) select user_id,'admin' from auth.identities where provider='github' and provider_id='112299157' on conflict(user_id) do nothing;

create table public.foamlab_content (
 id uuid primary key default gen_random_uuid(),
 slug text not null unique check(slug ~ '^[a-z0-9][a-z0-9/_-]{0,179}$'),
 kind text not null check(kind in ('course','lesson','article','log','resource','tool','module','announcement','assignment','reference')),
 title text not null check(char_length(title) between 1 and 180),
 summary text not null default '' check(char_length(summary)<=2000),
 body text not null default '' check(octet_length(body)<=1000000),
 track text not null default '', series text not null default '',
 author_id uuid references auth.users(id) on delete set null default auth.uid(),
 author_name text not null default 'QuantLab',
 status text not null default 'draft' check(status in ('draft','published','archived','trash')),
 sort_order integer not null default 0,
 comments_enabled boolean not null default true,
 cover_url text not null default '',
 metadata jsonb not null default '{}'::jsonb,
 revision integer not null default 1,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index content_catalog on public.foamlab_content(status,kind,track,sort_order);
create index content_author on public.foamlab_content(author_id);
alter table public.foamlab_content enable row level security;
create policy content_read on public.foamlab_content for select using(status='published' or author_id=(select auth.uid()) or foamlab_private.has_role(array['admin','editor']));
create policy content_create on public.foamlab_content for insert to authenticated with check(foamlab_private.has_role(array['admin','editor']) or (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid()) and status='draft' and kind in ('article','log')));
create policy content_edit on public.foamlab_content for update to authenticated using(foamlab_private.has_role(array['admin','editor']) or (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid()) and status='draft' and kind in ('article','log'))) with check(foamlab_private.has_role(array['admin','editor']) or (author_id=(select auth.uid()) and status='draft' and kind in ('article','log')));
create policy content_delete on public.foamlab_content for delete to authenticated using(foamlab_private.has_role(array['admin']) and status='trash');

create table public.foamlab_revisions (
 id bigint generated always as identity primary key,
 content_id uuid references public.foamlab_content(id) on delete cascade,
 revision integer not null, snapshot jsonb not null, actor uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
create index revisions_content on public.foamlab_revisions(content_id,revision desc);
create index revisions_actor on public.foamlab_revisions(actor);
alter table public.foamlab_revisions enable row level security;
create policy revisions_read on public.foamlab_revisions for select to authenticated using(foamlab_private.has_role(array['admin','editor']));
create function foamlab_private.content_revision() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' then
  insert into public.foamlab_revisions(content_id,revision,snapshot,actor) values(old.id,old.revision,to_jsonb(old),auth.uid());
  new.revision=old.revision+1; new.updated_at=now();
 end if;
 return new;
end $$;
create trigger save_content_revision before update on public.foamlab_content for each row execute function foamlab_private.content_revision();

create table public.foamlab_public_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check(char_length(display_name) between 1 and 60),
 bio text not null default '' check(char_length(bio)<=600), updated_at timestamptz not null default now()
);
alter table public.foamlab_public_profiles enable row level security;
create policy public_profiles_read on public.foamlab_public_profiles for select using(true);
create policy public_profiles_own on public.foamlab_public_profiles for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']));

create table public.foamlab_threads (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 title text not null check(char_length(title) between 5 and 180),
 body text not null check(char_length(body) between 10 and 40000),
 category text not null default '使用问题' check(char_length(category)<=40),
 version text not null default 'v2512' check(char_length(version)<=50),
 tags text[] not null default '{}',
 status text not null default 'open' check(status in ('open','resolved','closed','hidden')),
 pinned boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index threads_catalog on public.foamlab_threads(status,pinned desc,created_at desc);
create index threads_author on public.foamlab_threads(author_id);
alter table public.foamlab_threads enable row level security;
create policy threads_read on public.foamlab_threads for select using(status<>'hidden' or author_id=(select auth.uid()) or foamlab_private.has_role(array['admin','moderator']));
create policy threads_add on public.foamlab_threads for insert to authenticated with check(author_id=(select auth.uid()) and status='open' and not pinned and not foamlab_private.has_role(array['blocked']));
create policy threads_edit on public.foamlab_threads for update to authenticated using((author_id=(select auth.uid()) and status in ('open','resolved') and not foamlab_private.has_role(array['blocked'])) or foamlab_private.has_role(array['admin','moderator'])) with check(author_id=(select auth.uid()) or foamlab_private.has_role(array['admin','moderator']));
create policy threads_delete on public.foamlab_threads for delete to authenticated using(foamlab_private.has_role(array['admin']));

create table public.foamlab_messages (
 id uuid primary key default gen_random_uuid(),
 thread_id uuid references public.foamlab_threads(id) on delete cascade,
 content_id uuid references public.foamlab_content(id) on delete cascade,
 author_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 body text not null check(char_length(body) between 2 and 30000),
 status text not null default 'visible' check(status in ('visible','hidden')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 constraint one_message_parent check(num_nonnulls(thread_id,content_id)=1)
);
create index messages_thread on public.foamlab_messages(thread_id,created_at);
create index messages_content on public.foamlab_messages(content_id,created_at);
create index messages_author on public.foamlab_messages(author_id);
alter table public.foamlab_messages enable row level security;
create policy messages_read on public.foamlab_messages for select using(foamlab_private.has_role(array['admin','moderator']) or ((status='visible' or author_id=(select auth.uid())) and (exists(select 1 from public.foamlab_threads t where t.id=thread_id and t.status<>'hidden') or exists(select 1 from public.foamlab_content c where c.id=content_id and c.status='published' and c.comments_enabled))));
create policy messages_add on public.foamlab_messages for insert to authenticated with check(author_id=(select auth.uid()) and status='visible' and not foamlab_private.has_role(array['blocked']) and (exists(select 1 from public.foamlab_threads t where t.id=thread_id and t.status in ('open','resolved')) or exists(select 1 from public.foamlab_content c where c.id=content_id and c.status='published' and c.comments_enabled)));
create policy messages_edit on public.foamlab_messages for update to authenticated using((author_id=(select auth.uid()) and status='visible' and not foamlab_private.has_role(array['blocked'])) or foamlab_private.has_role(array['admin','moderator'])) with check(author_id=(select auth.uid()) or foamlab_private.has_role(array['admin','moderator']));
create policy messages_delete on public.foamlab_messages for delete to authenticated using(author_id=(select auth.uid()) or foamlab_private.has_role(array['admin','moderator']));

create function foamlab_private.guard_community() returns trigger language plpgsql set search_path='' as $$
begin
 if not foamlab_private.has_role(array['admin','moderator']) then
  if tg_op='UPDATE' then
   if new.author_id<>old.author_id then raise exception 'Author cannot change'; end if;
   if tg_table_name='foamlab_threads' then
    if new.pinned<>old.pinned or new.status not in ('open','resolved') then raise exception 'Moderator action required'; end if;
   else
    if new.status<>old.status or new.thread_id is distinct from old.thread_id or new.content_id is distinct from old.content_id then raise exception 'Message destination cannot change'; end if;
   end if;
  end if;
  if tg_op='INSERT' and tg_table_name='foamlab_threads' then
   if (select count(*) from public.foamlab_threads where author_id=auth.uid() and created_at>now()-interval '1 hour')>=5 then raise exception 'Please wait before creating more topics'; end if;
  end if;
  if tg_op='INSERT' and tg_table_name='foamlab_messages' then
   if (select count(*) from public.foamlab_messages where author_id=auth.uid() and created_at>now()-interval '1 hour')>=40 then raise exception 'Please wait before posting again'; end if;
  end if;
 end if;
 if tg_op='INSERT' then new.created_at=now(); end if;
 new.updated_at=now(); return new;
end $$;
create trigger guard_threads before insert or update on public.foamlab_threads for each row execute function foamlab_private.guard_community();
create trigger guard_messages before insert or update on public.foamlab_messages for each row execute function foamlab_private.guard_community();

create table public.foamlab_settings (key text primary key,value jsonb not null,updated_at timestamptz not null default now());
alter table public.foamlab_settings enable row level security;
create policy settings_read on public.foamlab_settings for select using(true);
create policy settings_admin on public.foamlab_settings for all to authenticated using(foamlab_private.has_role(array['admin'])) with check(foamlab_private.has_role(array['admin']));
insert into public.foamlab_settings(key,value) values('site','{"name":"QuantLab","tagline":"理解方法，复现计算，分享经验","discussion_open":true,"registration_note":"使用 GitHub 账号参与讨论"}');

create table public.foamlab_learning_progress (
 user_id uuid references auth.users(id) on delete cascade,
 content_id uuid references public.foamlab_content(id) on delete cascade,
 completed boolean not null default true,updated_at timestamptz not null default now(),
 primary key(user_id,content_id)
);
create index learning_progress_content on public.foamlab_learning_progress(content_id);
alter table public.foamlab_learning_progress enable row level security;
create policy learning_progress_own on public.foamlab_learning_progress for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('foamlab-resources','foamlab-resources',true,52428800,array['image/png','image/jpeg','image/webp','image/svg+xml','application/pdf','application/zip','application/x-zip-compressed','text/plain','text/markdown','application/octet-stream','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.presentationml.presentation']) on conflict(id) do nothing;
create policy foamlab_assets_read on storage.objects for select using(bucket_id='foamlab-resources');
create policy foamlab_assets_add on storage.objects for insert to authenticated with check(bucket_id='foamlab-resources' and foamlab_private.has_role(array['admin','editor']));
create policy foamlab_assets_edit on storage.objects for update to authenticated using(bucket_id='foamlab-resources' and foamlab_private.has_role(array['admin','editor'])) with check(bucket_id='foamlab-resources' and foamlab_private.has_role(array['admin','editor']));
create policy foamlab_assets_delete on storage.objects for delete to authenticated using(bucket_id='foamlab-resources' and foamlab_private.has_role(array['admin','editor']));
grant select on public.foamlab_content,public.foamlab_threads,public.foamlab_messages,public.foamlab_settings,public.foamlab_public_profiles to anon;
grant select,insert,update,delete on public.foamlab_content,public.foamlab_threads,public.foamlab_messages,public.foamlab_settings,public.foamlab_public_profiles,public.foamlab_learning_progress,public.foamlab_roles to authenticated;
grant select on public.foamlab_revisions to authenticated;
revoke all on all functions in schema foamlab_private from public;
grant execute on function foamlab_private.has_role(text[]) to anon,authenticated;
