python[[gen.inc_var("value", 1)]]
python[[
item_id = choose_random_collectible()
gen.genstate.add_descriptors(id_to_descriptors(item_id))
gen.writeln("""
self.timer = self.timer - 1
if self.timer <= 0 then
    self.timer = math.random(15, 80)
    if self.active then
        self.active = false
        player:RemoveCollectible({0})
    else
        self.active = true
        player:AddCollectible({0}, 0, false)
    end
end
""".format(item_id))

gen.write_effect("""
on_remove = function(self, player)
    if self.active then
        player:RemoveCollectible({0})
        self.active = false
    end
end
""".format(item_id))

gen.write_effect("""
init = function(self)
    self.active = false;
    self.timer = 30;
end""")
]]
