python[[gen.set_var("collision_damage", gen.get_var_default("collision_damage", 0)*3)]]
local target_pos = player.Position
local target_distance = python[[gen.write(random.uniform(20, 50))]]
if (target_pos-pos):LengthSquared() > target_distance^2 then
    local direction = (target_pos-pos):Normalized()
    local actual_target = target_pos - direction * target_distance
    local distance = (actual_target-pos):Length()
    local speed = distance * 0.25
    familiar.Velocity = direction * speed * python[[gen.write(random.uniform(0.8, 1.5))]]
else
    familiar.Velocity = Vector(0,0)
end
