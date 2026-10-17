-- Public messages contain only the author's public town identity. Writes go
-- through the authenticated RPC so names, levels and timestamps cannot be forged.
create table public.foamlab_town_chat_messages (
 id bigint generated always as identity primary key,
 author_id uuid not null references auth.users(id) on delete cascade,
 client_id uuid not null,
 channel text not null check (channel='world' or channel=any(foamlab_private.town_provinces())),
 body text not null check (char_length(body) between 1 and 500 and body ~ '[^[:space:]]'),
 display_name text not null,
 level integer not null,
 province text,
 created_at timestamptz not null default now(),
 unique(author_id,client_id)
);
create index town_chat_channel_recent on public.foamlab_town_chat_messages(channel,id desc);
create index town_chat_author_recent on public.foamlab_town_chat_messages(author_id,created_at desc);
alter table public.foamlab_town_chat_messages enable row level security;
revoke all on public.foamlab_town_chat_messages from anon,authenticated;
grant select on public.foamlab_town_chat_messages to anon,authenticated;

create function foamlab_private.town_chat_visible(who uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select not exists(select 1 from public.foamlab_roles where user_id=who and role='blocked')
$$;
revoke all on function foamlab_private.town_chat_visible(uuid) from public,anon,authenticated;
grant execute on function foamlab_private.town_chat_visible(uuid) to anon,authenticated;
create policy town_chat_read on public.foamlab_town_chat_messages for select to anon,authenticated
using ((select foamlab_private.town_enabled()) and foamlab_private.town_chat_visible(author_id));

create function public.foamlab_town_chat_history(channel text) returns jsonb
language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(m) order by m.id),'[]'::jsonb)
 from (select id,author_id,channel,body,display_name,level,province,created_at
       from public.foamlab_town_chat_messages where channel=$1 order by id desc limit 80) m
$$;
revoke all on function public.foamlab_town_chat_history(text) from public,anon,authenticated;
grant execute on function public.foamlab_town_chat_history(text) to anon,authenticated;

create function foamlab_private.town_chat_send(channel text,body text,client_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); target text:=channel; message text:=btrim(body);
 sent public.foamlab_town_chat_messages; last_sent timestamptz;
begin
 if who is null then raise exception '登录后就可以和大家聊天。'; end if;
 if foamlab_private.has_role(array['blocked']) then raise exception '当前账号暂时无法发言。'; end if;
 if not foamlab_private.town_enabled() then raise exception '小镇正在整理，请稍后再来。'; end if;
 if target is null or not (target='world' or target=any(foamlab_private.town_provinces())) then
  raise exception '请选择世界聊天或当前小镇。';
 end if;
 if message is null or char_length(message) not between 1 and 500 or message !~ '[^[:space:]]' then
  raise exception '请输入 1～500 字的消息，也可以发送表情。';
 end if;
 if client_id is null then raise exception '发送信息不完整，请重试。'; end if;
 -- Serialize sends from the same account, including separate tabs.
 perform pg_advisory_xact_lock(hashtextextended(who::text,771));
 select * into sent from public.foamlab_town_chat_messages m where m.author_id=who and m.client_id=$3;
 if found then
  if sent.channel<>target or sent.body<>message then raise exception '请重新发送这条消息。'; end if;
  return to_jsonb(sent)-'client_id';
 end if;
 select max(created_at) into last_sent from public.foamlab_town_chat_messages where author_id=who;
 if last_sent>clock_timestamp()-interval '2 seconds' then raise exception '发得有点快，稍等两秒再发送。'; end if;
 insert into public.foamlab_town_chat_messages(author_id,client_id,channel,body,display_name,level,province)
 values(who,$3,target,message,
  coalesce((select nullif(town_name,'') from public.foamlab_town_residents where user_id=who),
   (select nullif(display_name,'') from public.foamlab_public_profiles where user_id=who),'鲨鱼邻居'),
  foamlab_private.pet_level(coalesce((select xp from public.foamlab_pets where user_id=who),0)),
  (select province from public.foamlab_town_residents where user_id=who)) returning * into sent;
 return to_jsonb(sent)-'client_id';
end $$;
create function public.foamlab_town_chat_send(channel text,body text,client_id uuid) returns jsonb
language sql security invoker set search_path='' as $$
 select foamlab_private.town_chat_send(channel,body,client_id)
$$;
revoke all on function foamlab_private.town_chat_send(text,text,uuid),public.foamlab_town_chat_send(text,text,uuid) from public,anon,authenticated;
grant execute on function foamlab_private.town_chat_send(text,text,uuid),public.foamlab_town_chat_send(text,text,uuid) to authenticated;

-- A map visitor is still online. Keep this heartbeat separate from street
-- presence, which also authorizes movement and interactions in one province.
create table foamlab_private.town_activity (
 user_id uuid primary key references public.foamlab_town_residents(user_id) on delete cascade,
 seen_at timestamptz not null default now()
);
alter table foamlab_private.town_activity enable row level security;
revoke all on foamlab_private.town_activity from public,anon,authenticated;
create function foamlab_private.town_population(touch boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid();
begin
 if not foamlab_private.town_enabled() then return jsonb_build_object('enabled',false); end if;
 if touch and who is not null and not foamlab_private.has_role(array['blocked'])
    and exists(select 1 from public.foamlab_town_residents where user_id=who) then
  insert into foamlab_private.town_activity(user_id) values(who)
  on conflict(user_id) do update set seen_at=now()
  where town_activity.seen_at<now()-interval '30 seconds';
 end if;
 return jsonb_build_object('enabled',true,
 'residents',(select count(*) from public.foamlab_town_residents r where
   not exists(select 1 from public.foamlab_roles b where b.user_id=r.user_id and b.role='blocked')),
 'online',(select count(*) from public.foamlab_town_residents r where
   not exists(select 1 from public.foamlab_roles b where b.user_id=r.user_id and b.role='blocked') and (
   exists(select 1 from foamlab_private.town_activity a where a.user_id=r.user_id and a.seen_at>now()-interval '2 minutes') or
   exists(select 1 from public.foamlab_town_presence p where p.user_id=r.user_id and p.seen_at>now()-interval '2 minutes'))));
end $$;
create function public.foamlab_town_population(touch boolean default false) returns jsonb
language sql security invoker set search_path='' as $$ select foamlab_private.town_population(touch) $$;
revoke all on function foamlab_private.town_population(boolean),public.foamlab_town_population(boolean) from public,anon,authenticated;
grant execute on function foamlab_private.town_population(boolean),public.foamlab_town_population(boolean) to anon,authenticated;

alter publication supabase_realtime add table public.foamlab_town_chat_messages;
