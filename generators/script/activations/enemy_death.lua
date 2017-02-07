enemy_died = function(self, player, enemy)
    local pos = enemy.Position
    python[[gen.include("stipulations")]]
    python[[gen.include("effect_enemy_died")]]
end
