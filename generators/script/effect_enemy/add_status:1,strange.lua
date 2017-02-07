python[[
duration = random.randint(20, 60)
damage = random.uniform(0.5, 2.0)
VALID_STATUS = [
    "AddPoison(nil, {0}, {1:.2f})",
    "AddFreeze(nil, {0})--{1}",
    "AddSlowing(nil, {0}, 0.5, Color(0.5, 0.5, 0.5, 1.0, 0, 0, 0))--{1}",
    "AddCharmed ({0})--{1}",
    "AddConfusion(nil, {0}, false)--{1}",
    "AddMidasFreeze(nil, {0})--{1}",
    "AddFear(nil, {0})--{1}",
    "AddBurn(nil, {0}, {1:.2f})",
    "AddShrink(nil, {0})--{1}",
]
status = random.choice(VALID_STATUS)
gen.writeln("enemy:" + status.format(duration, damage))
]]
