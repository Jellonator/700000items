if player:GetNumCoins() >= 1 then
	player:AddCoins(-1)
	python[[gen.chance(5, 0.1, 2)]]
else
	return
end
