python[[gen.genstate.add_descriptors(["Death", "Enemy", "Blood"])]]
enemy_died = function(self, player, enemy, source)
    local pos = enemy.Position
    python[[gen.include("stipulations", exclude=["screenshake_me"])]]
    python[[gen.include("effect_enemy_died")]]
end
