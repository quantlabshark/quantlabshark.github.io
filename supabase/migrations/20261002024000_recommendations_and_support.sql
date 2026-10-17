alter table public.foamlab_content drop constraint foamlab_content_kind_check;
alter table public.foamlab_content add constraint foamlab_content_kind_check check(kind in ('course','lesson','article','log','resource','tool','module','announcement','assignment','reference','recommendation'));
insert into public.foamlab_settings(key,value) values('support','{"enabled":false,"message":"用于资料整理、计算示例核验与网站维护。","wechat_url":"","alipay_url":""}'::jsonb) on conflict(key) do nothing;
