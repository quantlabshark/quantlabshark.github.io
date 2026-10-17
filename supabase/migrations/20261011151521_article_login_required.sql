begin;

-- Keep public catalogs readable without granting access to the article body.
revoke select on public.foamlab_content from anon, public;
revoke select (body) on public.foamlab_content from anon, public;
grant select (id, slug, kind, title, summary, track, series, author_id,
    author_name, status, sort_order, comments_enabled, cover_url, metadata,
    revision, created_at, updated_at, published_at, section_ids, pinned)
    on public.foamlab_content to anon;

alter policy content_read on public.foamlab_content to authenticated
using (
    not coalesce(((select auth.jwt())->>'is_anonymous')::boolean, false)
    and (
        foamlab_private.has_role(array['admin'::text])
        or (coalesce(metadata->>'admin_only', 'false') <> 'true'
            and (status = 'published' or author_id = (select auth.uid())))
    )
);
drop policy if exists content_catalog_read on public.foamlab_content;
create policy content_catalog_read on public.foamlab_content for select to anon
using (status = 'published' and coalesce(metadata->>'admin_only', 'false') <> 'true');

-- Full-text search returns article excerpts and therefore also needs login.
revoke execute on function public.foamlab_search_content(text),
    public.foamlab_search_content_context(text),
    public.foamlab_search_content_scoped(text, text) from public, anon;
grant execute on function public.foamlab_search_content(text),
    public.foamlab_search_content_context(text),
    public.foamlab_search_content_scoped(text, text) to authenticated;

create or replace function public.foamlab_search_catalog(query text, section_key text default null)
returns table(slug text, title text, kind text, excerpt text, introduction text,
    section_ids uuid[], file_path text, canonical_path text)
language sql stable security invoker set search_path = ''
as $function$
    with recursive visible_sections as (
        select s.id, s.key, s.parent_id from public.foamlab_sections s
        where s.parent_id is null and s.visible
        union all
        select s.id, s.key, s.parent_id from public.foamlab_sections s
        join visible_sections p on s.parent_id = p.id where s.visible
    ), scope as (
        select s.id from visible_sections s where s.key = section_key
        union all
        select s.id from visible_sections s join scope p on s.parent_id = p.id
    ), terms as (
        select lower(btrim(query)) as phrase,
            regexp_split_to_array(lower(btrim(query)), '\s+') as words
        where char_length(btrim(query)) between 1 and 120
    )
    select c.slug, c.title, c.kind, c.summary, c.summary, c.section_ids,
        coalesce(c.metadata->>'file_path', ''), coalesce(c.metadata->>'canonical_path', '')
    from public.foamlab_content c cross join terms t
    where c.status = 'published' and coalesce(c.metadata->>'admin_only', 'false') <> 'true'
        and (nullif(section_key, '') is null or c.section_ids && array(select id from scope))
        and not exists (select 1 from unnest(t.words) w
            where strpos(lower(c.title || ' ' || c.summary || ' ' || c.track || ' ' || c.series), w) = 0)
    order by (strpos(lower(c.title), t.phrase) > 0) desc, c.sort_order, c.slug
    limit 40
$function$;
revoke all on function public.foamlab_search_catalog(text, text) from public;
grant execute on function public.foamlab_search_catalog(text, text) to anon, authenticated;

notify pgrst, 'reload schema';
commit;
