-- if math.random()*math.max(1.1, 12 - player.Luck) > 1 then return end
python[[
rng = random.uniform(0.4, 0.8)#Between 40% and 80% chance of success
gen.writeln("if math.random()*inf_norm_positive(player.Luck, 5) > {:.2f} then".format(rng))
gen.writeln("\treturn".format(rng))
gen.writeln("end".format(rng))
]]
