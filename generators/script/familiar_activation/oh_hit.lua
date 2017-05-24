python[[
gen.set_var("familiar_base_hp", 1000000000)
gen.write_effect("""
familiar_take_damage = function(self, player)
    self.on_hit_damage = (self.on_hit_damage or 4) - 1
end
""")
]]
if self.on_hit_damage == 0 then
    self.on_hit_damage = 4
else
    return
end
