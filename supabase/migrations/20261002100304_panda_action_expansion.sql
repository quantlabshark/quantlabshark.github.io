-- Existing pets keep their XP, outfit, chosen action and settings.
update foamlab_private.pet_items set required_level=1, description='先缩成一团，再轻轻滚一圈。' where id='roll';
update foamlab_private.pet_items set required_level=1, title='踢踏舞', description='左右踢踢脚，跟着节奏摆摆手。' where id='dance';
insert into foamlab_private.pet_items(id,category,title,description,required_level) values
 ('crawl','action','慢慢爬','四只爪子交替迈步，慢慢挪到旁边。',1),
 ('sing','action','唱首小曲','抱着话筒哼一小段旋律。',1),
 ('stretch','action','伸懒腰','举起双爪，舒展一下身体。',1),
 ('munch','action','吃竹子','抱起竹叶，小口嚼一嚼。',2),
 ('sway','action','摇摆舞','举起双爪，向左向右摇摆。',2),
 ('cheer','action','举爪欢呼','开心地跳起来，给你加油。',4),
 ('spin','action','转圈舞','张开双臂，轻快地转两个圈。',5)
on conflict(id) do update set title=excluded.title,description=excluded.description,required_level=excluded.required_level;
