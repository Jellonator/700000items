do
    local dir = player:GetAimDirection()
    local speed = python[[gen.write(random.choice([5, 6, 7, 8]))]]
    if dir.X ~= 0 or dir.Y ~= 0 then
        dir = dir:Normalized()
    end
    if not Game():GetRoom():IsPositionInRoom(familiar.Position + Vector(dir.X*(speed+1), 0), 1) then
        dir.X = 0
    end
    if not Game():GetRoom():IsPositionInRoom(familiar.Position + Vector(0, dir.Y*(speed+1)), 1) then
        dir.Y = 0
    end
    familiar.Velocity = dir * speed
end
