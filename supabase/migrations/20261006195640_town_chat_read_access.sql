-- The base town switch is intentionally private. Expose a narrow read predicate
-- for chat RLS instead of granting callers access to the underlying helper.
create function foamlab_private.town_chat_enabled() returns boolean
language sql stable security definer set search_path='' as $$
 select foamlab_private.town_enabled()
$$;
revoke all on function foamlab_private.town_chat_enabled() from public,anon,authenticated;
grant execute on function foamlab_private.town_chat_enabled() to anon,authenticated;
alter policy town_chat_read on public.foamlab_town_chat_messages
using ((select foamlab_private.town_chat_enabled()) and foamlab_private.town_chat_visible(author_id));
