python[[gen.inc_var("value", 1)]]
do
    local _tears = {}
    local _enemies = {}
    local distance = 48
    -- Get tears and enemies
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity:IsVulnerableEnemy() then
            -- table.insert(_enemies, entity:ToNPC())
            local enemy = entity:ToNPC()
            _enemies[enemy] = enemy
        end
        if entity.Type == EntityType.ENTITY_TEAR then
            _tears[entity] = entity
        end
    end
    -- Filter out enemies not near any tears
    for enemy in pairs(_enemies) do
        local is_near = false
        for tear in pairs(_tears) do
            if are_entities_near(enemy, tear, distance) then
                is_near = true
                break
            end
        end
        if not is_near then
            _enemies[enemy] = nil
        end
    end
    -- Add status effects
    for enemy in pairs(_enemies) do
        python[[
duration = 2
damage = "{:.2f}*player.Damage".format(random.uniform(0.4, 0.7))
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
