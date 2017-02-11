python[[gen.genstate.add_descriptors(["Reusable", "Active"])]]
on_usage = function(self, player, rng)
	local pos = player.Position
	python[[
gen.set_allow_random(False)
rng = random.uniform(0.1, 0.9)
gen.writeln("if math.random() < {:.2f} then".format(rng))
gen.include("effect_instant")
gen.writeln("else".format(rng))
gen.include("effect_instant")
gen.writeln("end".format(rng))
gen.set_allow_random(True)
]]
end
