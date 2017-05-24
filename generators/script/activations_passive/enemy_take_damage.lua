python[[gen.genstate.add_descriptors(["Enemy", "Harm", "Blood", "Tear", "Shot"])]]
enemy_take_damage = function(self, player, enemy, damage, flag, source, frames)
	-- To prevent infinite creep crash, only allow for knife, tears, and laser
	if not VALID_DAMAGE_SOURCES[source.Type] then return end
	-- Make sure effect doesn't occur too much
	self.timer = self.timer or 0
	if _timer < self.timer or _timer > self.timer + 5 then
		self.timer = _timer + 10
		local pos = source.Position
		python[[gen.include("stipulations", exclude=["screenshake_me"])]]
		python[[gen.include("effect_enemy")]]
	end
end
