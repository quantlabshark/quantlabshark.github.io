alter table public.foamlab_content add column pinned boolean not null default false;
-- Admin-only site management; member publications stay in the two community modules.
alter policy "content_read" on public.foamlab_content
 using ((foamlab_private.has_role(ARRAY['admin'::text]) OR ((COALESCE((metadata ->> 'admin_only'::text), 'false'::text) <> 'true'::text) AND ((status = 'published'::text) OR (author_id = ( SELECT auth.uid() AS uid))))));
alter policy "revisions_read" on public.foamlab_revisions
 using (foamlab_private.has_role(ARRAY['admin'::text]));
alter policy "threads_read" on public.foamlab_threads
 using (((status <> 'hidden'::text) OR (author_id = ( SELECT auth.uid() AS uid)) OR foamlab_private.has_role(ARRAY['admin'::text])));
alter policy "threads_edit" on public.foamlab_threads
 using ((((author_id = ( SELECT auth.uid() AS uid)) AND (status = ANY (ARRAY['open'::text, 'resolved'::text])) AND (NOT foamlab_private.has_role(ARRAY['blocked'::text]))) OR foamlab_private.has_role(ARRAY['admin'::text])))
 with check (((author_id = ( SELECT auth.uid() AS uid)) OR foamlab_private.has_role(ARRAY['admin'::text])));
alter policy "messages_read" on public.foamlab_messages
 using ((foamlab_private.has_role(ARRAY['admin'::text]) OR (((status = 'visible'::text) OR (author_id = ( SELECT auth.uid() AS uid))) AND ((EXISTS ( SELECT 1
   FROM foamlab_threads t
  WHERE ((t.id = foamlab_messages.thread_id) AND (t.status <> 'hidden'::text)))) OR (EXISTS ( SELECT 1
   FROM foamlab_content c
  WHERE ((c.id = foamlab_messages.content_id) AND (c.status = 'published'::text) AND c.comments_enabled)))))));
alter policy "messages_edit" on public.foamlab_messages
 using ((((author_id = ( SELECT auth.uid() AS uid)) AND (status = 'visible'::text) AND (NOT foamlab_private.has_role(ARRAY['blocked'::text]))) OR foamlab_private.has_role(ARRAY['admin'::text])))
 with check (((author_id = ( SELECT auth.uid() AS uid)) OR foamlab_private.has_role(ARRAY['admin'::text])));
alter policy "sections_insert" on public.foamlab_sections
 with check (foamlab_private.has_role(ARRAY['admin'::text]));
alter policy "messages_delete" on public.foamlab_messages
 using (((author_id = ( SELECT auth.uid() AS uid)) OR foamlab_private.has_role(ARRAY['admin'::text])));
alter policy "foamlab_assets_add" on storage.objects
 with check (((bucket_id = 'foamlab-resources'::text) AND foamlab_private.has_role(ARRAY['admin'::text])));
alter policy "foamlab_assets_edit" on storage.objects
 using (((bucket_id = 'foamlab-resources'::text) AND foamlab_private.has_role(ARRAY['admin'::text])))
 with check (((bucket_id = 'foamlab-resources'::text) AND foamlab_private.has_role(ARRAY['admin'::text])));
alter policy "foamlab_assets_delete" on storage.objects
 using (((bucket_id = 'foamlab-resources'::text) AND foamlab_private.has_role(ARRAY['admin'::text])));
alter policy "content_create" on public.foamlab_content
 with check ((foamlab_private.has_role(ARRAY['admin'::text]) OR ((NOT foamlab_private.has_role(ARRAY['blocked'::text])) AND (author_id = ( SELECT auth.uid() AS uid)) AND (kind = ANY (ARRAY['article'::text, 'log'::text])) AND (status = ANY (ARRAY['draft'::text, 'published'::text])) AND (COALESCE((metadata ->> 'admin_only'::text), 'false'::text) <> 'true'::text) AND (NOT (metadata ? 'canonical_path'::text)))));
