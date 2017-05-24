python[[
gen.write_effect("""
familiar_init = function(self, player, familiar)
    familiar.IsFollower = true
end
""")
]]
familiar:FollowParent()
