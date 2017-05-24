python[[gen.genstate.add_descriptors(["Enemy", "Harm", "Blood", "Tear", "Shot"])]]
enemy_take_damage = function(self, player, enemy, damage, flag, source, frames)
	-- Make sure effect doesn't occur too much
	self.take_damage_timer = self.take_damage_timer or 0
	if _timer < self.take_damage_timer or _timer > self.take_damage_timer + 15 then
		self.take_damage_timer = _timer + 10
		local pos = source.Position
		python[[gen.include("effect_enemy", exclude=["spawn_creep"])]]
	end
end
