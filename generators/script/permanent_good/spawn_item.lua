do
    local pos = Isaac.GetFreeNearPosition(pos, 1)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, 0, pos, Vector(0, 0), nil)
end
