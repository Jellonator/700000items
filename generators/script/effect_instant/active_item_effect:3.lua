python[[gen.inc_var("value", 1)]]
python[[gen.chance(4, 0.2, 1)]]
player:UseActiveItem(python[[
gen.write("{}".format(choose_random_active()))
]], false, false, true, true)
