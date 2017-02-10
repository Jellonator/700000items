python[[gen.genstate.add_descriptors(["Shoot"])]]
python[[gen.inc_var("value", 1)]]
python[[
POSSIBLE_SHOOTS = [
    ("Tear", "player:FireTear({0}, {1}, true, false, false)"),
    ("Bomb", "player:FireBomb({0}, {1})"),
    ("Brimstone", "player:FireBrimstone({1})--{0}"),
    ("Tech", "player:FireTechLaser({0}, LaserOffset.LASER_TECH1_OFFSET, {1}, true, false)"),
    ("Tech X", "player:FireTechXLaser({0}, {1}, 32)"),
]
shooty = random.choice(POSSIBLE_SHOOTS)
gen.writeln(shooty[1].format("pos", "player:GetLastDirection() * 8 * player.ShotSpeed"))
gen.genstate.add_descriptor(shooty[0].title())
]]
