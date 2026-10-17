create function public.foamlab_search_content(query text)
returns table(slug text,title text,kind text,excerpt text)
language sql stable security invoker set search_path='' as $$
 select c.slug,c.title,c.kind,left(c.summary,500)
 from public.foamlab_content c
 where c.status='published' and char_length(trim(query)) between 1 and 120
 and not exists (
  select 1 from unnest(regexp_split_to_array(lower(trim(query)), '\s+')) word
  where strpos(lower(c.title || ' ' || c.summary || ' ' || c.body),word)=0
 )
 order by (strpos(lower(c.title),lower(trim(query)))>0) desc,c.sort_order
 limit 40
$$;
revoke all on function public.foamlab_search_content(text) from public;
grant execute on function public.foamlab_search_content(text) to anon,authenticated;
