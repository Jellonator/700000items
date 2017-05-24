if player:GetNumBombs() >= 1 then
	player:AddBombs(-1)
else
	return false
end
