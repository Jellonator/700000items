-- spawn a creep every 5-8 frames
self.creep_time = self.creep_time and self.creep_time - 1 or 0
if self.creep_time <= 0 then
    self.creep_time = math.random(5,8)
    local id = python[[
gen.writeln("{}".format(choose_random_effect_common()))
    ]]
    local entity = Isaac.Spawn(EntityType.ENTITY_EFFECT, id, 0, pos, Vector(0,0), nil)
    -- local effect = entity:ToEffect()
    -- effect:SetDamageSource(EntityType.ENTITY_PLAYER)
    -- effect.LifeSpan = 30
end
