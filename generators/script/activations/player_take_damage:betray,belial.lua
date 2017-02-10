python[[gen.genstate.add_descriptors(["Blood", "Rage", "Brings"])]]
player_take_damage = function(self, player, damage, flag, source, frames)
	local pos = player.Position
	python[[gen.include("stipulations")]]
	python[[gen.include("effect_instant")]]
end
