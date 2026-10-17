begin;
alter table public.foamlab_sections add column page_content jsonb not null default '{}'::jsonb
 check (jsonb_typeof(page_content)='object'
 and page_content-'subtitle'-'body'='{}'::jsonb
 and (not page_content ? 'subtitle' or (jsonb_typeof(page_content->'subtitle')='string' and char_length(page_content->>'subtitle')<=1000))
 and (not page_content ? 'body' or (jsonb_typeof(page_content->'body')='string' and char_length(page_content->>'body')<=30000)));
comment on column public.foamlab_sections.page_content is 'Public landing-page subtitle and Markdown introduction; independent of article bodies.';
create table foamlab_private.section_edit_leases (
 section_id uuid primary key references public.foamlab_sections(id) on delete cascade,
 owner_id uuid not null references auth.users(id) on delete cascade,
 token uuid not null,
 started_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null
);
alter table foamlab_private.section_edit_leases enable row level security;
revoke all on foamlab_private.section_edit_leases from public,anon,authenticated;
create policy edit_leases_closed on foamlab_private.section_edit_leases for all to anon,authenticated using(false) with check(false);

create function foamlab_private.section_edit_lease(section_id_value uuid,token_value uuid,action_value text)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare who uuid:=auth.uid(); lease foamlab_private.section_edit_leases; acquired boolean:=false; holder text;
begin
 if who is null or not foamlab_private.has_role(array['admin']) then raise exception using errcode='42501',message='只有管理员可以占用文档编辑。';end if;
 if section_id_value is null or token_value is null or action_value is null or action_value not in ('acquire','renew','release') then raise exception using errcode='22023',message='编辑占用参数无效。';end if;
 -- Same lock order as content writes and directory moves: journal, then rows.
 perform pg_catalog.pg_advisory_xact_lock(7402512);
 if action_value='release' then
  delete from foamlab_private.section_edit_leases where section_id=section_id_value and owner_id=who and token=token_value;
  return jsonb_build_object('released',found);
 end if;
 if not exists(select 1 from public.foamlab_sections where id=section_id_value) then raise exception using errcode='22023',message='文档已不存在，请返回列表。';end if;
 if action_value='acquire' then
  insert into foamlab_private.section_edit_leases(section_id,owner_id,token,expires_at)
  values(section_id_value,who,token_value,clock_timestamp()+interval '120 seconds')
  on conflict(section_id) do update set owner_id=excluded.owner_id,token=excluded.token,
   started_at=case when section_edit_leases.owner_id=who and section_edit_leases.token=token_value then section_edit_leases.started_at else clock_timestamp() end,
   expires_at=excluded.expires_at
  where section_edit_leases.expires_at<=clock_timestamp()
   or (section_edit_leases.owner_id=who and section_edit_leases.token=token_value)
   or not exists(select 1 from public.foamlab_roles where user_id=section_edit_leases.owner_id and role='admin');
  acquired:=found;
 else
  update foamlab_private.section_edit_leases set expires_at=clock_timestamp()+interval '120 seconds'
  where section_id=section_id_value and owner_id=who and token=token_value and expires_at>clock_timestamp();
  acquired:=found;
 end if;
 select * into lease from foamlab_private.section_edit_leases where section_id=section_id_value;
 select coalesce(nullif(pp.display_name,''),nullif(u.raw_user_meta_data->>'user_name',''),'另一位管理员') into holder
 from auth.users u left join public.foamlab_public_profiles pp on pp.user_id=u.id where u.id=lease.owner_id;
 return jsonb_build_object('acquired',acquired,'owner_name',coalesce(holder,'另一位管理员'),'started_at',lease.started_at,'expires_at',lease.expires_at);
end $function$;
revoke all on function foamlab_private.section_edit_lease(uuid,uuid,text) from public,anon,authenticated;
grant execute on function foamlab_private.section_edit_lease(uuid,uuid,text) to authenticated;
create function public.foamlab_section_edit_lease(p_section_id uuid,p_token uuid,p_action text default 'acquire')
returns jsonb language sql security invoker set search_path='' as $function$
 select foamlab_private.section_edit_lease(p_section_id,p_token,p_action);
$function$;
revoke all on function public.foamlab_section_edit_lease(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.foamlab_section_edit_lease(uuid,uuid,text) to authenticated;

create function foamlab_private.enforce_section_edit_lease() returns trigger
language plpgsql security definer set search_path='' as $function$
declare who uuid:=auth.uid(); lease foamlab_private.section_edit_leases; request_token text;
begin
 select * into lease from foamlab_private.section_edit_leases
 where section_id=old.id and expires_at>clock_timestamp()
 and exists(select 1 from public.foamlab_roles where user_id=owner_id and role='admin');
 if found and who is not null then
  request_token:=coalesce(nullif(current_setting('request.headers',true),'')::jsonb->>'x-foamlab-edit-token','');
  if who<>lease.owner_id or request_token<>lease.token::text then
   raise exception using errcode='55P03',message='此文档正在由另一编辑窗口占用，暂时不能修改或删除。';
  end if;
 end if;
 return case when tg_op='DELETE' then old else new end;
end $function$;
revoke all on function foamlab_private.enforce_section_edit_lease() from public,anon,authenticated;
create trigger ab_enforce_section_edit_lease before update or delete on public.foamlab_sections
 for each row execute function foamlab_private.enforce_section_edit_lease();

update public.foamlab_sections set page_content=jsonb_build_object('subtitle',$text$理解流动规律、数学模型与数值求解之间的联系。$text$,'body',$text$湍流理论讨论需要计算的物理量及其控制方程；有限体积法说明怎样把方程转化为网格上的代数系统。两套课程分别展开推导，并用原生 OpenFOAM v2512 程序和算例连接理论与计算。$text$) where key='theory' and page_content='{}'::jsonb;
update public.foamlab_sections set page_content=jsonb_build_object('subtitle',$text$从流体运动方程与统计描述，逐步建立湍流尺度、壁面规律和计算模型。$text$,'body',$text$从流体运动与统计描述出发，学习自由剪切流、湍流尺度和壁面规律，再进入直接数值模拟、湍流黏性模型、雷诺应力模型、概率密度函数方法与大涡模拟。张量、傅里叶分析及随机过程附录可按正文链接随时查阅。

配套计算采用 OpenCFD OpenFOAM v2512。周期涡旋、标量扩散、平板通道和均匀湍流衰减算例给出实际计算结果、误差比较及运行记录，可按正文中的代码路径复现。$text$) where key='pope' and page_content='{}'::jsonb;
update public.foamlab_sections set page_content=jsonb_build_object('subtitle',$text$从守恒定律、网格和离散方程，走到流动算法与程序实现。$text$,'body',$text$课程分为基础、离散、流动算法和应用四部分，共二十章及附录。每章依次说明物理问题、数学关系、离散过程和代码实现。

课程采用原生 OpenFOAM v2512 C++，结合配套程序、算例和交互演示，讲解面通量、扩散、时间离散与压力修正。正文中的代码路径均相对于配套包解压后的根目录。$text$) where key='fvm' and page_content='{}'::jsonb;
update public.foamlab_sections set name='基础理论与原理' where key='theory';
notify pgrst,'reload schema';
commit;
