do
    if math.random()*math.max(1, 11-player.Luck) > 1 then return end
    local game = Game()
    python[[
FART_TYPES = [1, 1, 1, 2, 2, 3]
fart = random.choice(FART_TYPES)
if fart == 1:
    gen.writeln("game:Fart(pos, 48, nil, 1, 0)")
elif fart == 2:
    gen.writeln("game:ButterBeanFart(pos, 48, nil, false)")
else:
    gen.writeln("game:CharmFart(pos, 48, nil)")
]]
end
