do
	local player = Mod.stats_permanant
	local flag = CacheFlag.CACHE_ALL
python[[
stats = IsaacStats()
value = 2
gen.inc_var("value", value)
stats.add_random_stats(value, 1, gen.genstate)
gen.writeln("{}\n".format(stats.gen_eval_cache()))
]]
end

_signal_refresh_cache(player)
save_output()
