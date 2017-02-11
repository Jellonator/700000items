python[[gen.inc_var("value", 2)]]
whatever = function() end

python[[
item_id = choose_random_collectible()
gen.genstate.add_descriptors(id_to_descriptors(item_id))
gen.write_effect("""
on_add = function(self, player)
    player:AddCollectible({}, 0, false)
end
""".format(item_id))
gen.write_effect("""
on_remove = function(self, player)
    player:RemoveCollectible({})
end
""".format(item_id))
]]
