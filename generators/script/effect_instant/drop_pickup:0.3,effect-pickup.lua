python[[gen.inc_var("value", 1)]]
python[[gen.chance(8, 1, 2)]]
python[[gen.genstate.add_descriptors(["Drops", "Gives"])]]
do
	local pickup, subtype = python[[
pickup = choose_random_pickup(gen.genstate)
subtype = choose_random_pickup_subtype(pickup)
pickup_name = get_pickup_name(pickup)
gen.writeln("{}, {}".format(pickup_name, subtype))
gen.genstate.add_descriptor(pickup.title())
	]]
	local pos = Isaac.GetFreeNearPosition(pos, 1)
	Isaac.Spawn(EntityType.ENTITY_PICKUP, pickup, subtype, pos, Vector(0, 0), nil)
end
