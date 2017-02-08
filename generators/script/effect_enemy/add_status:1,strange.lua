python[[
gen.chance(3, 0.5, 1)
duration = random.randint(20, 60)
damage = random.uniform(0.5, 2.0)
VALID_STATUS = [
    "AddPoison(EntityRef(player), {0}, {1:.2f})",
    "AddFreeze(EntityRef(player), {0})--{1}",
    "AddSlowing(EntityRef(player), {0}, 0.5, Color(0.5, 0.5, 0.5, 1.0, 0, 0, 0))--{1}",
    "AddCharmed ({0})--{1}",
    "AddConfusion(EntityRef(player), {0}, false)--{1}",
    "AddMidasFreeze(EntityRef(player), {0})--{1}",
    "AddFear(EntityRef(player), {0})--{1}",
    "AddBurn(EntityRef(player), {0}, {1:.2f})",
    "AddShrink(EntityRef(player), {0})--{1}",
]
status = random.choice(VALID_STATUS)
gen.writeln("enemy:" + status.format(duration, damage))
]]
