--a stipulation WITH a screenshake! woo!
python[[
gen.include("stipulations")
]]
if not time_i then
    -- to prevent this from working on update frames, I test for the
    -- time_i local variable which is only present on update functions
    Game():ShakeScreen(5)
end
