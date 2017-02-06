room_change = function(self, player)
	if Game():GetRoom():IsFirstVisit() then
		python[[gen.include("stipulations")]]
		python[[gen.include("effect_instant")]]
	end
end
