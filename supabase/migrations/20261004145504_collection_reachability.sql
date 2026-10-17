-- Seasonal items remain claimable in configured festival windows and gain a permanent shop route.
insert into foamlab_private.town_shop(id,price,rare) values
 ('lantern-red',60,true),('zongzi',60,true),('moon-lamp',72,true),('firework',90,true)
on conflict(id) do nothing;

-- An item unlocked by level is already owned, just as the shop displays. Count it for collection achievements.
CREATE OR REPLACE FUNCTION foamlab_private.town_achievements(who uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 with counts as (
 select (select count(distinct case_id) from foamlab_private.town_training_runs where user_id=who and step=5)::integer runs,
 (select count(distinct r.case_id) from foamlab_private.town_training_runs r join foamlab_private.town_training_cases c on c.id=r.case_id where r.user_id=who and r.step=5 and c.enabled)::integer independent_runs,
 (select count(*) from foamlab_private.town_training_cases where enabled)::integer all_runs,
 (select count(*) from foamlab_private.town_inventory i join foamlab_private.town_knowledge_cards c on i.item_id='card:'||c.id where i.user_id=who)::integer cards,
 (select count(*) from foamlab_private.town_play_events where user_id=who and kind='shoot')::integer shoots,
 (select count(*) from foamlab_private.town_shop s where s.id in (select foamlab_private.pet_unlocked(who)))::integer items,
 (select count(*) from foamlab_private.town_play_events where user_id=who and kind='daily')::integer days,
 (select count(*) from foamlab_private.town_shop s where s.rare and s.id in (select foamlab_private.pet_unlocked(who)))::integer rare
 ), badges as (
 select v.* from counts c cross join lateral (values
 ('first-run','第一份计算结果','完成 1 个实训算例','',c.runs,1),
 ('three-runs','算例探索者','完成 3 个不同算例','',c.runs,3),
 ('all-runs','实训全通关','完成全部 '||c.all_runs||' 个独立算例','',c.independent_runs,c.all_runs),
 ('first-card','湖边的发现','收集 1 张知识卡','',c.cards,1),
 ('ten-cards','知识收藏家','收集 10 张知识卡','',c.cards,10),
 ('all-cards','完整图鉴','收集 100 张知识卡','',c.cards,100),
 ('bamboo-20','竹林采集员','累计拾取 20 根竹笋','',c.shoots,20),
 ('first-item','小屋焕新','获得 1 件商店收藏','',c.items,1),
 ('rare-item','闪光收藏','获得 1 件稀有收藏','',c.rare,1),
 ('daily-3','小镇常客','完成 3 天的全部任务','',c.days,3)
 ) v(id,title,description,icon,progress,goal))
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title,'description',description,'icon',icon,'progress',least(progress,goal),'goal',goal,'unlocked',progress>=goal)),'[]'::jsonb) from badges $function$
;

