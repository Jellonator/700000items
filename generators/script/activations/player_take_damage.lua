player_take_damage = function(self, player, damage, amount, flag, source, frames)
	local pos = player.Position
	python[[gen.include("stipulations")]]
	python[[gen.include("effect_instant")]]
end
