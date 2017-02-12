python[[gen.inc_var("value", 1)]]
python[[gen.genstate.add_descriptors(["Aura", "Close"])]]
for _, entity in pairs(Isaac.GetRoomEntities()) do
    local distance = python[[gen.writeln("{}".format(random.randint(80, 110)))]]
    if entity:IsVulnerableEnemy() and player.Position:DistanceSquared(entity.Position) < distance^2 then
        local enemy = entity:ToNPC()
        local pos = enemy.Position
        python[[
duration = random.randint(3, 6)
damage = random.uniform(0.5, 1.5)
VALID_STATUS = [
    ("Poison", "AddPoison(EntityRef(player), {0}, {1:.2f})"),
    ("Slow", "AddSlowing(EntityRef(player), {0}, 0.5, Color(0.5, 0.5, 0.5, 1.0, 0, 0, 0))--{1}"),
    ("Charm", "AddCharmed ({0})--{1}"),
    ("Confusion", "AddConfusion(EntityRef(player), {0}, false)--{1}"),
    ("Fear", "AddFear(EntityRef(player), {0})--{1}"),
    ("Burn", "AddBurn(EntityRef(player), {0}, {1:.2f})"),
    ("Shrink", "AddShrink(EntityRef(player), {0})--{1}"),
]
status = random.choice(VALID_STATUS)
gen.writeln("enemy:" + status[1].format(duration, damage))
gen.genstate.add_descriptor(status[0].title())
        ]]

    end
end
