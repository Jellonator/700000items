python[[gen.genstate.add_descriptors(["Sack", "Squeeze"])]]
on_pickup = function(self, player)
    local pos = player.Position
    local pickup, subtype, num = python[[
pickup = choose_random_pickup(gen.genstate)
subtype = choose_random_pickup_subtype(pickup)
pickup_name = get_pickup_name(pickup)
gen.genstate.add_descriptor(pickup.title())
max_num = 3
if pickup in ["trinket", "chest"]:
    max_num = 1
elif pickup in ["pill", "card", "battery", "sack"]:
    max_num = 2
num = random.randint(1, max_num)
gen.writeln("{}, {}, {}".format(pickup_name, subtype, num))
    ]]
    for i = 1, num do
        local pos = Isaac.GetFreeNearPosition(pos, 1)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, pickup, subtype, pos, Vector(0, 0), nil)
    end
end
