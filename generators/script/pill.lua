local player = Isaac.GetPlayer(0)
local pos = player.Position
local self = {}
python[[
num = random.random()
gen.set_allow_random(False)
if num <= 0.125:
	#12% chance really good
	gen.include("permanent_good", exclude=["spawn_many_helpers"])
	gen.writeln("player:AnimateHappy()")
elif num <= 0.25:
	#12% chance really bad
	gen.include("permanent_bad")
	gen.writeln("player:AnimateSad()")
elif num <= 0.50:
	#25% chance good
	gen.include("effect_good", exclude=["spawn_some_helpers", "effect_instant"])
	gen.writeln("player:AnimateHappy()")
elif num <= 0.75:
	#25% chance bad
	gen.include("effect_bad")
	gen.writeln("player:AnimateSad()")
else:
	#25% chance instant
	gen.include("effect_instant")
	gen.writeln("player:AnimateHappy()")
gen.set_allow_random(True)
]]
