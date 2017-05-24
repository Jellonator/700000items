python[[gen.genstate.add_descriptors(["Temporary"])]]
python[[gen.inc_var("value", 1)]]
python[[
item_id = choose_random_collectible(False)
gen.genstate.add_descriptors(id_to_descriptors(item_id))

# Init
gen.write_effect("""
init = function(self, player)
    self.active = false
end
""".format(item_id))

# Removed - remove effect
gen.write_effect("""
on_remove = function(self, player)
    if self.active then
        player:RemoveCollectible({})
        self.active = false
    end
end
""".format(item_id))

# Room Change - remove effect
gen.write_effect("""
room_change = function(self, player)
    if self.active then
        player:RemoveCollectible({})
        self.active = false
    end
end
""".format(item_id))

# Effect - make active
gen.writeln("""
if not self.active then
    self.active = true
    player:AddCollectible({}, 0, false)
end
""".format(item_id))
]]
