python[[gen.genstate.add_descriptors(["Status"])]]
python[[
base_chance = 8
duration = random.randint(20, 40)
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
if status[0] == "Freeze":
    duration //= 2
    base_chance += 2
gen.chance(base_chance, 0.6, 1)
gen.writeln("enemy:" + status[1].format(duration, damage))
gen.genstate.add_descriptor(status[0].title())
]]
