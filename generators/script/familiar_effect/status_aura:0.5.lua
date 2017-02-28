for _, entity in pairs(Isaac.GetRoomEntities()) do
    if entity:IsVulnerableEnemy() then
        local enemy = entity:ToNPC()
        if are_entities_near(enemy, familiar, 100) then
            python[[
duration = 2
damage = "{:.2f}".format(random.uniform(3.0, 4.2))
VALID_STATUS = [
    ("Poison", "AddPoison(EntityRef(player), {0}, {1})"),
    ("Slow", "AddSlowing(EntityRef(player), {0}, 0.5, Color(0.5, 0.5, 0.5, 1.0, 0, 0, 0))--{1}"),
    ("Charm", "AddCharmed ({0})--{1}"),
    ("Confusion", "AddConfusion(EntityRef(player), {0}, false)--{1}"),
    ("Fear", "AddFear(EntityRef(player), {0})--{1}"),
    ("Burn", "AddBurn(EntityRef(player), {0}, {1})"),
    ("Shrink", "AddShrink(EntityRef(player), {0})--{1}"),
]
status = random.choice(VALID_STATUS)
gen.writeln("enemy:" + status[1].format(duration, damage))
gen.genstate.add_descriptor(status[0].title())
            ]]
        end
    end
end
