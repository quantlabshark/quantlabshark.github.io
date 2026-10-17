-- Public avatar choices are separate from private profile details.
create table public.foamlab_avatars (
 user_id uuid primary key references auth.users(id) on delete cascade,
 avatar text not null default 'bamboo' check(avatar in ('bamboo','breeze','music','ribbon','scholar','engineer','explorer','space','spring','summer','autumn','winter','photo')),
 photo_path text,
 updated_at timestamptz not null default now(),
 constraint avatar_photo_owner check(photo_path is null or (photo_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$' and split_part(photo_path,'/',1)=user_id::text)),
 constraint avatar_photo_present check(avatar<>'photo' or photo_path is not null)
);
alter table public.foamlab_avatars enable row level security;
grant select on public.foamlab_avatars to anon,authenticated;
grant insert,update on public.foamlab_avatars to authenticated;
create policy avatars_read on public.foamlab_avatars for select using(true);
create policy avatars_insert on public.foamlab_avatars for insert to authenticated
 with check(user_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']));
create policy avatars_update on public.foamlab_avatars for update to authenticated
 using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']));
create trigger foamlab_avatar_updated before update on public.foamlab_avatars
 for each row execute function public.foamlab_touch_updated_at();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('foamlab-avatars','foamlab-avatars',true,2097152,array['image/webp']);
create policy avatar_files_insert on storage.objects for insert to authenticated
 with check(bucket_id='foamlab-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text
 and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$' and not foamlab_private.has_role(array['blocked']));
create policy avatar_files_select on storage.objects for select to authenticated
 using(bucket_id='foamlab-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy avatar_files_delete on storage.objects for delete to authenticated
 using(bucket_id='foamlab-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
-- Every replacement uses a new object key, so a failed upload/save keeps the current avatar intact.
