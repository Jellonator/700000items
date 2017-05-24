update = function(self, player, time_i, time_f)
    local pos = player.Position
    python[[gen.include("stipulations", exclude=["screenshake_me"])]]
    python[[gen.include("effect_continuous")]]
end
