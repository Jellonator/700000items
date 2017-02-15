do
    local data = familiar:GetData()
    data.shoot_timer = data.shoot_timer or 0
    if data.shoot_timer <= 0 then
        local dir = GetAimDirection()
        if dir.X ~= 0 or dir.Y ~= 0 then
            dir = dir:Normalized()
            data.shoot_timer = 30
            familiar:Shoot()
        end
    else
        data.shoot_timer = data.shoot_timer - 1
    end
end
