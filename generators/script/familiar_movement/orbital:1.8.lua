
do
    local distance, speed = python[[
distance,mult = random.choice([(40,5), (40,5), (60,4), (80,3), (100,2), (120,1)])
speed = random.choice([1,2,2,3])
gen.write("{}, {}".format(distance, speed))
gen.set_var("collision_damage", gen.get_var_default("collision_damage", 0)*mult)
gen.write_effect("""
familiar_init = function(self, player, familiar)
    familiar.OrbitSpeed = {0}*0.01
    familiar.OrbitDistance = Vector({1}, {1})
end
""".format(speed, distance))
]]
    -- local data = familiar:GetData()
    -- data.angle = ((data.angle or 0) + speed) % 360
    -- local position = player.Position + Vector(1,0):Rotated(data.angle) * distance
    -- familiar.Position = position
    -- familiar.OrbitAngleOffset = 0
    -- familiar.Position = familiar:GetOrbitPosition(player.Position)
    familiar:Follow()
end
