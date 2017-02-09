python[[gen.genstate.add_descriptors(["Meh"])]]
if not self.feelin_it then
    chance = self.feelin_it and 0.5 or 0.3
    if time_i then
        chance = chance / 15
    end
    if math.random() <= chance then
        self.feelin_it = not self.feelin_it
    end
    return
end
