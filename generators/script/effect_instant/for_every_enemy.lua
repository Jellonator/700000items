for _, enemy in pairs(Isaac.GetRoomEnemies()) do
    local pos = enemy.Position
    python[[
gen.include("effect_enemy")
    ]]
end
