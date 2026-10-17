-- Comment replies and account notifications. Existing comments stay at the top level.
alter table public.foamlab_messages add column reply_to_id uuid
 references public.foamlab_messages(id) on delete set null;
create index messages_reply_to on public.foamlab_messages(reply_to_id) where reply_to_id is not null;

create function foamlab_private.guard_message_reply() returns trigger
language plpgsql set search_path='' as $$
declare target public.foamlab_messages;
begin
 if tg_op='UPDATE' then
  if new.id<>old.id or new.author_id<>old.author_id or new.thread_id is distinct from old.thread_id or new.content_id is distinct from old.content_id then
   raise exception '评论的作者与所属页面不能修改。';
  end if;
  -- A deleted parent clears its reference through the foreign-key action.
  if new.reply_to_id is distinct from old.reply_to_id and (pg_trigger_depth()<2 or new.reply_to_id is not null) then
   raise exception '回复对象不能修改。';
  end if;
  return new;
 end if;
 if new.reply_to_id is not null then
  select * into target from public.foamlab_messages where id=new.reply_to_id and status='visible';
  if target.id is null or target.id=new.id or target.thread_id is distinct from new.thread_id or target.content_id is distinct from new.content_id then
   raise exception '请选择当前页面中可见的评论进行回复。';
  end if;
 end if;
 return new;
end $$;
revoke all on function foamlab_private.guard_message_reply() from public,anon,authenticated;
create trigger guard_message_reply before insert or update on public.foamlab_messages
 for each row execute function foamlab_private.guard_message_reply();

create table foamlab_private.reply_notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid not null references auth.users(id) on delete cascade,
 message_id uuid not null references public.foamlab_messages(id) on delete cascade,
 kind text not null check(kind in ('comment','content','thread')),
 created_at timestamptz not null default now(),
 read_at timestamptz,
 unique(recipient_id,message_id)
);
create index reply_notifications_recipient_time on foamlab_private.reply_notifications(recipient_id,created_at desc,id desc);
create index reply_notifications_unread on foamlab_private.reply_notifications(recipient_id) where read_at is null;
create index reply_notifications_message on foamlab_private.reply_notifications(message_id);
alter table foamlab_private.reply_notifications enable row level security;
revoke all on foamlab_private.reply_notifications from public,anon,authenticated;

create function foamlab_private.notify_message_reply() returns trigger
language plpgsql security definer set search_path='' as $$
declare comment_owner uuid; content_owner uuid; thread_owner uuid;
begin
 if new.status<>'visible' then return new;end if;
 select author_id into comment_owner from public.foamlab_messages where id=new.reply_to_id and status='visible';
 select author_id into content_owner from public.foamlab_content where id=new.content_id and status='published' and comments_enabled and coalesce(metadata->>'admin_only','false')<>'true';
 select author_id into thread_owner from public.foamlab_threads where id=new.thread_id and status in ('open','resolved');
 insert into foamlab_private.reply_notifications(recipient_id,message_id,kind)
 select recipient,new.id,(array['comment','content','thread'])[min(priority)]
 from (values (comment_owner,1),(content_owner,2),(thread_owner,3)) targets(recipient,priority)
 where recipient is not null and recipient<>new.author_id group by recipient
 on conflict(recipient_id,message_id) do nothing;
 return new;
end $$;
revoke all on function foamlab_private.notify_message_reply() from public,anon,authenticated;
create trigger notify_message_reply after insert on public.foamlab_messages
 for each row execute function foamlab_private.notify_message_reply();

-- This private view is consumed only by the authenticated, recipient-scoped API.
create view foamlab_private.reply_notification_feed as
select n.*,m.author_id,coalesce(nullif(p.display_name,''),'社区成员') author_name,
 left(m.body,240) excerpt,c.slug,coalesce(c.title,t.title) title,m.thread_id,m.reply_to_id
from foamlab_private.reply_notifications n
join public.foamlab_messages m on m.id=n.message_id
left join public.foamlab_content c on c.id=m.content_id
left join public.foamlab_threads t on t.id=m.thread_id
left join public.foamlab_public_profiles p on p.user_id=m.author_id
where m.status='visible' and (
 (c.status='published' and c.comments_enabled and coalesce(c.metadata->>'admin_only','false')<>'true')
 or t.status in ('open','resolved','closed')
);
revoke all on foamlab_private.reply_notification_feed from public,anon,authenticated;

create function foamlab_private.reply_notifications_api(operation text,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare who uuid:=auth.uid(); result jsonb; unread bigint; cursor_time timestamptz; cursor_id uuid;
begin
 if who is null then raise exception '请先登录。' using errcode='42501';end if;
 if operation='read' then
  update foamlab_private.reply_notifications set read_at=coalesce(read_at,now()) where recipient_id=who and id=(payload->>'id')::uuid;
 elsif operation='read_all' then
  update foamlab_private.reply_notifications n set read_at=now() where n.recipient_id=who and n.read_at is null
   and exists(select 1 from foamlab_private.reply_notification_feed f where f.id=n.id);
 elsif operation not in ('list','count') then raise exception '未知消息操作。';end if;
 select count(*) into unread from foamlab_private.reply_notification_feed where recipient_id=who and read_at is null;
 if operation='list' then
  cursor_time:=(payload->>'before_time')::timestamptz;cursor_id:=(payload->>'before_id')::uuid;
  select coalesce(jsonb_agg(to_jsonb(f)-'recipient_id' order by f.created_at desc,f.id desc),'[]'::jsonb) into result
  from (select * from foamlab_private.reply_notification_feed where recipient_id=who
   and (cursor_time is null or (created_at,id)<(cursor_time,cursor_id)) order by created_at desc,id desc limit 51) f;
 end if;
 return jsonb_build_object('unread_count',unread,'items',coalesce(result,'[]'::jsonb));
end $$;
revoke all on function foamlab_private.reply_notifications_api(text,jsonb) from public,anon;
grant execute on function foamlab_private.reply_notifications_api(text,jsonb) to authenticated;
create function public.foamlab_reply_notifications(operation text default 'list',payload jsonb default '{}') returns jsonb
language sql security invoker set search_path='' as $$
 select foamlab_private.reply_notifications_api(operation,payload)
$$;
revoke all on function public.foamlab_reply_notifications(text,jsonb) from public,anon;
grant execute on function public.foamlab_reply_notifications(text,jsonb) to authenticated;
