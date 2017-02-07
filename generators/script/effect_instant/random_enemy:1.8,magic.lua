python[[gen.inc_var("value", 1)]]
local enemies = {}
for _, entity in pairs(Isaac.GetRoomEntities()) do
    if entity:IsVulnerableEnemy() then
        local enemy = entity:ToNPC()
        table.insert(enemies, enemy)
    end
end
if #enemies > 0 then
	local enemy = enemies[math.random(1, #enemies)]
	local pos = enemy.Position
	python[[
gen.include("effect_enemy")
	]]
end
