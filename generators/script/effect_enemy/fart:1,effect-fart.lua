python[[gen.genstate.add_descriptors(["Gas", "Gassy", "Fart", "Smell"])]]
do
python[[gen.chance(8, 0.5, 1)]]
    local game = Game()
    python[[
FART_TYPES = [1, 1, 1, 2, 2, 3]
fart = random.choice(FART_TYPES)
if fart == 1:
    gen.writeln("game:Fart(pos, 48, nil, 1, 0)")
elif fart == 2:
    gen.writeln("game:ButterBeanFart(pos, 48, nil, true)")
else:
    gen.writeln("game:CharmFart(pos, 48, nil)")
]]
end
