CREATE OR REPLACE FUNCTION public.foamlab_search_content_scoped(query text, section_key text DEFAULT NULL::text)
 RETURNS TABLE(slug text, title text, kind text, excerpt text, introduction text, section_ids uuid[], file_path text, canonical_path text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 with recursive visible_sections as (
  select s.id,s.key,s.parent_id from public.foamlab_sections s where s.parent_id is null and s.visible
  union all select s.id,s.key,s.parent_id from public.foamlab_sections s join visible_sections p on s.parent_id=p.id where s.visible
 ), scope as (
  select s.id from visible_sections s where s.key=section_key
  union all select s.id from visible_sections s join scope p on s.parent_id=p.id
 ), terms as (
  select lower(btrim(query)) as phrase,regexp_split_to_array(lower(btrim(query)), '\s+') as words
  where char_length(btrim(query)) between 1 and 120
 ), docs as materialized (
  select c.slug,c.title,c.kind,c.summary,c.sort_order,c.body,c.section_ids,c.metadata,
   replace(replace(replace(replace(replace(replace(
    case when c.metadata->>'format'='html' or c.body ~ '^\s*<(p|h[1-6]|div|section)' then
     regexp_replace(regexp_replace(regexp_replace(regexp_replace(c.body,'</(td|th)>',' | ','gi'),'<(script|style)[^>]*>.*?</\1>','','gis'),
       '<(/(p|h[1-6]|div|li|pre|tr|section|blockquote)>|br\s*/?>)',E'\n','gi'),'<[^>]+>','','g')
    else c.body end,
    '&lt;','<'),'&gt;','>'),'&quot;','"'),'&#39;',''''),'&nbsp;',' '),'&amp;','&') as plain
  from public.foamlab_content c cross join terms t
  where c.status='published' and coalesce(c.metadata->>'admin_only','false')<>'true'
   and c.slug not in ('site-maintenance','site-design')
   and (nullif(section_key,'') is null or c.section_ids && array(select id from scope))
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
  case when exists(select 1 from unnest(h.words) w where strpos(lower(h.summary),w)>0) then h.summary else '' end),
  left(coalesce(nullif(btrim(case
   when h.metadata->>'format'='html' or h.body ~ '^\s*<(p|h[1-6]|div|section)' then
    (regexp_split_to_array((regexp_split_to_array(h.body,'<p(?:\s[^>]*)?>','i'))[2],'</p>','i'))[1]
   else (select btrim(paragraph) from regexp_split_to_table(h.body,E'\r?\n[ \t]*\r?\n') with ordinality p(paragraph,n)
     where btrim(paragraph)<>'' and btrim(paragraph)!~ '^(#{1,6}\s|```|~~~|!\[|<|\|)' order by n limit 1)
   end),''),nullif(btrim(h.summary),''),''),2000),h.section_ids,coalesce(h.metadata->>'file_path',''),coalesce(h.metadata->>'canonical_path','')
 from hits h
 order by (h.body_hits=cardinality(h.words)) desc,(strpos(lower(h.plain),h.phrase)>0) desc,
  h.body_hits desc,(strpos(lower(h.title),h.phrase)>0) desc,h.sort_order,h.slug
 limit 40
$function$
;
revoke execute on function public.foamlab_search_content_scoped(text,text) from public,anon; grant execute on function public.foamlab_search_content_scoped(text,text) to authenticated;
