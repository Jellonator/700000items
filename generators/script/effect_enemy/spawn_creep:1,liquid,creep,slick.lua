python[[gen.genstate.add_descriptors(["Gross", "Trail", "Creep", "Slime", "Liquid"])]]
do
    local id = python[[
gen.writeln("{}".format(choose_random_effect_common()))
    ]]
    local entity = Isaac.Spawn(EntityType.ENTITY_EFFECT, id, 0, pos, Vector(0,0), nil)
    local effect = entity:ToEffect()
    -- effect:SetDamageSource(EntityType.ENTITY_PLAYER)
    effect.LifeSpan = 20
end
