python[[gen.chance(5, 0.25, 2.5)]]
if math.random()*math.max(2.5, 5-0.25*player.Luck) > 1 then
    player:AnimateSad()
    return
end
do
    local pos = Isaac.GetFreeNearPosition(pos, 1)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_KEY,
        KeySubType.KEY_GOLDEN, pos, Vector(0, 0), nil)
end
