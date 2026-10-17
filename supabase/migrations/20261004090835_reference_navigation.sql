-- Reparent existing nodes: ids and article placements are preserved.
insert into public.foamlab_sections(key,name,href,nav_group,sort_order,visible)
values('quick-reference','速查手册','/quick-reference/','学习空间',190,true)
on conflict(key) do update set name=excluded.name,href=excluded.href;
update public.foamlab_sections set parent_id=(select id from public.foamlab_sections where key='quick-reference'),sort_order=case key when 'commands' then 10 when 'dictionaries' then 20 when 'function-objects' then 30 else 50 end
where key in ('commands','dictionaries','function-objects','reference');
insert into public.foamlab_sections(key,name,parent_id,href,nav_group,sort_order,visible)
select 'boundary-conditions','边界条件速查',id,'/boundary-conditions/','学习空间',40,true
from public.foamlab_sections where key='quick-reference'
on conflict(key) do update set name=excluded.name,parent_id=excluded.parent_id,href=excluded.href;
insert into public.foamlab_sections(key,name,parent_id,href,nav_group,sort_order,visible)
select 'boundary-conditions-'||x.key,x.name,s.id,'/boundary-conditions/?field='||x.key,'学习空间',x.ord,true
from public.foamlab_sections s cross join (values
 ('velocity','速度 U',1),('pressure','压力 p / p_rgh',2),('temperature','温度 T',3),
 ('turbulence','湍流字段',4),('phase','相分数 α',5),('geometry','几何与耦合',6)
) x(key,name,ord) where s.key='boundary-conditions'
on conflict(key) do update set name=excluded.name,parent_id=excluded.parent_id,href=excluded.href;

update public.foamlab_sections set name=case key when 'commands' then '命令速查' when 'dictionaries' then '配置与字典速查' when 'function-objects' then '函数对象速查' else '参考手册' end where key in ('commands','dictionaries','function-objects','reference');
