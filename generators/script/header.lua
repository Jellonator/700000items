Mod = RegisterMod("700000Items", 1)
--[[
Per-Item data, such as: stats, item variants, functionality, etc.
--]]
Mod.items = {} -- Item Data (indexable by name and id)
Mod.item_names = {} -- List of item names
Mod.item_ids = {} -- List of item ids (unordered)
Mod.item_id_to_name = {} -- key = id, value = name
Mod.item_name_to_id = {} -- key = name, value = id

function Mod:get_player_id(player)
	local game = Game()
	if type(player) == "number" then return player, Isaac.GetPlayer(player-1) end
	for i = 1, game:GetNumPlayers() do
		local p = game:GetPlayer(i-1)
		if p.Index == player.Index then
			return i, player
		end
	end
	error("No player with ID!")
end

-- call a callback for a specific player
function Mod:call_callbacks(player_id, func, ...)
	player_id, player = Mod:get_player_id(player_id)
	local item_ids = _get_player_items(player_id).list
	for item_id in pairs(item_ids) do
		local item_def = Mod.items[item_id]
		local item_func = item_def[func]
		if item_func then
			item_func(item_def, player, ...)
		end
	end
end

function Mod:call_callbacks_all(func, ...)
	local game = Game()
	for i = 1, game:GetNumPlayers() do
		Mod:call_callbacks(i, func, ...)
	end
end

--[[
Global data, such as: damage taken, damage dealt, coins collected
--]]
Mod.args = {}

--[[
Utility functions
--]]
function inf_norm(x, n)
	n = n or 1
	return x / (math.abs(x) + n)
end

function inf_norm_positive(x, n)
	return (inf_norm(x, n) + 1) / 2
end

_player_items = {}
function _get_player_items(id)
	if not _player_items[id] then
		_player_items[id] = {
			potential = {},
			list = {}
		}
	end
	return _player_items[id]
end

function _signal_refresh_cache(id)
	local player = Isaac.GetPlayer(id)
	player:AddCacheFlags(CacheFlag.CACHE_ALL)
	player:EvaluateItems()
end

-- Completely refreshing the cache is a slow operation that may take a second
-- Use conservatively!
function _refresh_item_cache()
	local game = Game()
	for i = 1, game:GetNumPlayers() do
		local player_items = _get_player_items(i);
		local player = game:GetPlayer(i-1);
		player_items.list = {}
		player_items.potential = {}
		for _, item_id in pairs(Mod.item_ids) do
			if player:HasCollectible(item_id) then
				player_items.list[item_id] = true
			end
		end
		_signal_refresh_cache(i-1)
	end
	Isaac.DebugString("Refreshed Item Cache")
end

--[[
Callback functions
--]]
Mod.callbacks = {}
Mod._cache_firedelay_need_update = false
function Mod.callbacks:evaluate_cache(player, flag)
	-- if flag == CacheFlag.CACHE_FIREDELAY then
	-- 	Mod._cache_firedelay_need_update = true
	-- else
	Mod:call_callbacks(player, "evaluate_cache", flag)
	-- end
end

