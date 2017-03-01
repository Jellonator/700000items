
do
    local length = python[[
length = random.choice([30, 45, 60, 75, 90])
gen.write(length)
gen.write_effect("""
familiar_init = function(self, player, familiar)
    familiar.IsDelayed = true
end
""")]]
    familiar:MoveDelayed(length)
end
