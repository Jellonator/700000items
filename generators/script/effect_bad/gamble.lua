if player:GetNumCoins() >= 1 then
	player:AddCoins(-1)
	if math.random()*math.max(2, 4-0.1*player.Luck) > 1 then
		player:AnimateSad()
		return
	end
else
	return false
end
player:AnimateHappy()
