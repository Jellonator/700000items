python[[gen.inc_var("value", 2)
# Familiars aren't really that good,
# but they often don't typically have stat upgrades either]]
familiar_update = function(self, player, familiar)
    local pos = familiar.Position
    python[[gen.include("familiar_movement")]]
    python[[gen.include("familiar_effect")]]
end

python[[
gen.write_effect("""
update = function(self, player, time_i, time_f)
    local familiar_num = player:GetCollectibleNum(self.item_id)
    local variant = self.familiar_variant
    player:CheckFamiliar(variant, familiar_num, RNG())
end
""")
]]
