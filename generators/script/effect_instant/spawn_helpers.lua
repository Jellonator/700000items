python[[
if random.random() < 0.4:
    gen.writeln("player:AddBlueSpider(pos)")
else:
    gen.writeln("player:AddBlueFlies(1, pos, nil)")
]]
