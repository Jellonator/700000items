python[[
for i in range(3):
    if i == 0 or random.random() < 0.2:
        effect = choose_random_tearflag();
        chance = get_tearflag_chance(effect)
        color = get_tearflag_color(effect)
        variant = get_tearflag_variant(effect)
        if chance < 1:
            gen.writeln("if math.random() < {} then".format(chance))
        gen.writeln("tear.TearFlags = tear.TearFlags | {}".format(effect))
        if color:
            gen.writeln("if tear.Color then tear.Color = {} else Isaac.DebugString(\"No colorino :/\") end".format(color))
        if variant:
            gen.writeln("tear:ChangeVariant({})".format(variant))
        if chance < 1:
            gen.writeln("end")
gen.writeln("tear:ResetSpriteScale()")
]]
