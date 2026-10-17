insert into foamlab_private.town_training_cases(id,theme,title) values
('cavity','层流入门','顶盖驱动方腔 · Re = 10'),
('cavity-re100','层流入门','细网格方腔 · Re = 100'),
('pitzdaily','湍流','后台阶湍流 · pitzDaily'),
('flange','传热','法兰瞬态导热'),
('scalar','标量输运','后台阶被动标量输运'),
('dambreak','多相流','水柱溃坝 · damBreak'),
('cavity-re50','层流入门','方腔流 · Re = 50'),
('cavity-re200','层流入门','细网格方腔 · Re = 200'),
('cavity-slow','层流入门','方腔流 · 半速顶盖'),
('cavity-reverse','层流入门','方腔流 · 反向顶盖'),
('pitz-sst','湍流','后台阶 · k–ω SST'),
('pitz-omega','湍流','后台阶 · k–ω'),
('pitz-realizable','湍流','后台阶 · realizable k–ε'),
('pitz-inlet5','湍流','后台阶 · 5 m/s 入口'),
('pitz-inlet20','湍流','后台阶 · 20 m/s 入口'),
('flange-slow','传热','法兰导热 · 低扩散率'),
('flange-fast','传热','法兰导热 · 高扩散率'),
('flange-warm','传热','法兰导热 · 降低热壁温度'),
('flange-preheat','传热','法兰导热 · 预热初始场'),
('flange-early','传热','法兰导热 · 初期热扩散'),
('scalar-lowdiff','标量输运','标量输运 · 弱扩散'),
('scalar-highdiff','标量输运','标量输运 · 强扩散'),
('scalar-step','标量输运','标量输运 · 延迟阶跃入口'),
('scalar-pulse','标量输运','标量输运 · 脉冲入口'),
('scalar-linear','标量输运','标量输运 · 线性抬升入口'),
('dam-low','多相流','溃坝 · 低水柱'),
('dam-high','多相流','溃坝 · 高水柱'),
('dam-wide','多相流','溃坝 · 加宽水柱'),
('dam-lowgravity','多相流','溃坝 · 半重力环境'),
('dam-early','多相流','溃坝 · 早期坍塌')
on conflict(id) do update set title=excluded.title,theme=excluded.theme;
do $$ declare def text;begin
select pg_get_functiondef('foamlab_private.town_achievements(uuid)'::regprocedure) into def;
def:=replace(def,'完成全部 6 个算例','完成全部 30 个算例');
def:=replace(def,'c.runs,6)','c.runs,30)');
execute def;
end $$;
