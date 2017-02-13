do
    local pos = Isaac.GetFreeNearPosition(pos, 1)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BOMB, 
		BombSubType.BOMB_GOLDEN, pos, Vector(0, 0), nil)
end
