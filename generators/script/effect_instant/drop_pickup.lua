do
	local pickup, subtype = python[[
pickup = choose_random_pickup()
subtype = choose_random_pickup_subtype(pickup)
pickup_name = get_pickup_name(pickup)
gen.writeln("{}, {}".format(pickup_name, subtype))
	]]
	local pos = Isaac.GetFreeNearPosition(pos, 1)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, pickup, subtype, pos, Vector(0, 0), nil)
end
