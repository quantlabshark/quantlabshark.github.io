-- Keep the existing RPC contract for older clients and the town library.
-- Security invoker retains content RLS. Only published, public records are searched.
create or replace function public.foamlab_search_content(query text)
returns table(slug text,title text,kind text,excerpt text)
language sql stable security invoker set search_path='' as $function$
 with terms as (
  select lower(btrim(query)) as phrase,regexp_split_to_array(lower(btrim(query)), '\s+') as words
  where char_length(btrim(query)) between 1 and 120
 ), docs as materialized (
  select c.slug,c.title,c.kind,c.summary,c.sort_order,
   replace(replace(replace(replace(replace(replace(
    case when c.metadata->>'format'='html' or c.body ~ '^\s*<(p|h[1-6]|div|section)' then
     regexp_replace(regexp_replace(regexp_replace(c.body,'<(script|style)[^>]*>.*?</\1>','','gis'),
       '<(/(p|h[1-6]|div|li|pre|tr|section|blockquote)>|br\s*/?>)',E'\n','gi'),'<[^>]+>','','g')
    else c.body end,
    '&lt;','<'),'&gt;','>'),'&quot;','"'),'&#39;',''''),'&nbsp;',' '),'&amp;','&') as plain
  from public.foamlab_content c cross join terms t
  where c.status='published' and coalesce(c.metadata->>'admin_only','false')<>'true'
   and c.slug not in ('site-maintenance','site-design')
   and (t.phrase ~ '[<>&]' or not exists(select 1 from unnest(t.words) w where strpos(lower(c.title||' '||c.summary||' '||c.body),w)=0))
 ), hits as (
  select d.*,t.phrase,t.words,
   (select count(*) from unnest(t.words) w where strpos(lower(d.plain),w)>0) as body_hits,
   (select string_agg(line,E'\n' order by exact desc,hits desc,n) from (
    select case when pos>70 then '…' else '' end||substr(line,greatest(1,pos-70),420)||case when length(line)>greatest(1,pos-70)+419 then '…' else '' end as line,n,exact,hits
    from (
     select btrim(line) as line,min(n) as n,strpos(lower(line),t.phrase)>0 as exact,
      (select count(*) from unnest(t.words) w where strpos(lower(line),w)>0) as hits,
      (select min(nullif(strpos(lower(line),w),0)) from unnest(t.words) w) as pos
     from regexp_split_to_table(d.plain,E'\r?\n') with ordinality as l(line,n)
     where exists(select 1 from unnest(t.words) w where strpos(lower(line),w)>0)
     group by line
     order by exact desc,hits desc,min(n) limit 3
    ) matched
   ) clipped) as matches
  from docs d cross join terms t
  where not exists(select 1 from unnest(t.words) w where strpos(lower(d.title||' '||d.summary||' '||d.plain),w)=0)
 )
 select h.slug,h.title,h.kind,coalesce(h.matches,
  case when exists(select 1 from unnest(h.words) w where strpos(lower(h.summary),w)>0) then h.summary else '' end)
 from hits h
 order by (h.body_hits=cardinality(h.words)) desc,(strpos(lower(h.plain),h.phrase)>0) desc,
  h.body_hits desc,(strpos(lower(h.title),h.phrase)>0) desc,h.sort_order,h.slug
 limit 40
$function$;
revoke all on function public.foamlab_search_content(text) from public;
grant execute on function public.foamlab_search_content(text) to anon,authenticated;
