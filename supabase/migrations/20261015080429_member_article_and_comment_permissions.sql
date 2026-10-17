-- Owners can remove their sharing articles through the existing recycle bin.
-- Archived or administrator-managed content remains outside these permissions.
create or replace function foamlab_private.is_sharing_article(c public.foamlab_content)
returns boolean language sql stable security invoker set search_path='' as $$
 select c.kind='article' and c.status in ('draft','published','trash')
 and coalesce(c.metadata->>'admin_only','false')<>'true' and not(c.metadata ? 'canonical_path')
 and cardinality(c.section_ids)>0
 and c.section_ids <@ array(select id from public.foamlab_sections where key='sharing')
$$;

alter policy content_create on public.foamlab_content with check (
 foamlab_private.has_role(array['admin']) or
 (not foamlab_private.has_role(array['blocked']) and author_id=(select auth.uid())
  and status in ('draft','published') and foamlab_private.is_sharing_article(foamlab_content))
);

-- Ordinary authors may remove comments, but cannot edit another person's text.
-- The existing UPDATE, parent visibility and reading-access policies still apply.
alter policy messages_delete on public.foamlab_messages using (
 foamlab_private.has_role(array['admin','editor','moderator']) or
 (author_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']))
);
