
do
    local distance, speed, layer = python[[
distance,mult,layer = random.choice([(40,5,1), (40,5,1), (60,4,5), (80,3,6), (100,2,7), (120,1,8)])
speed = random.choice([1,2,2,3])
gen.write("{}, {}, {}".format(distance, speed, layer))
gen.set_var("collision_damage", gen.get_var_default("collision_damage", 0)*mult)
]]
    familiar.OrbitDistance = Vector(distance, distance)
    familiar.OrbitLayer = layer
    familiar.OrbitSpeed = speed*0.01
    local target = familiar:GetOrbitPosition(player.Position + player.Velocity)
    familiar.Velocity = target - familiar.Position
end
