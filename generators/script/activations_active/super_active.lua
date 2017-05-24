python[[gen.genstate.add_descriptors(["Reusable", "Active"])]]
on_usage = function(self, player, rng)
	local pos = player.Position
	python[[
got = gen.include("permanent_bad")
exclude = []
if got == "take_health":
	exclude.append("give_health")
gen.include("permanent_good")
]]
end
