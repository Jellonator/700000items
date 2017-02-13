python[[
stats = IsaacStats()
value = 2
gen.inc_var("value", value)
stats.add_random_stats(value, -1, gen.genstate)
gen.write_effect("\tinc_stats = {}\n".format(stats.gen_eval_cache()))
gen.writeln(stats.gen_is_stat_capped())
]]
do
	local player = Mod.stats_permanant
	self:inc_stats(player, CacheFlag.CACHE_ALL)
end

_signal_refresh_cache(player)
