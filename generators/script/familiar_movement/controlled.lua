do
    local dir = player:GetAimDirection()
    if dir.X ~= 0 or dir.Y ~= 0 then
        dir = dir:Normalized()
    end
    familiar.Velocity = dir * python[[gen.write(random.choice([5, 6, 7, 8]))]]
    if not Game():GetRoom():IsPositionInRoom(familiar.Position + familiar.Velocity, 1) then
        familiar.Velocity = Vector(0,0)
    end
end
