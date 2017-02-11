python[[gen.genstate.add_descriptors(["Temporary", "Stats"])]]
python[[
gen.write_effect("""
room_change = function(self, player)
    self.is_active = false
    _signal_refresh_cache(player)
end
""")
stats = IsaacStats()
value = random.randint(2, 3)
gen.inc_var("value", value)
stats.add_random_stats(value, 1, gen.genstate)
gen.write_effect("\ttemp_stats = {}\n".format(stats.gen_eval_cache()))
gen.write_effect("""\tevaluate_cache_special = function(self, ...)
    if self.is_active then
        self:temp_stats(...)
    end
end""")
]]
self.is_active = true
_signal_refresh_cache(player)