alter policy "content_edit" on public.foamlab_content
 using ((foamlab_private.has_role(ARRAY['admin'::text]) OR ((NOT foamlab_private.has_role(ARRAY['blocked'::text])) AND (author_id = ( SELECT auth.uid() AS uid)) AND (kind = ANY (ARRAY['article'::text, 'log'::text])) AND (status = ANY (ARRAY['draft'::text, 'published'::text])) AND (COALESCE((metadata ->> 'admin_only'::text), 'false'::text) <> 'true'::text))))
 with check ((foamlab_private.has_role(ARRAY['admin'::text]) OR ((NOT foamlab_private.has_role(ARRAY['blocked'::text])) AND (author_id = ( SELECT auth.uid() AS uid)) AND (kind = ANY (ARRAY['article'::text, 'log'::text])) AND (status = ANY (ARRAY['draft'::text, 'published'::text])) AND (COALESCE((metadata ->> 'admin_only'::text), 'false'::text) <> 'true'::text) AND (NOT (metadata ? 'canonical_path'::text)))));
alter policy "sections_update" on public.foamlab_sections
 using (foamlab_private.has_role(ARRAY['admin'::text]))
 with check (foamlab_private.has_role(ARRAY['admin'::text]));
alter policy "sections_delete" on public.foamlab_sections
 using (foamlab_private.has_role(ARRAY['admin'::text]));
alter policy "town_mail_participant" on public.foamlab_town_mail
 using (((owner_id = ( SELECT auth.uid() AS uid)) OR (author_id = ( SELECT auth.uid() AS uid)) OR ( SELECT foamlab_private.has_role(ARRAY['admin'::text]) AS has_role)));
alter policy "town_reports_mod" on public.foamlab_town_reports
 using (( SELECT foamlab_private.has_role(ARRAY['admin'::text]) AS has_role));
alter policy "town_gallery_manage_read" on storage.objects
 using (((bucket_id = 'foamlab-town-gallery'::text) AND (((storage.foldername(name))[1] = ( SELECT (auth.uid())::text AS uid)) OR ( SELECT foamlab_private.has_role(ARRAY['admin'::text]) AS has_role))));

