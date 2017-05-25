python[[gen.chance(3, 0.3, 2)]]
python[[gen.genstate.add_descriptors(["Charge", "Battery", "Volt"])]]
if player:NeedsCharge() then
    player:SetActiveCharge(player:GetActiveCharge()+1)
end
