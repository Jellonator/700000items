for ix = -1, 1 do
	for iy = -1, 1 do
		if ix ~= 0 or iy ~= 0 then
			local veloc = Vector(ix, iy):Normalized()*5*player.ShotSpeed
			local tear = player:FireTear(pos, veloc, false, true, false)
			tear.Scale = tear.Scale * 2
			tear.Height = tear.Height + 4
			tear.FallingSpeed = tear.FallingSpeed - 0.5
		end
	end
end
