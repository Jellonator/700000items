python[[gen.inc_var("value", 2)
# Familiars aren't really that good,
#but they often don't have stat upgrades either]]
familiar_update = function(self, player, familiar)
    local pos = familiar.Position
    local familiar_num = player:GetCollectibleNum(self.item_id)
    if self.familiar_remove and self.familiar_remove > 0 then
        familiar:Kill()
        Isaac.DebugString("Removed familiar")
        self.familiar_remove = self.familiar_remove - 1
        return
    end
    python[[gen.include("familiar_movement")]]
    python[[gen.include("familiar_effect")]]
end

python[[
#gen.write_effect("""
#on_add = function(self, player)
#    local variant = self.familiar_variant
#    Isaac.DebugString("FAMILIAR PICKUP")
#    Isaac.Spawn(EntityType.ENTITY_FAMILIAR, variant, 0,
#        player.Position, Vector(0, 0), player)
#end
#""")
gen.write_effect("""
update = function(self, player, time_i, time_f)
    self.familiar_remove = 0
    -- Count number of familiars
    local actual_familiars = 0
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity.Type == 3 and entity.Variant == self.familiar_variant then
            actual_familiars = actual_familiars + 1
        end
    end

    -- Number of familiars we should have
    local familiar_num = player:GetCollectibleNum(self.item_id)

    -- If there aren't enough familiars, spawn more
    while actual_familiars < familiar_num do
        local variant = self.familiar_variant
        Isaac.DebugString("FAMILIAR PICKUP")
        Isaac.Spawn(EntityType.ENTITY_FAMILIAR, variant, 0,
            player.Position, Vector(0, 0), player)
        actual_familiars = actual_familiars + 1
    end

    -- If there are too many, remove some
    while actual_familiars > familiar_num do
        self.familiar_remove = self.familiar_remove + 1
        actual_familiars = actual_familiars - 1
    end
end
""")
]]