local _room_id = -1
local _enemies = {}
function Mod.callbacks:update()
	local game = Game()
	-- if Mod._cache_firedelay_need_update then
	-- 	Mod._cache_firedelay_need_update = false
	-- 	for i = 1, game:GetNumPlayers() do
	-- 		local player = game:GetPlayer(i-1)
	-- 		Mod:call_callbacks(player, "evaluate_cache", CacheFlag.CACHE_FIREDELAY)
	-- 	end
	-- end
	-- refresh for room change
	local level = game:GetLevel()
	local room_id = level:GetCurrentRoomIndex()
	if _room_id ~= room_id then
		_room_id = room_id
		_refresh_item_cache()
		Mod.args.damage_taken = 0
		Mod.args.damage_dealt = 0
		Mod:call_callbacks_all("room_change")
		_enemies = {}
	end

	-- remove items that the player does not have
	for i = 1, game:GetNumPlayers() do
		local list = _get_player_items(i).list;
		local player = game:GetPlayer(i-1);
		local item_i = 1
		for item_id in pairs(list) do
			if not player:HasCollectible(item_id) then
				list[item_id] = nil
				Isaac.DebugString(("Removed item %d!"):format(item_id))
				_signal_refresh_cache(i-1)
			end
		end
	end

	-- add items to list of potential items
	for _, entity in pairs(Isaac.GetRoomEntities()) do
		local item_id = entity.SubType
		if entity.Type == EntityType.ENTITY_PICKUP
		and entity.Variant == PickupVariant.PICKUP_COLLECTIBLE
		and Mod.item_id_to_name[item_id] then
			for i = 1, game:GetNumPlayers() do
				local player_items = _get_player_items(i)
				if player_items.list[item_id] == nil then
					if player_items.potential[item_id] == nil then
						Isaac.DebugString(("Added potential item %d!"):format(item_id))
					end
					player_items.potential[item_id] = 100
				end
			end
		end
	end

	-- track potential items and see if player picked them up
	for i = 1, game:GetNumPlayers() do
		local player_items = _get_player_items(i)
		local player = game:GetPlayer(i-1)
		for item_id in pairs(player_items.potential) do
			if player:HasCollectible(item_id) then
				player_items.list[item_id] = true
				player_items.potential[item_id] = nil
				Isaac.DebugString(("Added item %d!"):format(item_id))
				_signal_refresh_cache(i-1)
			else
				player_items.potential[item_id] = player_items.potential[item_id] - 1
				if player_items.potential[item_id] <= 0 then
					player_items.potential[item_id] = nil
					Isaac.DebugString(("Removed potential item %d!"):format(item_id))
				end
			end
		end
	end

	-- add enemies to list
	for _, entity in pairs(Isaac.GetRoomEntities()) do
		if entity:IsActiveEnemy(false) and not _enemies[entity.Index] then
			_enemies[entity.Index] = entity:ToNPC()
		end
	end

	-- check for dead enemies
	for id, enemy in pairs(_enemies) do
		if not enemy:Exists() then
			_enemies[id] = nil
			Mod:call_callbacks(Isaac.GetPlayer(0), "enemy_died", enemy)
		end
	end
end

function Mod.callbacks:render()
	local game = Game()
	for i = 1, game:GetNumPlayers() do
		local list = _get_player_items(i).list;
		local pos = 0
		for item_i, item_v in pairs(list) do
			pos = pos + 1
			Isaac.RenderText(tostring(item_i), (i-1)*128, (pos-1)*16, 255, 255, 255, 255);
		end
	end
end

function Mod.callbacks:use_item(item, rng)
	local item_def = Mod.items[item]
	if item_def.on_usage then
		item_def.on_usage(item_def, Isaac.GetPlayer(0), rng)
	end
end

function Mod.callbacks:player_take_damage(player, amount, ...)
	player = player:ToPlayer()
	Mod:call_callbacks(player, "player_take_damage", amount, ...)
	print("TOOK " .. tostring(amount) .. " DAMAGE!")
	Mod.args.damage_taken = Mod.args.damage_taken + amount
	print("NOW AT " .. tostring(Mod.args.damage_taken) .. " DAMAGE")
end

function Mod.callbacks:enemy_take_damage(enemy, amount, ...)
	if not enemy:IsVulnerableEnemy() then return end
	Mod.args.damage_dealt = Mod.args.damage_dealt + amount
	Mod:call_callbacks(Isaac.GetPlayer(0), "enemy_take_damage", enemy, amount, ...)
end

function Mod.callbacks:use_pill(pill_effect)
	Mod:call_callbacks(Isaac.GetPlayer(0), "take_pill", pill_effect)
end

function Mod.callbacks:use_card(card)
	Mod:call_callbacks(Isaac.GetPlayer(0), "use_card", card)
end

Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, Mod.callbacks.update)
Mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Mod.callbacks.evaluate_cache)
Mod:AddCallback(ModCallbacks.MC_POST_RENDER, Mod.callbacks.render)
Mod:AddCallback(ModCallbacks.MC_USE_ITEM, Mod.callbacks.use_item)
Mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Mod.callbacks.player_take_damage, EntityType.ENTITY_PLAYER)
Mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Mod.callbacks.enemy_take_damage)
Mod:AddCallback(ModCallbacks.MC_USE_CARD, Mod.callbacks.use_card)
Mod:AddCallback(ModCallbacks.MC_USE_PILL, Mod.callbacks.use_pill)
