python[[gen.genstate.add_descriptors(["Enemy", "Harm", "Blood", "Tear", "Shot"])]]
enemy_take_damage = function(self, player, enemy, damage, amount, flag, source, frames)
	local pos = enemy.Position
	python[[gen.include("stipulations")]]
	python[[gen.include("effect_enemy")]]
end
