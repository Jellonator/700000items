self.on_hit_damage = self.on_hit_damage or 0

for _, entity in pairs(Isaac.GetRoomEntities()) do
    if entity.Type == EntityType.ENTITY_PROJECTILE then
        if are_entities_near(entity, familiar, 15) then
            entity:Kill()
            self.on_hit_damage = self.on_hit_damage - 1
        end
    end
end

if self.on_hit_damage == 0 then
    self.on_hit_damage = 4
else
    return
end
