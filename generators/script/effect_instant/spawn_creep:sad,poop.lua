python[[gen.genstate.add_descriptors(["Gross", "Trail", "Creep", "Slime", "Liquid"])]]
do
    local id = python[[
gen.writeln("{}".format(choose_random_effect_common()))
    ]]
    for i = 1, 10 do
        local pos = pos + Vector(1, 0):Rotated(math.random()*360)*math.sqrt(math.random())*40
        local entity = Isaac.Spawn(EntityType.ENTITY_EFFECT, id, 0, pos, Vector(0,0), nil)
    end
    -- local effect = entity:ToEffect()
    -- effect:SetDamageSource(EntityType.ENTITY_PLAYER)
    -- effect.LifeSpan = 30
end
