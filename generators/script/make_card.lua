local player = Isaac.GetPlayer(0)
local pos = player.Position
local self = {}
python[[
gen.set_allow_random(False)
gen.include("effect_instant")
gen.set_allow_random(True)
]]