CREATE OR REPLACE FUNCTION foamlab_private.town_gallery_can_remove(path text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select foamlab_private.town_gallery_can_upload() and
 (split_part(path,'/',1)=auth.uid()::text or foamlab_private.has_role(array['admin']))
 and not exists(select 1 from foamlab_private.town_gallery where object_path=path and not hidden) $function$
;

CREATE OR REPLACE FUNCTION foamlab_private.town_gallery_api(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 declare who uuid:=auth.uid(); target uuid:=nullif(payload->>'owner','')::uuid;
 p integer:=greatest(0,least(coalesce((payload->>'page')::integer,0),10000)); total integer; likes_total bigint;
 pic foamlab_private.town_gallery; card jsonb; path text; title_text text; body text; liked boolean;
 mod boolean:=foamlab_private.has_role(array['admin']);
 begin
 if not foamlab_private.town_enabled() then raise exception '小镇暂未开放。';end if;
 if operation='list' then
  select count(*),coalesce(sum((select count(*) from foamlab_private.town_gallery_likes l where l.image_id=g.id)),0)
  into total,likes_total from foamlab_private.town_gallery g where not hidden and (target is null or owner_id=target);
  p:=least(p,greatest(0,ceil(total/12.0)::integer-1));
  return jsonb_build_object('total',total,'total_likes',likes_total,'page',p,'items',coalesce((select jsonb_agg(to_jsonb(v)) from (
   select g.id,g.owner_id,g.object_path,g.title,g.description,g.created_at,
   coalesce(c.card->>'name',g.author_name) author_name,coalesce((c.card->>'level')::integer,g.author_level) author_level,
   coalesce(c.card->>'province',g.province) province,
   (select count(*) from foamlab_private.town_gallery_likes l where l.image_id=g.id) likes,
   exists(select 1 from foamlab_private.town_gallery_likes l where l.image_id=g.id and l.user_id=who) liked,
   coalesce(g.owner_id=who or mod,false) can_delete
   from foamlab_private.town_gallery g left join lateral(select foamlab_private.town_card(g.owner_id) card) c on true
   where not g.hidden and (target is null or g.owner_id=target)
   order by case when payload->>'sort'='popular' then (select count(*) from foamlab_private.town_gallery_likes l where l.image_id=g.id) else 0 end desc,g.created_at desc,g.id
   offset p*12 limit 12) v),'[]'::jsonb));
 end if;
 if not foamlab_private.town_gallery_can_upload() then raise exception using errcode='42501',message='请使用 GitHub 登录并入住后操作。';end if;
 if operation='publish' then
  perform 1 from public.foamlab_town_residents where user_id=who for update;
  path:=payload->>'object_path';
  if path is null or split_part(path,'/',1)<>who::text or path!~ '^[a-f0-9-]+/[a-f0-9-]+\.(png|jpg|webp)$' then raise exception using errcode='42501',message='图片路径无效。';end if;
  select * into pic from foamlab_private.town_gallery where object_path=path;
  if found then
   if pic.hidden then raise exception '这件作品已删除，请重新上传。';end if;
   return jsonb_build_object('id',pic.id);
  end if;
  if not exists(select 1 from storage.objects where bucket_id='foamlab-town-gallery' and name=path and metadata->>'mimetype' in ('image/png','image/jpeg','image/webp') and (metadata->>'size')::bigint between 1 and 6291456) then raise exception '请先上传有效图片。';end if;
  if (select count(*) from foamlab_private.town_gallery where owner_id=who and created_at>now()-interval '1 day')>=20 then raise exception '每天最多发布 20 张计算图片。';end if;
  title_text:=foamlab_private.town_text(payload->>'title',100);body:=btrim(coalesce(payload->>'description',''));
  if char_length(body)>500 then raise exception '计算说明最多 500 字。';end if;
  card:=foamlab_private.town_card(who);
  insert into foamlab_private.town_gallery(owner_id,object_path,title,description,author_name,author_level,province)
   values(who,path,title_text,body,card->>'name',(card->>'level')::integer,card->>'province') returning * into pic;
  return jsonb_build_object('id',pic.id);
 elsif operation in ('like','delete') then
  select * into pic from foamlab_private.town_gallery where id=(payload->>'id')::uuid and not hidden for update;
  if pic.id is null then raise exception '作品不存在或已删除。';end if;
  if operation='like' then
   liked:=coalesce((payload->>'liked')::boolean,true);
   if liked then insert into foamlab_private.town_gallery_likes(image_id,user_id) values(pic.id,who) on conflict do nothing;
   else delete from foamlab_private.town_gallery_likes where image_id=pic.id and user_id=who;end if;
   return jsonb_build_object('id',pic.id,'liked',liked,'likes',(select count(*) from foamlab_private.town_gallery_likes where image_id=pic.id));
  end if;
  if pic.owner_id<>who and not mod then raise exception using errcode='42501',message='只有作者或管理员可以删除作品。';end if;
  update foamlab_private.town_gallery set hidden=true where id=pic.id;
  return jsonb_build_object('object_path',pic.object_path);
 else raise exception '未知操作。';end if;
 end $function$
;

CREATE OR REPLACE FUNCTION foamlab_private.guard_community()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin if tg_op='UPDATE' then new.created_at=old.created_at; end if; if not foamlab_private.has_role(array['admin']) then if tg_op='INSERT' and tg_table_name='foamlab_threads' then if exists(select 1 from public.foamlab_settings where key='site' and value->>'discussion_open'='false') then raise exception 'New discussions are temporarily closed'; end if; if (select count(*) from public.foamlab_threads where author_id=auth.uid() and created_at>now()-interval '1 hour')>=5 then raise exception 'Please wait before creating more topics'; end if; end if; if tg_op='INSERT' and tg_table_name='foamlab_messages' and (select count(*) from public.foamlab_messages where author_id=auth.uid() and created_at>now()-interval '1 hour')>=40 then raise exception 'Please wait before posting again'; end if; if tg_op='UPDATE' then if new.author_id<>old.author_id then raise exception 'Author cannot change'; end if; if tg_table_name='foamlab_threads' then if new.pinned<>old.pinned or new.status not in ('open','resolved') then raise exception 'Moderator action required'; end if; else if new.status<>old.status or new.thread_id is distinct from old.thread_id or new.content_id is distinct from old.content_id then raise exception 'Message destination cannot change'; end if; end if; end if; end if; if tg_op='INSERT' then new.created_at=now(); end if; new.updated_at=now(); return new; end $function$
;

CREATE OR REPLACE FUNCTION foamlab_private.content_sections_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare community_id uuid;
begin
 -- Ordinary edits do not rewrite an admin's placements on a member's own article.
 if tg_op='UPDATE' and new.section_ids is not distinct from old.section_ids then return new; end if;
 perform pg_advisory_xact_lock(7402512);
 if tg_op='INSERT' and cardinality(new.section_ids)=0 and new.kind in ('article','log') and coalesce(new.metadata->>'admin_only','false')<>'true' then
  select id into community_id from public.foamlab_sections where key='sharing';
  if community_id is not null then new.section_ids:=array[community_id]; end if;
 end if;
 if cardinality(new.section_ids)>20 then raise exception '每篇内容最多选择 20 个位置。'; end if;
 if exists(select 1 from unnest(new.section_ids) s(id) where id is null or not exists(select 1 from public.foamlab_sections d where d.id=s.id)) then raise exception '目录已变化，请刷新后重新选择位置。'; end if;
 select coalesce(array_agg(distinct x),'{}'::uuid[]) into new.section_ids from unnest(new.section_ids) x;
 if current_user in ('anon','authenticated') and not foamlab_private.has_role(array['admin']) then
  if tg_op='UPDATE' then raise exception '文章位置由管理员调整。'; end if;
  if exists(select 1 from public.foamlab_sections where id=any(new.section_ids) and key<>'sharing') then raise exception '个人文章发布在实践与分享。'; end if;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.foamlab_delete_section(section_id uuid, expected_revision integer)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare ids uuid[]; removed integer; child record;
begin
 if not foamlab_private.has_role(array['admin']) then raise exception '需要内容管理权限。'; end if;
 perform pg_advisory_xact_lock(7402512);
 if not exists(select 1 from public.foamlab_sections where id=section_id and revision=expected_revision) then raise exception '目录已被更新，请刷新后重试。'; end if;
 with recursive tree as (select id from public.foamlab_sections where id=section_id union all select s.id from public.foamlab_sections s join tree t on s.parent_id=t.id) select array_agg(id) into ids from tree;
 update public.foamlab_content c set section_ids=array(select x from unnest(c.section_ids) x where not(x=any(ids))) where c.section_ids && ids;
 get diagnostics removed=row_count;
 -- Delete leaves first because the parent foreign key is restrictive.
 for child in with recursive tree as (select id,0 depth from public.foamlab_sections where id=section_id union all select s.id,t.depth+1 from public.foamlab_sections s join tree t on s.parent_id=t.id) select id from tree order by depth desc loop
  delete from public.foamlab_sections where id=child.id;
 end loop;
 return removed;
end $function$
;

CREATE OR REPLACE FUNCTION foamlab_private.town_admin(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 declare typ text:=coalesce(payload->>'type','reports'); p integer:=greatest(0,least(coalesce((payload->>'page')::integer,0),10000));
 term text:=left(trim(coalesce(payload->>'query','')),100); filter_status text:=coalesce(payload->>'status',''); sort_order text:=coalesce(payload->>'sort','newest');
 items jsonb; n bigint; gkey text; province_id text; group_label text; alias_list text[]; setting_key text; setting_value jsonb; festival_name text; festival_dates jsonb;
 begin
 if auth.uid() is null or not foamlab_private.has_github_identity() or not foamlab_private.has_role(array['admin']) or foamlab_private.has_role(array['blocked']) then raise exception using errcode='42501',message='需要管理员或社区管理员权限。'; end if;
 if operation='list' then
 if typ='reports' then
 with rows as (select r.id,r.mail_id,r.reason,r.status,r.created_at,m.body,m.status mail_status,m.owner_id,m.author_id,coalesce(pr.display_name,'鲨鱼邻居') reporter from public.foamlab_town_reports r join public.foamlab_town_mail m on m.id=r.mail_id left join public.foamlab_public_profiles pr on pr.user_id=r.reporter_id where (filter_status='' or r.status=filter_status) and (term='' or position(lower(term) in lower(m.body||r.reason))>0))
 select (select count(*) from rows),coalesce(jsonb_agg(to_jsonb(s)),'[]') into n,items from (select * from rows order by case when sort_order='oldest' then created_at end asc,created_at desc,id offset p*20 limit 20) s;
 elsif typ='mail' then
 with rows as (select m.*,coalesce(pr.display_name,'鲨鱼邻居') author_name from public.foamlab_town_mail m left join public.foamlab_public_profiles pr on pr.user_id=m.author_id where (filter_status='' or m.status=filter_status) and (term='' or position(lower(term) in lower(m.body||coalesce(pr.display_name,'')))>0))
 select (select count(*) from rows),coalesce(jsonb_agg(to_jsonb(s)),'[]') into n,items from (select * from rows order by case when sort_order='oldest' then created_at end asc,created_at desc,id offset p*20 limit 20) s;
 elsif typ='groups' then
 with rows as (select * from public.foamlab_town_groups where term='' or position(lower(term) in lower(display_name||' '||province))>0)
 select (select count(*) from rows),coalesce(jsonb_agg(to_jsonb(s)),'[]') into n,items from (select * from rows order by province,display_name offset p*20 limit 20) s;
 elsif typ='residents' then
 with rows as (select r.*,coalesce(pr.display_name,'鲨鱼邻居') name from public.foamlab_town_residents r left join public.foamlab_public_profiles pr using(user_id) where term='' or position(lower(term) in lower(coalesce(pr.display_name,'')||' '||r.group_name))>0)
 select (select count(*) from rows),coalesce(jsonb_agg(to_jsonb(s)),'[]') into n,items from (select user_id,name,province,group_name,created_at,last_seen_at from rows order by case when sort_order='name' then name end,case when sort_order='oldest' then created_at end asc,created_at desc,user_id offset p*20 limit 20) s;
 else raise exception '未知的管理列表。'; end if;
 return jsonb_build_object('items',items,'total',n,'page',p);
 elsif operation in ('hide','restore','resolve') then
 if operation='resolve' then update public.foamlab_town_reports set status='resolved' where id=(payload->>'id')::uuid;
 else update public.foamlab_town_mail set status=case when operation='hide' then 'hidden' else 'visible' end,updated_at=now() where id=(payload->>'id')::uuid and status<>'deleted'; end if;
 elsif operation in ('group_save','group_delete','settings') then
 if not foamlab_private.has_role(array['admin']) then raise exception using errcode='42501',message='此项需要网站管理员权限。'; end if;
 if operation='settings' then
 for setting_key,setting_value in select key,value from jsonb_each(payload) loop
 if setting_key='town_enabled' and setting_value in ('"off"'::jsonb,'"admins"'::jsonb,'"on"'::jsonb) then null;
 elsif setting_key='town_banned_words' and jsonb_typeof(setting_value)='array' and jsonb_array_length(setting_value)<=200 then
 if exists(select 1 from jsonb_array_elements(setting_value) v where jsonb_typeof(v)<>'string' or char_length(v#>>'{}')>40) then raise exception '过滤词每项最多 40 个字。'; end if;
 elsif setting_key='town_options' and jsonb_typeof(setting_value)='object' then
 if not setting_value ?& array['move_days','mail_hour_limit','max_online','interactions'] then raise exception '请填写全部小镇设置。'; end if;
 if (setting_value->>'move_days')::integer not between 1 and 30 or (setting_value->>'mail_hour_limit')::integer not between 1 and 30 or (setting_value->>'max_online')::integer not between 1 and 30 or jsonb_typeof(setting_value->'interactions')<>'boolean' then raise exception '设置范围为 1–30；互动开关使用布尔值。'; end if;
 elsif setting_key='town_festivals' and jsonb_typeof(setting_value)='object' and length(setting_value::text)<20000 then
 for festival_name,festival_dates in select event.key,event.value from jsonb_each(setting_value) y cross join lateral jsonb_each(y.value) event loop
 if jsonb_typeof(festival_dates)<>'array' or jsonb_array_length(festival_dates)<>2 or festival_dates->>0 is null or festival_dates->>1 is null or (festival_dates->>0)::date>(festival_dates->>1)::date then raise exception '请填写有效的活动起止日期。'; end if;
 end loop;
 else raise exception '设置项无效：%',setting_key;
 end if;
 insert into public.foamlab_settings(key,value) values(setting_key,setting_value) on conflict(key) do update set value=excluded.value,updated_at=now();
 end loop;
 else
 province_id:=payload->>'province';gkey:=foamlab_private.town_normalize(payload->>'group_key');
 if not province_id=any(foamlab_private.town_provinces()) or gkey='' then raise exception '请选择省份并填写名称。'; end if;
 if operation='group_delete' then delete from public.foamlab_town_groups where province=province_id and group_key=gkey;
 else
 group_label:=foamlab_private.town_text(payload->>'display_name',40);
 select coalesce(array_agg(distinct foamlab_private.town_normalize(v)) filter(where trim(v)<>''),'{}') into alias_list from jsonb_array_elements_text(coalesce(payload->'aliases','[]')) v;
 if cardinality(alias_list)>40 then raise exception '每个研究所最多 40 个别名。'; end if;
 if exists(select 1 from public.foamlab_town_groups g where g.province=province_id and g.group_key<>gkey and (g.group_key=any(alias_list) or gkey=any(g.aliases) or g.aliases&&alias_list)) then raise exception '别名已属于另一个研究所，请先调整原记录。'; end if;
 insert into public.foamlab_town_groups(group_key,province,display_name,aliases) values(gkey,province_id,group_label,alias_list) on conflict(group_key,province) do update set display_name=excluded.display_name,aliases=excluded.aliases;
 end if;
 end if;
 else raise exception '未知的管理操作。'; end if;
 return jsonb_build_object('saved',true);
 end $function$
;

CREATE OR REPLACE FUNCTION foamlab_private.accept_answer(thread_id uuid, message_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 declare who uuid:=auth.uid(); t public.foamlab_threads; m public.foamlab_messages; awarded integer:=0;
 begin
 if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) then raise exception using errcode='42501',message='请使用 GitHub 登录后操作。'; end if;
 select * into t from public.foamlab_threads where id=thread_id for update;
 if not found or t.status not in ('open','resolved') or (t.author_id<>who and not foamlab_private.has_role(array['admin'])) then raise exception using errcode='42501',message='由提问者或管理员采纳回答。'; end if;
 if message_id is not null then
 select * into m from public.foamlab_messages where id=message_id and foamlab_messages.thread_id=t.id and status='visible';
 if not found or m.author_id=t.author_id then raise exception '请选择其他用户在本问题下的有效回答。'; end if;
 end if;
 if t.accepted_message_id is not distinct from message_id then return jsonb_build_object('accepted_message_id',message_id,'awarded',0); end if;
 update public.foamlab_threads set accepted_message_id=message_id,accepted_at=case when message_id is not null then now() end,status=case when message_id is null then 'open' else 'resolved' end where id=t.id;
 if message_id is not null then awarded:=foamlab_private.pet_award(m.author_id,'accepted','accepted:'||m.id,20,3,m.id,t.id); end if;
 return jsonb_build_object('accepted_message_id',message_id,'awarded',awarded);
 end $function$
;

CREATE OR REPLACE FUNCTION foamlab_private.town_board_api(operation text, payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
 declare who uuid:=auth.uid(); target text:=payload->>'province'; p integer:=greatest(0,least(coalesce((payload->>'page')::integer,0),10000));
 card jsonb; body_text text; mod boolean:=foamlab_private.has_role(array['admin']); request uuid; total bigint;
 begin
 if not foamlab_private.town_enabled() then raise exception '小镇暂未开放。';end if;
 if target is null or not target=any(foamlab_private.town_provinces()) then raise exception '请选择小镇。';end if;
 if operation<>'list' then
  if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) then raise exception using errcode='42501',message='请使用 GitHub 登录后留言。';end if;
  card:=foamlab_private.town_card(who);if card is null then raise exception '请先入住小镇。';end if;
  -- Serialize this author's writes to enforce the posting limit across tabs.
  perform 1 from public.foamlab_town_residents where user_id=who for update;
  if operation='post' then
   request:=(payload->>'request_id')::uuid;if request is null then raise exception '缺少请求编号。';end if;
   if not exists(select 1 from foamlab_private.town_board_messages where author_id=who and request_id=request) then
    if (select count(*) from foamlab_private.town_board_messages where author_id=who and created_at>now()-interval '1 hour')>=10 then raise exception '每小时可发布 10 条小镇留言。';end if;
    body_text:=foamlab_private.town_text(payload->>'body',500);
    insert into foamlab_private.town_board_messages(province,author_id,author_name,author_level,author_province,body,request_id)
     values(target,who,card->>'name',(card->>'level')::integer,card->>'province',body_text,request);
   end if;
  elsif operation='delete' then
   update foamlab_private.town_board_messages set hidden=true where id=(payload->>'id')::uuid and province=target and (author_id=who or mod);
   if not found then raise exception using errcode='42501',message='仅作者和管理员可以删除留言。';end if;
  else raise exception '未知操作。';end if;
 end if;
 select count(*) into total from foamlab_private.town_board_messages where province=target and not hidden;
 p:=least(p,greatest(0,ceil(total/20.0)::integer-1));
 return jsonb_build_object('total',total,'page',p,'items',coalesce((select jsonb_agg(to_jsonb(m)) from
 (select id,author_id,author_name,author_level,author_province,body,created_at,(author_id=who or mod) can_delete
 from foamlab_private.town_board_messages where province=target and not hidden order by created_at desc,id offset p*20 limit 20) m),'[]'::jsonb));
 end $function$
;


-- Existing author logs become sharing articles without changing their URLs or content.
update public.foamlab_content set kind='article' where kind='log';

create or replace function foamlab_private.is_sharing_article(c public.foamlab_content)
returns boolean language sql stable security invoker set search_path='' as $$
 select c.kind='article' and c.status in ('draft','published')
 and coalesce(c.metadata->>'admin_only','false')<>'true' and not(c.metadata ? 'canonical_path')
 and cardinality(c.section_ids)>0
 and c.section_ids <@ array(select id from public.foamlab_sections where key='sharing')
$$;
revoke all on function foamlab_private.is_sharing_article(public.foamlab_content) from public,anon;
grant execute on function foamlab_private.is_sharing_article(public.foamlab_content) to authenticated;

alter policy content_create on public.foamlab_content with check (
 foamlab_private.has_role(array['admin']) or
 (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid()) and foamlab_private.is_sharing_article(foamlab_content))
);
alter policy content_edit on public.foamlab_content using (
 foamlab_private.has_role(array['admin']) or
 (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid()) and foamlab_private.is_sharing_article(foamlab_content))
) with check (
 foamlab_private.has_role(array['admin']) or
 (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid()) and foamlab_private.is_sharing_article(foamlab_content))
);

-- New destinations accept articles/questions through their separate schemas.
create or replace function foamlab_private.community_kind_guard()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user='authenticated' and not foamlab_private.has_role(array['admin']) and ((tg_op='INSERT' and new.pinned) or (tg_op='UPDATE' and new.pinned is distinct from old.pinned)) then
  raise exception using errcode='42501',message='只有管理员可以置顶或取消置顶文章。';
 end if;
 if new.kind<>'article' and exists(select 1 from public.foamlab_sections s where s.id=any(new.section_ids) and s.key='sharing') then
  raise exception using errcode='23514',message='实践与分享只接收文章。';
 end if;
 if exists(select 1 from public.foamlab_sections s where s.id=any(new.section_ids) and s.key='community') then
  raise exception using errcode='23514',message='讨论中心只接收问题，请使用提问入口。';
 end if;
 return new;
end $$;
create trigger b_community_kind_guard before insert or update on public.foamlab_content
for each row execute function foamlab_private.community_kind_guard();

-- Only a message's owner or an admin can remove it; blocked users cannot write.
alter policy messages_delete on public.foamlab_messages using (
 foamlab_private.has_role(array['admin']) or (author_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']))
);

-- Private like identities; clients receive aggregate counts and their own state only.
create table foamlab_private.community_likes (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 content_id uuid references public.foamlab_content(id) on delete cascade,
 thread_id uuid references public.foamlab_threads(id) on delete cascade,
 message_id uuid references public.foamlab_messages(id) on delete cascade,
 created_at timestamptz not null default now(),
 constraint community_like_one_target check(num_nonnulls(content_id,thread_id,message_id)=1)
);
alter table foamlab_private.community_likes enable row level security;
revoke all on foamlab_private.community_likes from public,anon,authenticated;
create unique index community_likes_content on foamlab_private.community_likes(content_id,user_id) where content_id is not null;
create unique index community_likes_thread on foamlab_private.community_likes(thread_id,user_id) where thread_id is not null;
create unique index community_likes_message on foamlab_private.community_likes(message_id,user_id) where message_id is not null;
create index community_likes_user on foamlab_private.community_likes(user_id);

create or replace function foamlab_private.community_like_visible(target_kind text,target_id uuid)
returns boolean language sql stable security invoker set search_path='' as $$
 select case target_kind
 when 'article' then exists(select 1 from public.foamlab_content c where c.id=target_id and c.kind='article' and c.status='published' and coalesce(c.metadata->>'admin_only','false')<>'true')
 when 'question' then exists(select 1 from public.foamlab_threads t where t.id=target_id and t.status<>'hidden')
 when 'comment' then exists(select 1 from public.foamlab_messages m where m.id=target_id and m.status='visible' and (
  exists(select 1 from public.foamlab_threads t where t.id=m.thread_id and t.status<>'hidden') or
  exists(select 1 from public.foamlab_content c where c.id=m.content_id and c.status='published' and c.comments_enabled and coalesce(c.metadata->>'admin_only','false')<>'true')))
 else false end
$$;

create or replace function foamlab_private.community_like_state(targets jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare answer jsonb; who uuid:=auth.uid();
begin
 if jsonb_typeof(targets) is distinct from 'array' or jsonb_array_length(targets)>200 then
  raise exception '每次最多读取 200 条点赞记录。';
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('kind',t.kind,'id',t.id,'count',likes.n,'liked',likes.mine)),'[]'::jsonb) into answer
 from (select distinct x.kind,x.id from jsonb_to_recordset(targets) as x(kind text,id uuid)) t
 cross join lateral (
  select count(*) as n,coalesce(bool_or(l.user_id=who),false) as mine
  from foamlab_private.community_likes l where
  (t.kind='article' and l.content_id=t.id) or (t.kind='question' and l.thread_id=t.id) or (t.kind='comment' and l.message_id=t.id)
 ) likes where foamlab_private.community_like_visible(t.kind,t.id);
 return answer;
end $$;

create or replace function foamlab_private.community_set_like(target_kind text,target_id uuid,liked boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid();
begin
 if who is null or not foamlab_private.has_github_identity() or foamlab_private.has_role(array['blocked']) then
  raise exception using errcode='42501',message='请使用 GitHub 登录后点赞。';
 end if;
 if liked is null or not foamlab_private.community_like_visible(target_kind,target_id) then
  raise exception using errcode='42501',message='这条内容暂不可点赞。';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(who::text||target_kind||target_id::text,0));
 if liked then
  insert into foamlab_private.community_likes(user_id,content_id,thread_id,message_id)
  values(who,case when target_kind='article' then target_id end,case when target_kind='question' then target_id end,case when target_kind='comment' then target_id end)
  on conflict do nothing;
 else
  delete from foamlab_private.community_likes l where l.user_id=who and
  ((target_kind='article' and l.content_id=target_id) or (target_kind='question' and l.thread_id=target_id) or (target_kind='comment' and l.message_id=target_id));
 end if;
 return foamlab_private.community_like_state(jsonb_build_array(jsonb_build_object('kind',target_kind,'id',target_id)))->0;
end $$;

create or replace function public.foamlab_like_counts(targets jsonb)
returns jsonb language sql stable security invoker set search_path='' as $$
 select foamlab_private.community_like_state(targets)
$$;
create or replace function public.foamlab_set_like(target_kind text,target_id uuid,liked boolean)
returns jsonb language sql security invoker set search_path='' as $$
 select foamlab_private.community_set_like(target_kind,target_id,liked)
$$;
revoke all on function foamlab_private.community_like_visible(text,uuid) from public,anon,authenticated;
revoke all on function foamlab_private.community_like_state(jsonb) from public,anon,authenticated;
revoke all on function foamlab_private.community_set_like(text,uuid,boolean) from public,anon,authenticated;
revoke all on function public.foamlab_like_counts(jsonb) from public,anon,authenticated;
revoke all on function public.foamlab_set_like(text,uuid,boolean) from public,anon,authenticated;
grant execute on function foamlab_private.community_like_state(jsonb),public.foamlab_like_counts(jsonb) to anon,authenticated;
grant execute on function foamlab_private.community_set_like(text,uuid,boolean),public.foamlab_set_like(text,uuid,boolean) to authenticated;

-- Existing resource categories become editable directory modules.
do $$
declare group_row record; child_id uuid;
begin
 for group_row in
  select s.id parent_id,s.key,c.track from public.foamlab_sections s join public.foamlab_content c on s.id=any(c.section_ids)
  where s.key in ('resource','recommendation') and c.kind=s.key and c.track<>'' group by s.id,s.key,c.track
 loop
  insert into public.foamlab_sections(key,name,parent_id,nav_group,sort_order)
  values('resources-'||md5(group_row.key||':'||group_row.track),group_row.track,group_row.parent_id,'资源与社区',100)
  on conflict(key) do update set name=excluded.name returning id into child_id;
  update public.foamlab_content c set section_ids=array(select distinct x from unnest(array_replace(c.section_ids,group_row.parent_id,child_id)) x)
  where group_row.parent_id=any(c.section_ids) and c.kind=group_row.key and c.track=group_row.track;
 end loop;
end $$;
update public.foamlab_sections set description='提出 OpenFOAM 使用与计算中的问题，登录后即可提问和回答。' where key='community';
update public.foamlab_sections set description='分享计算案例、技术文章与研究笔记，登录后即可发布自己的文章。' where key='sharing';
update public.foamlab_threads set category='其他问题' where category='经验交流';
notify pgrst,'reload schema';
