update = function(self, player)
    local pos = player.Position
    python[[gen.include("stipulations")]]
    python[[gen.include("effect_continuous")]]
end
