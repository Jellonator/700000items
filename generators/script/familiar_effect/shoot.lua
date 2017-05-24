do
    local data = familiar:GetData()
    data.shoot_timer = data.shoot_timer or 0
    if data.shoot_timer <= 0 then
        local dir = player:GetAimDirection()
        if dir.X ~= 0 or dir.Y ~= 0 then
            dir = direction_to_vector(player:GetFireDirection())
            data.shoot_timer = 25
            local tear = familiar:FireProjectile(dir)
            python[[
gen.include("familiar_tear")
if random.random() < 0.3:
    gen.include("familiar_tear")
            ]]
        end
    else
        data.shoot_timer = data.shoot_timer - 1
    end
end
