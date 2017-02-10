python[[gen.genstate.add_descriptors(["Status"])]]
python[[
gen.chance(3, 0.5, 1)
duration = random.randint(20, 60)
damage = random.uniform(0.5, 2.0)
VALID_STATUS = [
    ("Poison", "AddPoison(EntityRef(player), {0}, {1:.2f})"),
    ("Freeze", "AddFreeze(EntityRef(player), {0})--{1}"),
    ("Slowing", "AddSlowing(EntityRef(player), {0}, 0.5, Color(0.5, 0.5, 0.5, 1.0, 0, 0, 0))--{1}"),
    ("Charmed", "AddCharmed ({0})--{1}"),
    ("Confusion", "AddConfusion(EntityRef(player), {0}, false)--{1}"),
    ("Fear", "AddFear(EntityRef(player), {0})--{1}"),
    ("Burn", "AddBurn(EntityRef(player), {0}, {1:.2f})"),
    ("Shrink", "AddShrink(EntityRef(player), {0})--{1}"),
]
status = random.choice(VALID_STATUS)
gen.writeln("enemy:" + status[1].format(duration, damage))
gen.genstate.add_descriptor(status[0].title())
]]
