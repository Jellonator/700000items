python[[
POSSIBLE_SHOOTS = [
    "player:FireTear({0}, {1}, true, false, false)",
    "player:FireBomb({0}, {1})",
    "player:FireBrimstone({1})--{0}",
    "player:FireTechLaser({0}, LaserOffset.LASER_TECH1_OFFSET, {1}, true, false)",
    "player:FireTechXLaser({0}, {1}, 32)",
]
shooty = random.choice(POSSIBLE_SHOOTS)
gen.writeln(shooty.format("pos", "player:GetAimDirection() * 6 * player.ShotSpeed"))
]]
