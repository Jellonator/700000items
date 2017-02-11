python[[gen.genstate.add_descriptors(["Reusable", "Active"])]]
on_usage = function(self, player, rng)
	local pos = player.Position
	python[[
gen.set_allow_random(False)
gen.include("effect_instant")
gen.set_allow_random(True)]]
end
