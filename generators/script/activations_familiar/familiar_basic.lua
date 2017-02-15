familiar_update = function(self, player, familiar)
    local pos = familiar.Position
    if self.familiar_remove > 0 then
        familiar:Kill()
        self.familiar_remove = self.familiar_remove - 1
        return
    end
    python[[gen.include("familiar_movement")]]
    python[[gen.include("familiar_effect")]]
end

python[[
gen.write_effect("""
init = function(self)
    self.familiar_remove = 0
end""")
gen.write_effect("""
on_remove = function(self, player)
    self.familiar_remove = self.familiar_remove + 1
end""")
gen.write_effect("""
on_add = function(self, player)
    local variant = self.familiar_variant
    Isaac.DebugString("FAMILIAR PICKUP")
    Isaac.Spawn(EntityType.ENTITY_FAMILIAR, variant, 0,
        player.Position, Vector(0, 0), player)
end
""")
]]
