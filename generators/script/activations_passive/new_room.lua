python[[gen.inc_var("value", 1)]]
python[[gen.set_var("room_change", True)]]
python[[gen.genstate.add_descriptors(["Enter"])]]
room_change = function(self, player)
	local pos = player.Position
	if Game():GetRoom():IsFirstVisit() then
		python[[gen.include("effect_instant", exclude=["temporary_item", "temporary_stat_up"])]]
	end
end
