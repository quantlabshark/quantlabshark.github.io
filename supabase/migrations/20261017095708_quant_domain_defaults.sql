alter table public.foamlab_threads alter column version set default 'Python';
alter table public.foamlab_pets alter column name set default '小鲨';
update public.foamlab_settings set value='"off"'::jsonb where key='town_enabled';
