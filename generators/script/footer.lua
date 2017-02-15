for i, name in pairs(Mod.item_names) do
	local id = Isaac.GetItemIdByName(name)
	local def = Mod.items[id] or Mod.items[name] or {}
	Mod.items[id] = def
	Mod.items[name] = def

	def.item_name = name
	def.item_id = id

	if def.init then def:init() end

	table.insert(Mod.item_ids, id)

	local familiar_variant = Isaac.GetEntityVariantByName(name)
	if familiar_variant and familiar_variant >= 0 then
		Isaac.DebugString(("Item \"%s\" has familiar variant %d"):format(name, familiar_variant))
		Mod.familiars[familiar_variant] = def
		def.familiar_variant = familiar_variant
	end
end

Mod.card_names = {}
for name, func in pairs(Mod.cards) do
	table.insert(Mod.card_names, name)
end
for _, name in ipairs(Mod.card_names) do
	local id = Isaac.GetCardIdByName(name)
	Mod.cards[id] = Mod.cards[name]
end

Mod.pill_names = {}
for name, func in pairs(Mod.pills) do
	table.insert(Mod.pill_names, name)
end
for _, name in ipairs(Mod.pill_names) do
	local id = Isaac.GetPillEffectByName(name)
	Mod.pills[id] = Mod.pills[name]
end

Mod.trinket_names = {}
for name, def in pairs(Mod.trinkets) do
	table.insert(Mod.trinket_names, name)
end
for _, name in ipairs(Mod.trinket_names) do
	local id = Isaac.GetTrinketIdByName(name)
	Mod.trinkets[id] = Mod.trinkets[name]
end

load_data()
