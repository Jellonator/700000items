do
    local target_pos
    local target_distance_2
    local max_distance = 5
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity:IsVulnerableEnemy() then
            local enemy = entity:ToNPC()
            local new_distance_2 = (enemy.Position-familiar.Position):LengthSquared()
            if not target_distance_2 or new_distance_2 < target_distance_2 then
                target_pos = enemy.Position
                target_distance_2 = new_distance_2
                if target_distance_2 <= max_distance^2 then
                    target_pos = nil
                    break
                end
            end
        end
    end
    if target_pos then
        local direction = (target_pos-pos):Normalized()
        local speed = python[[gen.write(random.choice([5, 6, 7, 8]))]]
        familiar.Velocity = direction*speed
        if not Game():GetRoom():IsPositionInRoom(familiar.Position + familiar.Velocity, 1) then
            familiar.Velocity = Vector(0,0)
        end
    else
        familiar.Velocity = Vector(0,0)
    end
end
