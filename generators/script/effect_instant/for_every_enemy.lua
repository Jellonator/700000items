python[[gen.inc_var("value", 1)]]
for _, entity in pairs(Isaac.GetRoomEntities()) do
    if entity:IsVulnerableEnemy() then
        local enemy = entity:ToNPC()
        local pos = enemy.Position
        python[[
gen.include("effect_enemy", exclude=["occasional_super"])
        ]]
    end
end
