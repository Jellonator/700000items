python[[gen.inc_var("value", 1)]]
room_change = function(self, player)
	local pos = player.Position
	if Game():GetRoom():IsFirstVisit() then
		python[[gen.include("stipulations")]]
		python[[gen.include("effect_instant")]]
	end
end
