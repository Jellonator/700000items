python[[
if random.random() < 0.4:
    gen.writeln("player:AddBlueSpider(pos)")
    gen.genstate.add_descriptors(["Spider"])
else:
    gen.writeln("player:AddBlueFlies(math.random(1, 3), pos, nil)")
    gen.genstate.add_descriptors(["Fly"])
]]
