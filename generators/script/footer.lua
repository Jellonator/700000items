for i, name in pairs(Mod.item_names) do
	local id = Isaac.GetItemIdByName(name)
	local def = Mod.items[id] or Mod.items[name] or {}
	Mod.items[id] = def
	Mod.items[name] = def

	table.insert(Mod.item_ids, id)
	Mod.item_id_to_name[id] = name
	Mod.item_name_to_id[name] = id
end
