python[[gen.inc_var("value", 1)]]
for _, entity in pairs(Isaac.GetRoomEntities()) do
    local distance = python[[gen.writeln("{}".format(random.randint(70, 140)))]]
    if entity:IsVulnerableEnemy() and player.Position:DistanceSquared(entity.Position) < distance^2 then
        local enemy = entity:ToNPC()
        local pos = enemy.Position
        python[[
duration = random.randint(3, 10)
damage = random.uniform(0.5, 1.5)
VALID_STATUS = [
    "AddPoison(EntityRef(player), {0}, {1:.2f})",
    "AddSlowing(EntityRef(player), {0}, 0.5, Color(0.5, 0.5, 0.5, 1.0, 0, 0, 0))--{1}",
    "AddCharmed ({0})--{1}",
    "AddConfusion(EntityRef(player), {0}, false)--{1}",
    "AddFear(EntityRef(player), {0})--{1}",
    "AddBurn(EntityRef(player), {0}, {1:.2f})",
    "AddShrink(EntityRef(player), {0})--{1}",
]
status = random.choice(VALID_STATUS)
gen.writeln("enemy:" + status.format(duration, damage))
        ]]

    end
end
