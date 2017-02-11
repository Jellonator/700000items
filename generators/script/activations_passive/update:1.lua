update = function(self, player, time_i, time_f)
    local pos = player.Position
    python[[gen.include("stipulations")]]
    python[[gen.include("effect_continuous")]]
end
