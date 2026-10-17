-- Enrich the ranked matches without changing the legacy four-column RPC.
create function public.foamlab_search_content_context(query text)
returns table(slug text,title text,kind text,excerpt text,introduction text,section_ids uuid[],file_path text,canonical_path text)
language sql stable security invoker set search_path='' as $$
 select r.slug,r.title,r.kind,r.excerpt,
  left(coalesce(nullif(btrim(case
   when c.metadata->>'format'='html' or c.body ~ '^\s*<(p|h[1-6]|div|section)' then
    (regexp_match(c.body,'<p(?:\s[^>]*)?>(.*?)</p>','is'))[1]
   else (select btrim(paragraph) from regexp_split_to_table(c.body,E'\r?\n[ \t]*\r?\n') with ordinality p(paragraph,n)
     where btrim(paragraph)<>'' and btrim(paragraph)!~ '^(#{1,6}\s|```|~~~|!\[|<|\|)' order by n limit 1)
   end),''),nullif(btrim(c.summary),''),''),2000),
  c.section_ids,
  coalesce(nullif(c.metadata->>'file_path',''),(regexp_match(c.body,'位置[：:]\s*<code>([^<]+)</code>','i'))[1],''),
  coalesce(c.metadata->>'canonical_path','')
 from public.foamlab_search_content(query) with ordinality r(slug,title,kind,excerpt,n)
 join public.foamlab_content c on c.slug=r.slug
 where c.status='published' and coalesce(c.metadata->>'admin_only','false')<>'true'
 order by r.n
$$;
revoke all on function public.foamlab_search_content_context(text) from public;
grant execute on function public.foamlab_search_content_context(text) to anon,authenticated;
