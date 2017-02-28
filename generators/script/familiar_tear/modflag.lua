python[[
for i in range(3):
    if i == 0 or random.random() < 0.25:
        effect = choose_random_tearflag();
        chance = get_tearflag_chance(effect)
        if chance < 1:
            gen.writeln("if math.random() < {} then".format(chance))
        gen.writeln("tear.TearFlags = tear.TearFlags | {}".format(effect))
        if chance < 1:
            gen.writeln("end")
]]
