-- 鲨鱼画卡: illustrated panda cards, a second collection next to the knowledge cards: 48 cards in five
-- series (日常四季, 流动之美, 节日, 十二生肖, 十二星座), 38 common, 7 rare, 3 legend.
-- Cards are inventory items 'art:<id>'. They come from the bamboo blind box (25%), fishing (25% bonus on
-- top of the knowledge card) and finishing all daily tasks (one card per day). The pictures live in the
-- site (themes/quant-lab/source/assets/town/town-cards.js); the ids below must match it.
-- Function bodies are patched in place with guarded replacements, like the earlier town migrations.

create table foamlab_private.town_art_cards(id text primary key,rarity text not null check(rarity in ('common','rare','legend')));
alter table foamlab_private.town_art_cards enable row level security;
revoke all on foamlab_private.town_art_cards from public,anon,authenticated;
insert into foamlab_private.town_art_cards(id,rarity) values
('bamboo-breakfast','common'),('lake-fishing','common'),('rainy-reading','common'),('spring-blossom','common'),
('summer-fireflies','common'),('autumn-leaves','common'),('snow-day','common'),('kite-hill','common'),
('bubble-garden','common'),('taichi-morning','common'),('mesh-workshop','common'),('residual-night','common'),
('lab-flask','common'),('photo-walk','common'),('cavity-vortex','rare'),('karman-street','rare'),
('airfoil-wind','rare'),('starry-observatory','rare'),('moon-festival','rare'),('dragon-boat','rare'),
('spring-festival','rare'),('town-portrait','legend'),('paraview-aurora','legend'),('ns-scroll','legend'),
('zodiac-rat','common'),('zodiac-ox','common'),('zodiac-tiger','common'),('zodiac-rabbit','common'),
('zodiac-dragon','common'),('zodiac-snake','common'),('zodiac-horse','common'),('zodiac-sheep','common'),
('zodiac-monkey','common'),('zodiac-rooster','common'),('zodiac-dog','common'),('zodiac-pig','common'),
('star-aries','common'),('star-taurus','common'),('star-gemini','common'),('star-cancer','common'),
('star-leo','common'),('star-virgo','common'),('star-libra','common'),('star-scorpio','common'),
('star-sagittarius','common'),('star-capricorn','common'),('star-aquarius','common'),('star-pisces','common');

-- 70% common, 24% rare, 6% legend; equal chances inside a rarity.
create function foamlab_private.town_draw_art_card() returns text language sql volatile security definer set search_path='' as $$
 with tier as materialized(select case when r<0.06 then 'legend' when r<0.30 then 'rare' else 'common' end rarity from (select random() r) x)
 select c.id from foamlab_private.town_art_cards c,tier t where c.rarity=t.rarity order by random() limit 1 $$;
revoke all on function foamlab_private.town_draw_art_card() from public,anon,authenticated;

do $migration$
declare def text;
 old_decl text:='reward_rare boolean:=false;';
 old_fish text:='reward:=jsonb_build_object(''item'',item);';
 old_box text:='if roll<0.6 then item:=''card:''||foamlab_private.town_draw_card();';
 old_daily text:='if n=1 then update foamlab_private.town_wallet set balance=balance+10,earned=earned+10 where user_id=who;end if;';
begin
 select pg_get_functiondef('foamlab_private.town_play_api(text,jsonb)'::regprocedure) into def;
 if position(old_decl in def)=0 or position(old_fish in def)=0 or position(old_box in def)=0 or position(old_daily in def)=0
 then raise exception 'Review town_play_api before adding art cards';end if;
 def:=replace(def,old_decl,'reward_rare boolean:=false; art text;');
 -- Fishing: the knowledge card as before, and one time in four a picture card as well.
 def:=replace(def,old_fish,'if random()<0.25 then art:=''art:''||foamlab_private.town_draw_art_card();insert into foamlab_private.town_inventory values(who,art,now()) on conflict do nothing;end if;reward:=jsonb_build_object(''item'',item,''art'',art);');
 -- Blind box: knowledge card 40%, picture card 25%, common item 25%, rare item 10% (rare stays at roll>=0.9).
 def:=replace(def,old_box,'if roll<0.4 then item:=''card:''||foamlab_private.town_draw_card();elsif roll<0.65 then item:=''art:''||foamlab_private.town_draw_art_card();');
 -- All daily tasks: +10 bamboo and one picture card.
 def:=replace(def,old_daily,'if n=1 then update foamlab_private.town_wallet set balance=balance+10,earned=earned+10 where user_id=who;art:=''art:''||foamlab_private.town_draw_art_card();insert into foamlab_private.town_inventory values(who,art,now()) on conflict do nothing;reward:=reward||jsonb_build_object(''daily_art'',art);end if;');
 execute def;

 select pg_get_functiondef('foamlab_private.town_play_state(uuid)'::regprocedure) into def;
 if position('''cardChance'',60,''commonChance'',30,''rareChance'',10' in def)=0 then raise exception 'Review town_play_state before adding art cards';end if;
 def:=replace(def,'''cardChance'',60,''commonChance'',30,''rareChance'',10','''cardChance'',40,''artChance'',25,''commonChance'',25,''rareChance'',10');
 execute def;

 -- Picture cards are not wardrobe items: keep them out of the "items" count used by achievements.
 select pg_get_functiondef('foamlab_private.town_achievements(uuid)'::regprocedure) into def;
 if position('item_id not like ''card:%''' in def)>0 then
  def:=replace(def,'item_id not like ''card:%''','item_id not like ''card:%'' and item_id not like ''art:%''');
  execute def;
 end if;
end $migration$;
