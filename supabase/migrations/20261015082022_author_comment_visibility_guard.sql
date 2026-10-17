-- Apply the reading boundary to DELETE itself, including requests without
-- RETURNING or a row filter, which need not invoke the SELECT policies.
alter policy messages_delete on public.foamlab_messages using (
 foamlab_private.has_role(array['admin'])
 or (author_id=(select auth.uid()) and not foamlab_private.has_role(array['blocked']))
 or (
  foamlab_private.has_role(array['editor','moderator']) and status='visible'
  and (
   exists(select 1 from public.foamlab_content c
          where c.id=foamlab_messages.content_id and c.status='published')
   or exists(select 1 from public.foamlab_threads t
             where t.id=foamlab_messages.thread_id and t.status<>'hidden')
  )
 )
);
