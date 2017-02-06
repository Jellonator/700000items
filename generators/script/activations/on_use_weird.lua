python[[gen.item.type = "active"]]
on_usage = function(self, player, rng)
	python[[
rng = random.uniform(0.1, 0.9)
gen.writeln("if math.random() < {:.2f} then".format(rng))
gen.include("effect_instant")
gen.writeln("else".format(rng))
gen.include("effect_instant")
gen.writeln("end".format(rng))
]]
end
