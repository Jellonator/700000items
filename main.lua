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
function Mod.callbacks:evaluate_cache(player, flag)
	Mod:call_callbacks(player, "evaluate_cache", flag)
end

local _room_id = -1
function Mod.callbacks:update()
	local game = Game()
	-- refresh for room change
	local level = game:GetLevel()
	local room_id = level:GetCurrentRoomIndex()
	if _room_id ~= room_id then
		_room_id = room_id
		_refresh_item_cache()
		Mod.args.damage_taken = 0
		Mod.args.damage_dealt = 0
		Mod:call_callbacks_all("room_change")
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
	Mod:call_callbacks(player, "player_take_damage", amount, ...)
	Mod.args.damage_taken = Mod.args.damage_taken + amount
end

function Mod.callbacks:enemy_take_damage(enemy, amount, ...)
	if not enemy:IsVulnerableEnemy() then return end
	Mod.args.damage_dealt = Mod.args.damage_dealt + amount
	Mod:call_callbacks(Isaac.GetPlayer(0), "enemy_take_damage", enemy, amount, ...)
end

function Mod.callbacks:use_pill(pill_effect)
	Mod:call_callbacks(Isaac.GetPlayer(1), "take_pill", pill_effect)
end

function Mod.callbacks.use_card(card)
	Mod:call_callbacks(Isaac.GetPlayer(1), "use_card", card)
end

Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, Mod.callbacks.update)
Mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Mod.callbacks.evaluate_cache)
Mod:AddCallback(ModCallbacks.MC_POST_RENDER, Mod.callbacks.render)
Mod:AddCallback(ModCallbacks.MC_USE_ITEM, Mod.callbacks.use_item)
Mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG , Mod.callbacks.player_take_damage, EntityType.ENTITY_PLAYER)
Mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG , Mod.callbacks.enemy_take_damage)
Mod:AddCallback(ModCallbacks.MC_USE_CARD , Mod.callbacks.use_card)
Mod:AddCallback(ModCallbacks.MC_USE_PILL , Mod.callbacks.use_pill)
Mod.item_names = {
	"930 Rotten Paw",
	"159 Cursed Halo of Paw",
	"120 My Holy Box",
	"468 My Sticky Sticky Bomb Sack of Shadows",
	"791 My Rotten Eye 2.0",
	"785 Mr. Ultra Bag",
	"476 Mysterious Little Coin Ring",
	"399 Mr. Cursed Head of Meat",
	"525 My Cube of Box",
	"83 Mom's Halo of Poop",
	"547 Bomb Paw",
	"993 Guppy's Demonic Halo of Box",
	"749 Mysterious Coin Sack",
	"304 Mom's Turdy Book of Sack of Meat",
	"163 Bob's Tiny Fly Meat",
	"592 My Demonic Halo of Ring of Secrets",
	"945 Guppy's Sad Head",
	"938 Coin Brain",
	"956 Sacred Halo of Box",
	"929 My Sad Halo of Meat",
	"937 Sad Boy",
	"720 Guppy's Ring",
	"555 Rotten Fly Eye 2.0",
	"856 Bob's Little Cube of Brain",
	"228 Super Halo of Boy of Meat",
	"640 Mr. Small Bomb Sack",
	"787 Tiny Mysterious Bomb Box Baby",
	"847 Halo of Poop",
	"116 Sacred Ultra Kid of Flies",
	"707 My Mysterious Poop",
	"508 Mr. Sack",
	"377 Guppy's Tiny Gross Meat",
	"948 Mom's Rotten Cube of Paw",
	"983 Holy Ring",
	"9 Guppy's Ultra Poop of Cards",
	"425 Bob's Sack",
	"677 My Brain Worm",
	"467 Mr. Holy Book of Box",
	"69 Guppy's Sad Brain",
	"631 Guppy's Mysterious Meat",
	"384 Mr. Cursed Ultra Halo of Bag",
	"236 Small Brain da Whoop",
	"102 Holy Cube of Ring",
	"240 Guppy's Cursed Sticky Sack da Whoop",
	"889 Super Brain of Shadows",
	"691 Bob's Smelly Magic Cube of Sack da Whoop",
	"98 Mr. Tears of Shadows",
	"539 Mom's Magic Halo of Ring of Cards",
	"15 My Spider Kid Worm",
	"772 Magic Cube of Meat",
	"603 Guppy's Lost Meat",
	"53 Sad Brain of Pills",
	"247 Fly Paw of Shadows",
	"89 Bob's Sad Cube of Tears 2.0",
	"302 Mysterious Halo of Tears",
	"407 Mom's Magic Sticky Meat da Whoop",
	"60 My Lost Spider Sack",
	"428 Guppy's Gross Sacred Halo of Box of Flies",
	"482 Guppy's Coin Bag",
	"705 Mr. Holy Little Kid",
	"126 Mr. Sad Kid",
	"269 Bob's Sticky Holy Cube of Poop of Secrets",
	"872 Guppy's Turdy Sticky Cube of Boy Worm",
	"260 My Fly Paw",
	"562 Mr. Demonic Sticky Bag 2.0",
	"209 Mr. Halo of Head",
	"277 Sticky Demonic Eye",
	"602 Mr. Holy Cube of Meat",
	"300 Mom's Turdy Boy",
	"30 Sad Book of Brain",
	"614 Turdy Ring",
	"980 My Demonic Magic Eye",
	"954 Guppy's Rotten Box",
	"388 Mr. Sad Coin Tears da Whoop",
	"170 Ultra Evil Head",
	"762 Sad Bomb Brain of Shadows",
	"172 My Holy Poop",
	"835 Gross Halo of Sack",
	"838 Sticky Smelly Bomb Box",
	"105 Bob's Tiny Halo of Sack da Whoop",
	"439 Ultra Spider Box",
	"462 Mom's Ultra Head",
	"647 Mr. Holy Smelly Spider Poop",
	"534 My Rotten Super Poop",
	"57 Bob's Evil Spider Boy",
	"575 Bob's Gross Bomb Eye",
	"171 Bob's Halo of Eye",
	"648 Mr. Rotten Paw da Whoop",
	"910 Mom's Cube of Boy",
	"264 Mom's Small Turdy Spider Ring da Whoop",
	"936 My Sticky Fly Kid",
	"10 Book of Boy",
	"740 Turdy Rotten Book of Paw",
	"543 Cube of Eye 2.0",
	"842 Holy Cube of Box",
	"706 Super Spider Box of Shadows",
	"133 Guppy's Rotten Evil Bag",
	"837 Mom's Bag",
	"839 Cursed Gross Bag of Cards",
	"118 My Sack da Whoop",
	"690 Mr. Tiny Bomb Kid",
	"297 Holy Bomb Tears",
	"757 Mr. Book of Eye of Meat",
	"100 Holy Coin Tears of Secrets",
	"780 Small Box",
	"458 Sacred Spider Eye",
	"818 Super Smelly Cube of Bag",
	"966 Mom's Spider Paw",
	"940 My Bomb Kid Fetus",
	"693 Little Turdy Meat",
	"455 Little Kid 2.0",
	"127 My Holy Book of Ring",
	"382 Cursed Halo of Brain",
	"125 Ultra Book of Head",
	"653 Mom's Sack",
	"16 Bob's Cube of Eye",
	"634 Magic Sticky Head",
	"226 Mom's Tiny Gross Coin Paw of Pills",
	"701 Tiny Head of Secrets",
	"925 Cube of Meat",
	"239 Mr. Ultra Brain da Whoop",
	"738 My Paw of Cards",
	"673 Turdy Magic Bomb Head",
	"465 Guppy's Smelly Halo of Paw",
	"481 Sad Mysterious Paw",
	"294 Mr. Ultra Small Bomb Box da Whoop",
	"346 Book of Tears Worm",
	"688 Bob's Dead Tiny Bomb Kid Baby",
	"800 Mom's Mysterious Boy",
	"230 Mr. Halo of Kid",
	"975 My Sacred Paw",
	"681 Coin Paw Baby",
	"485 Bob's Bag of Flies",
	"433 Holy Fly Kid Fetus",
	"103 Lost Tiny Book of Sack 2.0",
	"849 My Poop",
	"778 Mom's Sacred Demonic Eye",
	"951 Mom's Sacred Boy",
	"633 Bob's Mysterious Cube of Boy",
	"128 Magic Fly Box",
	"340 My Dead Ring",
	"763 Mysterious Spider Boy of Flies",
	"402 Mr. Dead Smelly Meat",
	"915 Super Bomb Boy",
	"333 Mr. Smelly Sacred Cube of Bag",
	"549 Evil Eye of Cards",
	"760 Guppy's Bomb Eye",
	"86 Mom's Tiny Coin Box of Secrets",
	"802 Sad Poop",
	"244 Guppy's Evil Super Paw of Meat",
	"518 My Super Book of Head",
	"460 My Gross Tears of Cards",
	"580 Guppy's Super Poop Fetus",
	"819 Mom's Mysterious Box",
	"898 Smelly Mysterious Fly Meat",
	"522 Rotten Fly Head",
	"164 My Super Rotten Brain",
	"799 Mom's Tears",
	"72 Little Demonic Coin Box",
	"411 Coin Paw",
	"4 Mom's Small Fly Eye",
	"689 Rotten Cube of Paw 2.0",
	"811 Sacred Book of Brain",
	"54 Mr. Smelly Meat",
	"888 Smelly Spider Head",
	"40 Mr. Dead Boy",
	"279 Mom's Spider Box",
	"615 Mr. Fly Head",
	"207 Turdy Smelly Tears",
	"583 Demonic Eye",
	"665 Cube of Eye",
	"64 Mom's Super Magic Halo of Bag",
	"261 Rotten Super Book of Bag",
	"459 My Lost Gross Box",
	"652 Mr. Cursed Ultra Fly Kid of Flies",
	"708 Mom's Super Eye Baby",
	"146 Holy Ring Baby",
	"695 Demonic Box",
	"339 Holy Super Ring of Meat",
	"291 Sad Cube of Sack 2.0",
	"663 My Ring of Secrets",
	"505 Dead Brain",
	"320 Evil Mysterious Halo of Eye",
	"74 My Cube of Poop",
	"907 Mom's Sticky Cube of Paw",
	"586 Evil Brain",
	"710 Turdy Fly Box of Flies",
	"579 Mr. Halo of Tears",
	"878 Sacred Spider Sack of Secrets",
	"28 Sacred Bomb Kid",
	"630 Guppy's Cursed Sacred Halo of Ring Fetus",
	"669 Coin Poop 2.0",
	"828 Tiny Cube of Meat Worm",
	"542 My Rotten Fly Paw",
	"868 My Sticky Book of Poop",
	"135 Magic Super Coin Brain of Flies",
	"12 Bob's Cube of Paw",
	"852 My Evil Cube of Ring",
	"237 Mom's Sad Little Halo of Box 2.0",
	"205 My Ultra Ring",
	"850 Sacred Cube of Tears",
	"94 Turdy Holy Cube of Brain of Pills",
	"223 Mom's Sack of Shadows",
	"423 Guppy's Tiny Coin Poop",
	"512 Demonic Meat of Flies",
	"526 Cube of Tears",
	"165 Guppy's Smelly Bomb Brain",
	"905 My Fly Sack da Whoop",
	"79 Guppy's Book of Meat 2.0",
	"162 Bob's Mysterious Book of Tears Worm",
	"477 Mom's Mysterious Brain",
	"445 Gross Mysterious Book of Paw",
	"788 Little Sack",
	"43 Mom's Magic Box of Flies",
	"853 My Lost Fly Brain",
	"232 Mom's Paw",
	"326 Sticky Bag",
	"944 Demonic Mysterious Spider Bag Fetus",
	"729 Mom's Little Ring",
	"144 My Evil Sticky Box",
	"904 Sacred Bomb Box",
	"379 Halo of Tears of Meat",
	"726 Mr. Demonic Head",
	"273 My Turdy Head",
	"914 Smelly Super Cube of Meat",
	"851 My Dead Bag",
	"181 Mom's Ring",
	"281 Guppy's Spider Paw of Pills",
	"275 Mom's Bomb Paw",
	"608 Guppy's Fly Brain",
	"972 Spider Poop",
	"80 Demonic Sacred Cube of Eye",
	"511 Guppy's Gross Kid",
	"957 Turdy Brain",
	"446 Mom's Small Brain Worm",
	"197 Mom's Sacred Box",
	"722 Mom's Ultra Fly Kid",
	"563 Mysterious Head",
	"366 My Evil Super Book of Meat",
	"644 Mr. Small Bomb Ring",
	"981 Evil Fly Box",
	"950 My Coin Ring",
	"931 Mom's Magic Paw",
	"63 Smelly Book of Poop",
	"130 Mom's Turdy Holy Sack",
	"548 Lost Super Bomb Ring",
	"646 Guppy's Turdy Kid of Meat",
	"222 Spider Box 2.0",
	"974 Evil Ring",
	"732 Little Cube of Sack of Shadows",
	"782 Mom's Smelly Sticky Kid",
	"29 Sticky Mysterious Bomb Head of Shadows",
	"958 Bob's Dead Halo of Tears Worm",
	"873 Bob's Turdy Coin Paw",
	"822 Bob's Magic Cursed Sack Baby",
	"731 Small Sticky Bag",
	"765 My Little Mysterious Fly Head of Secrets",
	"430 Mom's Dead Tears of Meat",
	"879 Demonic Boy of Pills",
	"806 Bob's Dead Cube of Boy",
	"375 My Sad Halo of Paw",
	"591 Guppy's Ultra Lost Cube of Meat",
	"817 Mr. Cube of Boy Worm",
	"441 Magic Holy Book of Tears",
	"588 Rotten Boy Worm",
	"894 Bob's Holy Spider Tears",
	"285 Mom's Tiny Eye",
	"475 Guppy's Little Cube of Kid",
	"11 My Sad Brain da Whoop",
	"620 Mom's Magic Super Kid Fetus",
	"489 Bob's Fly Ring",
	"841 Demonic Turdy Boy Baby",
	"659 Bomb Head Fetus",
	"933 My Magic Bomb Brain",
	"61 Sticky Coin Head",
	"278 Mom's Ultra Gross Coin Tears",
	"825 Sacred Turdy Box",
	"916 Mysterious Fly Eye Worm",
	"491 Bob's Halo of Head",
	"864 Guppy's Tears",
	"276 My Brain of Pills",
	"798 Coin Box",
	"922 Bob's Rotten Turdy Coin Eye",
	"831 Sad Cube of Ring",
	"142 Holy Bomb Head",
	"417 Lost Sacred Bag of Flies",
	"855 Sad Eye",
	"431 Guppy's Brain",
	"556 Tiny Paw",
	"924 Gross Rotten Cube of Paw",
	"584 Sad Tiny Coin Brain of Flies",
	"97 Dead Boy",
	"661 Tiny Turdy Halo of Boy of Secrets",
	"686 Mom's Sticky Spider Eye",
	"329 Ultra Bomb Brain",
	"741 Mom's Sad Halo of Paw da Whoop",
	"861 Sticky Bag 2.0",
	"394 Guppy's Small Bomb Tears",
	"985 Dead Spider Tears",
	"233 Evil Bomb Box Worm",
	"783 Mr. Ultra Mysterious Halo of Bag",
	"174 Mom's Holy Bomb Sack 2.0",
	"900 Mom's Sad Demonic Ring",
	"655 My Bomb Head of Meat",
	"886 Sacred Kid of Shadows",
	"495 Mr. Cursed Box of Flies",
	"751 Mr. Bomb Eye",
	"767 Ultra Cube of Poop of Shadows",
	"364 Mom's Box",
	"899 Rotten Meat",
	"38 Mom's Head da Whoop",
	"345 Lost Fly Kid",
	"312 Sad Dead Coin Kid",
	"272 Turdy Rotten Sack 2.0",
	"212 Mr. Fly Boy of Flies",
	"692 Magic Eye of Flies",
	"990 Rotten Fly Ring",
	"711 Sacred Mysterious Sack",
	"50 Bob's Tiny Eye 2.0",
	"976 Mysterious Super Paw",
	"529 Guppy's Magic Eye da Whoop",
	"730 Mom's Smelly Small Ring",
	"796 Bob's Poop",
	"807 Mr. Smelly Sacred Bomb Sack",
	"590 Bob's Turdy Bomb Boy",
	"867 Small Spider Ring of Shadows",
	"625 Mr. Coin Kid of Flies",
	"965 Mom's Super Coin Boy",
	"516 Bob's Ultra Demonic Cube of Poop",
	"875 Super Box",
	"322 Mom's Sad Paw",
	"122 Cursed Evil Poop Worm",
	"971 Ultra Coin Paw Worm",
	"303 Mr. Tiny Spider Brain",
	"355 Guppy's Kid of Cards",
	"257 My Rotten Bomb Boy",
	"541 My Spider Poop",
	"626 Coin Poop",
	"987 Cube of Ring",
	"564 Evil Demonic Book of Tears of Secrets",
	"779 Rotten Turdy Head",
	"578 Guppy's Dead Bomb Box",
	"113 My Ultra Dead Boy",
	"582 Mr. Cursed Fly Paw",
	"761 Mr. Little Spider Poop",
	"190 Cursed Bomb Poop of Shadows",
	"928 Dead Bomb Paw 2.0",
	"959 Mom's Mysterious Smelly Bomb Paw",
	"168 Sacred Tears of Pills",
	"415 Mr. Small Ring",
	"403 Guppy's Rotten Sack",
	"166 Ultra Poop of Shadows",
	"325 Halo of Bag",
	"939 Mom's Halo of Brain",
	"816 Turdy Kid",
	"719 Little Cube of Poop",
	"180 Bob's Bomb Ring",
	"66 Mr. Ultra Cube of Eye",
	"573 Bob's Cursed Head",
	"452 Sacred Sacred Kid",
	"668 Guppy's Sacred Cube of Meat of Flies",
	"884 Mom's Demonic Bomb Paw",
	"262 Magic Cube of Eye",
	"766 Mom's Halo of Tears",
	"22 Mr. Holy Gross Ring of Shadows",
	"160 Little Coin Ring da Whoop",
	"656 Mr. Sticky Sacred Halo of Bag",
	"36 Little Halo of Boy 2.0",
	"500 Small Meat",
	"137 Sticky Eye of Shadows",
	"768 Mr. Brain",
	"702 Mr. Tears Fetus",
	"67 Bob's Holy Cube of Poop of Flies",
	"220 Mr. Cursed Halo of Kid",
	"650 Guppy's Spider Tears of Pills",
	"87 Sacred Tiny Tears",
	"795 Mysterious Poop of Pills",
	"568 Mom's Turdy Bomb Boy",
	"280 Bob's Super Poop",
	"617 Bob's Book of Tears",
	"108 Guppy's Meat",
	"919 My Little Halo of Brain of Cards",
	"932 Mom's Ultra Ring",
	"621 Mysterious Coin Eye",
	"745 Bob's Super Mysterious Bag",
	"32 Cursed Ring",
	"596 Mr. Evil Head",
	"503 My Rotten Holy Kid of Flies",
	"49 Mr. Smelly Bag",
	"557 Bomb Poop of Cards",
	"801 Demonic Paw",
	"424 Mom's Mysterious Cursed Boy da Whoop",
	"198 Mr. Turdy Kid",
	"921 Ultra Sack of Flies",
	"887 Mom's Sacred Bomb Bag of Secrets",
	"282 Bob's Ultra Sack Fetus",
	"255 Guppy's Turdy Box",
	"472 Guppy's Dead Bomb Kid 2.0",
	"502 My Fly Ring Worm",
	"454 Mom's Sticky Poop",
	"883 Mom's Sack of Cards",
	"20 Turdy Head",
	"437 Mom's Cube of Tears",
	"348 Ultra Coin Tears",
	"413 Book of Eye",
	"316 Mom's Tiny Halo of Poop of Secrets",
	"680 Bob's Mysterious Gross Cube of Ring",
	"821 Bob's Evil Book of Bag",
	"550 Rotten Cube of Ring",
	"865 Guppy's Holy Sad Kid",
	"679 Guppy's Sticky Kid Baby",
	"153 Mr. Book of Head of Shadows",
	"318 Guppy's Sacred Bag of Meat",
	"718 Mr. Spider Tears Fetus",
	"161 Mr. Demonic Smelly Cube of Brain of Cards",
	"362 Book of Bag",
	"24 Guppy's Evil Box",
	"378 Bob's Small Head of Secrets",
	"834 Guppy's Kid",
	"356 Mr. Smelly Evil Head",
	"82 Mom's Sacred Fly Head",
	"267 Bob's Ultra Little Brain Baby",
	"115 Rotten Kid 2.0",
	"844 Coin Boy of Shadows",
	"636 Holy Halo of Paw",
	"714 Little Sticky Meat",
	"117 Turdy Ultra Halo of Poop of Secrets",
	"797 Sticky Mysterious Book of Kid",
	"324 Turdy Super Cube of Brain",
	"660 Small Demonic Book of Kid",
	"744 Fly Poop",
	"427 Mom's Eye of Shadows",
	"435 Mom's Sad Eye",
	"287 Super Halo of Paw of Shadows",
	"121 Little Cube of Tears da Whoop",
	"618 Bomb Bag",
	"42 My Rotten Book of Kid",
	"374 Mom's Dead Spider Eye",
	"295 My Little Sad Box",
	"723 Rotten Coin Tears",
	"622 Bob's Cursed Coin Boy of Pills",
	"649 Mr. Bag da Whoop",
	"598 Bob's Sacred Head Fetus",
	"395 Guppy's Smelly Mysterious Cube of Kid Fetus",
	"75 Bob's Brain",
	"420 Mr. Paw Worm",
	"182 Little Super Tears",
	"391 Guppy's Tiny Lost Box",
	"605 Coin Tears",
	"803 Mom's Sacred Book of Box of Meat",
	"694 Guppy's Small Bomb Kid",
	"65 Mr. Gross Book of Meat of Shadows",
	"786 Guppy's Sacred Head",
	"138 Bob's Sticky Evil Meat",
	"739 Mom's Sticky Box",
	"977 Holy Tears of Flies",
	"438 My Sacred Boy",
	"664 Ultra Bomb Bag of Cards",
	"206 Bob's Sacred Halo of Tears",
	"629 Guppy's Sad Bomb Ring of Flies",
	"876 Guppy's Ultra Kid",
	"632 Super Coin Paw",
	"192 My Halo of Kid",
	"832 My Tiny Spider Poop Fetus",
	"245 Tiny Spider Meat",
	"891 Bob's Sacred Cube of Ring",
	"699 Mom's Small Book of Head 2.0",
	"412 Evil Holy Fly Paw",
	"585 Tiny Demonic Meat",
	"666 Guppy's Bomb Bag",
	"469 My Evil Sad Boy",
	"733 Bob's Gross Poop",
	"92 Sticky Coin Meat Fetus",
	"845 Super Rotten Book of Bag",
	"498 Guppy's Tiny Box of Secrets",
	"926 Mr. Demonic Ultra Bomb Paw",
	"183 Turdy Halo of Meat",
	"398 Mysterious Spider Ring",
	"727 Small Cube of Poop",
	"44 Turdy Magic Spider Boy",
	"151 Bob's Sacred Halo of Meat of Flies",
	"238 Bob's Boy 2.0",
	"143 Mom's Super Ring da Whoop",
	"712 My Turdy Ring",
	"145 Bob's Boy",
	"607 Mom's Evil Fly Paw",
	"155 Mom's Sticky Spider Meat da Whoop",
	"809 My Little Dead Cube of Bag of Flies",
	"597 Mr. Demonic Sad Cube of Eye",
	"667 Mom's Tiny Meat",
	"611 Demonic Small Poop of Cards",
	"139 Bob's Turdy Boy",
	"337 Guppy's Holy Coin Boy of Shadows",
	"177 Mr. Smelly Cube of Head da Whoop",
	"48 Bob's Magic Sack",
	"148 Rotten Mysterious Sack of Cards",
	"986 Halo of Box",
	"724 Smelly Meat of Pills",
	"968 Ultra Brain",
	"330 Mysterious Super Eye da Whoop",
	"341 Bob's Magic Ring",
	"119 Gross Cube of Box",
	"949 Magic Book of Tears Fetus",
	"880 Mom's Tiny Demonic Head 2.0",
	"419 Guppy's Sticky Fly Sack of Pills",
	"484 Gross Paw",
	"836 My Sticky Sack of Secrets",
	"728 My Spider Eye of Cards",
	"1 Sticky Cube of Box 2.0",
	"167 Smelly Little Halo of Eye of Flies",
	"637 Mom's Boy",
	"147 Bob's Mysterious Kid",
	"283 My Dead Eye Fetus",
	"14 Spider Eye of Cards",
	"826 Little Lost Halo of Paw",
	"1000 Mr. Halo of Meat",
	"8 Little Book of Eye",
	"488 Bob's Turdy Bomb Ring Fetus",
	"286 Guppy's Cursed Meat",
	"52 Bob's Cube of Tears Worm",
	"953 Guppy's Lost Ring",
	"2 Guppy's Sticky Ultra Poop",
	"101 Bob's Mysterious Cube of Eye",
	"969 My Sad Turdy Spider Eye",
	"490 Spider Boy",
	"813 Mom's Meat of Pills",
	"51 Mr. Tears Worm",
	"531 Guppy's Mysterious Cube of Box",
	"737 Halo of Paw Fetus",
	"536 Mr. Sticky Poop of Meat",
	"979 Mom's Sad Cube of Paw of Cards",
	"327 Mom's Sad Book of Head",
	"639 Magic Tiny Kid",
	"600 Rotten Halo of Bag",
	"46 Guppy's Evil Fly Meat",
	"645 Mr. Little Gross Bag of Flies",
	"577 Bob's Demonic Mysterious Halo of Brain",
	"380 Ultra Book of Box",
	"311 Guppy's Halo of Boy of Flies",
	"385 My Small Meat",
	"988 Lost Sticky Book of Boy da Whoop",
	"344 Bob's Holy Holy Bomb Box",
	"902 Fly Boy",
	"342 Cursed Sad Eye",
	"713 Little Halo of Paw of Secrets",
	"442 Bob's Rotten Boy Fetus",
	"501 Rotten Box",
	"593 Guppy's Evil Turdy Sack",
	"216 Gross Smelly Fly Brain 2.0",
	"450 Bob's Sticky Coin Paw",
	"746 Rotten Meat of Flies",
	"259 Mr. Head",
	"612 Mom's Ultra Bag",
	"748 My Lost Spider Ring",
	"328 Holy Tears of Meat",
	"243 Bob's Cursed Sack of Flies",
	"955 Fly Paw",
	"397 My Lost Box",
	"558 Mr. Demonic Box",
	"483 My Smelly Halo of Boy",
	"871 Mom's Holy Fly Meat",
	"68 My Sack",
	"890 Coin Bag da Whoop",
	"670 Sad Bomb Head",
	"908 Bob's Head",
	"363 Mom's Rotten Bag of Secrets",
	"351 Mom's Fly Meat",
	"552 Ultra Cursed Head of Secrets",
	"537 Mr. Holy Fly Eye",
	"901 Super Head",
	"697 My Dead Halo of Tears",
	"776 Sacred Spider Meat Baby",
	"854 Mr. Magic Boy",
	"866 Guppy's Holy Fly Boy",
	"229 Mr. Sacred Coin Tears",
	"893 Halo of Kid",
	"805 Sticky Super Halo of Boy",
	"824 Bob's Turdy Evil Coin Boy of Meat",
	"81 Mom's Brain",
	"315 Mom's Holy Book of Poop of Flies",
	"877 Mom's Dead Ring",
	"700 My Holy Spider Eye",
	"804 Ultra Fly Box",
	"820 My Holy Eye",
	"47 Magic Little Head Fetus",
	"641 Smelly Book of Ring",
	"310 Super Book of Paw",
	"859 Guppy's Smelly Little Eye of Shadows",
	"219 Sacred Holy Cube of Ring",
	"414 Holy Fly Sack of Pills",
	"754 Gross Cube of Bag",
	"56 Super Tiny Poop",
	"514 Turdy Bomb Brain",
	"387 Dead Fly Eye",
	"369 Cursed Tears of Pills",
	"998 Mr. Spider Sack 2.0",
	"789 Turdy Eye",
	"360 Demonic Turdy Paw",
	"284 Bob's Tiny Fly Brain",
	"96 Mr. Box",
	"527 Magic Mysterious Boy",
	"528 Holy Cursed Cube of Kid",
	"114 Mr. Super Fly Sack",
	"662 Bob's Cursed Boy 2.0",
	"225 Demonic Fly Head",
	"406 Demonic Gross Sack da Whoop",
	"301 My Sticky Meat Baby",
	"775 Mom's Sack Fetus",
	"141 Guppy's Boy Baby",
	"99 My Small Cube of Meat Baby",
	"246 Mr. Holy Bomb Tears",
	"752 Bob's Dead Dead Ring Fetus",
	"7 Mom's Ultra Sad Halo of Paw",
	"176 Sticky Kid",
	"947 Guppy's Poop",
	"773 My Coin Paw da Whoop",
	"305 Book of Poop",
	"39 My Rotten Brain",
	"187 My Smelly Halo of Bag of Cards",
	"444 Guppy's Coin Sack Worm",
	"474 Sad Ring",
	"513 My Gross Book of Eye Worm",
	"759 Super Head of Cards",
	"296 Guppy's Boy",
	"169 Sad Paw",
	"307 Demonic Spider Box of Secrets",
	"624 Bomb Meat",
	"443 My Mysterious Ring Baby",
	"298 Mom's Brain of Shadows",
	"559 Book of Tears",
	"13 Cursed Demonic Sack 2.0",
	"194 Guppy's Tiny Evil Cube of Meat",
	"682 Ultra Fly Kid",
	"447 Dead Mysterious Cube of Meat",
	"256 Small Tears",
	"869 Bob's Tiny Sack of Meat",
	"331 Super Cube of Meat of Flies",
	"497 Mr. Spider Eye",
	"769 Bomb Bag of Cards",
	"35 Turdy Spider Poop of Meat",
	"306 Guppy's Fly Head of Flies",
	"354 Bob's Fly Kid Fetus",
	"658 Smelly Little Book of Kid of Meat",
	"812 Mr. Gross Cube of Meat",
	"530 Mr. Cursed Book of Boy",
	"790 Bob's Magic Halo of Bag",
	"323 Mr. Evil Eye",
	"687 Turdy Sad Boy da Whoop",
	"613 Little Book of Boy of Flies",
	"840 Bob's Sad Brain Baby",
	"989 Magic Gross Paw",
	"999 Guppy's Demonic Dead Boy",
	"464 Mr. Magic Tears",
	"676 Cursed Book of Paw",
	"619 Holy Sticky Sack",
	"704 Mom's Magic Cube of Eye",
	"638 Mr. Spider Tears",
	"45 Mom's Cursed Brain da Whoop",
	"610 Sacred Cube of Kid",
	"521 My Book of Paw",
	"487 Guppy's Sad Halo of Kid",
	"882 Sacred Coin Poop",
	"492 Mr. Sad Evil Sack Baby",
	"967 Guppy's Sad Boy of Shadows",
	"906 My Box",
	"193 My Tiny Halo of Poop",
	"554 My Ultra Book of Eye",
	"794 Mr. Eye",
	"770 My Demonic Fly Bag",
	"601 Bob's Evil Eye of Cards",
	"995 Mom's Little Fly Ring of Shadows",
	"721 My Paw da Whoop",
	"792 Bob's Lost Halo of Boy",
	"571 Mr. Small Ring of Pills",
	"334 Gross Bag Fetus",
	"241 Guppy's Lost Bomb Sack Worm",
	"201 My Holy Coin Brain",
	"934 My Rotten Ring",
	"250 Mr. Rotten Mysterious Kid Fetus",
	"350 Mr. Little Head",
	"506 Tiny Meat",
	"73 Bomb Box",
	"599 My Sacred Coin Head",
	"37 My Fly Bag",
	"389 Fly Ring",
	"221 Mr. Magic Bag of Cards",
	"870 Mom's Dead Spider Meat",
	"881 Sticky Book of Boy",
	"848 Holy Holy Head",
	"935 Bob's Smelly Tiny Ring",
	"642 Magic Spider Paw",
	"827 Coin Sack",
	"609 Mom's Bomb Kid of Shadows",
	"186 Mr. Fly Boy",
	"569 Evil Holy Book of Eye of Shadows",
	"964 Bob's Paw",
	"570 My Eye 2.0",
	"104 Fly Boy of Meat",
	"833 Ultra Fly Eye",
	"843 Bob's Ultra Sacred Bomb Ring Fetus",
	"808 Mysterious Small Book of Brain",
	"353 Bob's Bag of Pills",
	"41 Mr. Lost Little Sack Baby",
	"480 My Cursed Magic Head",
	"896 Bob's Gross Bomb Paw",
	"486 Lost Cube of Ring",
	"258 Mom's Super Ring of Flies",
	"674 Guppy's Spider Poop Worm",
	"863 My Eye",
	"903 Holy Fly Brain",
	"735 Guppy's Cursed Sack of Secrets",
	"136 Book of Kid",
	"942 My Cursed Boy",
	"288 Little Spider Tears",
	"675 Mr. Small Small Kid",
	"210 Small Bomb Ring of Secrets",
	"846 Guppy's Small Gross Head Worm",
	"332 Ultra Meat Fetus",
	"917 Mr. Smelly Magic Brain",
	"21 Fly Paw of Cards",
	"771 Smelly Halo of Head Fetus",
	"234 My Gross Head of Secrets",
	"59 Mr. Sad Evil Coin Poop",
	"756 Fly Sack",
	"436 Bob's Ring",
	"235 Bob's Gross Book of Ring of Cards",
	"224 Mr. Small Bomb Kid",
	"214 Cursed Tears",
	"493 Guppy's Magic Book of Meat",
	"566 My Lost Gross Bomb Sack",
	"927 Mr. Boy",
	"368 My Coin Kid",
	"189 My Meat",
	"218 Cube of Eye of Shadows",
	"191 Bob's Evil Spider Tears",
	"292 Magic Sack",
	"858 Mr. Poop",
	"545 Mom's Sacred Cube of Kid",
	"857 Mom's Sticky Evil Meat of Pills",
	"470 Bob's Smelly Spider Head Worm",
	"604 Mr. Little Tiny Meat",
	"764 Super Demonic Book of Boy",
	"996 Cursed Halo of Bag",
	"984 Mr. Sad Cube of Eye",
	"519 My Head",
	"91 Cursed Coin Paw of Pills",
	"338 Sad Tears",
	"758 My Cursed Bag of Meat",
	"5 Small Eye",
	"567 Mom's Book of Box of Cards",
	"793 My Boy",
	"109 Bob's Magic Paw of Meat",
	"466 Mom's Demonic Book of Head",
	"973 Mr. Bomb Sack",
	"696 Mom's Dead Bomb Sack",
	"560 Bob's Magic Book of Head",
	"507 Bob's Rotten Eye",
	"25 Mom's Poop 2.0",
	"211 My Fly Eye",
	"595 Bob's Little Fly Box Worm",
	"523 Cursed Boy",
	"479 Fly Kid of Cards",
	"698 Mr. Turdy Gross Bomb Poop",
	"213 Bomb Paw da Whoop",
	"195 Sticky Sticky Halo of Paw",
	"90 Mr. Dead Box",
	"561 Super Holy Halo of Tears",
	"643 Mom's Eye",
	"88 Little Small Brain of Pills",
	"463 Turdy Sad Halo of Meat",
	"349 Mom's Evil Mysterious Book of Head",
	"347 Mr. Gross Spider Paw",
	"671 Bob's Rotten Fly Head",
	"499 Tiny Halo of Kid da Whoop",
	"392 Mr. Gross Kid 2.0",
	"184 Tiny Head",
	"265 Coin Head",
	"426 Guppy's Demonic Book of Boy 2.0",
	"393 Mysterious Ultra Halo of Head",
	"268 Gross Lost Eye",
	"365 Mr. Super Cursed Paw",
	"253 Bob's Box da Whoop",
	"154 Spider Meat",
	"535 Magic Meat Worm",
	"509 Spider Bag",
	"448 Turdy Bomb Kid",
	"678 Guppy's Tiny Dead Fly Boy",
	"289 Guppy's Magic Brain 2.0",
	"401 Little Coin Box",
	"920 Mom's Lost Halo of Boy",
	"200 Mom's Small Head",
	"994 Smelly Bag of Cards",
	"150 Bob's Fly Tears",
	"606 Mom's Book of Boy 2.0",
	"683 My Sad Sack",
	"418 Rotten Mysterious Box",
	"461 Mom's Dead Bag",
	"709 Mr. Small Cube of Poop",
	"421 Sticky Box",
	"911 Super Book of Head of Shadows",
	"892 Smelly Head",
	"997 Mr. Lost Halo of Paw",
	"308 Mr. Ultra Bomb Paw of Secrets",
	"17 Guppy's Halo of Tears",
	"717 Turdy Mysterious Sack",
	"252 Mom's Book of Brain",
	"473 Magic Fly Tears",
	"381 Sticky Coin Poop",
	"110 Bob's Evil Eye",
	"404 Lost Kid",
	"515 Halo of Sack",
	"202 Mr. Paw",
	"188 Mom's Sacred Bomb Poop",
	"544 Ultra Sacred Tears",
	"551 Dead Fly Brain",
	"747 Dead Mysterious Sack",
	"589 Mr. Bomb Meat Worm",
	"208 Mr. Spider Sack",
	"313 Dead Dead Meat",
	"755 Halo of Eye Baby",
	"961 Smelly Halo of Boy",
	"157 My Paw",
	"970 Demonic Smelly Book of Box",
	"19 Mr. Turdy Spider Eye da Whoop",
	"386 Evil Gross Spider Ring da Whoop",
	"158 Guppy's Halo of Sack",
	"654 My Sacred Coin Kid 2.0",
	"533 Mom's Coin Sack",
	"685 Tiny Smelly Eye 2.0",
	"532 Bob's Little Meat of Pills",
	"963 Coin Meat",
	"960 My Coin Bag",
	"912 My Sticky Halo of Bag",
	"909 Mr. Lost Boy of Shadows",
	"178 Ultra Holy Bag Baby",
	"913 Smelly Little Eye",
	"874 Smelly Cursed Coin Box",
	"263 My Small Cube of Sack",
	"77 Turdy Box",
	"396 Mom's Spider Eye",
	"299 Sacred Rotten Sack Fetus",
	"111 Mom's Dead Sacred Brain of Flies",
	"753 Mom's Ultra Bomb Eye da Whoop",
	"432 Bob's Rotten Bag",
	"271 Bob's Sad Tiny Box",
	"494 Rotten Bomb Kid",
	"510 Demonic Boy",
	"587 Guppy's Paw",
	"453 Bob's Lost Fly Poop",
	"572 Smelly Cube of Tears",
	"478 Bob's Tears",
	"623 Mr. Tiny Dead Bag",
	"860 Mr. Spider Bag",
	"371 Cube of Sack",
	"734 My Turdy Coin Ring Fetus",
	"777 My Box of Meat",
	"203 Spider Brain",
	"885 Holy Turdy Bomb Brain",
	"991 Bob's Little Sacred Box",
	"434 Guppy's Box",
	"451 Dead Coin Poop",
	"457 Bob's Poop Fetus",
	"152 Mom's Ultra Cube of Box",
	"581 My Spider Kid",
	"107 Bob's Sacred Dead Paw da Whoop",
	"823 Mom's Sticky Halo of Paw",
	"781 Halo of Kid of Cards",
	"616 Bob's Spider Kid",
	"982 Mr. Eye da Whoop",
	"129 Tiny Kid of Meat",
	"657 Super Smelly Bag",
	"635 Coin Ring",
	"814 Mom's Spider Paw Worm",
	"941 Mom's Head of Shadows",
	"440 Mysterious Meat",
	"449 Guppy's Sacred Super Coin Boy",
	"62 Cursed Head",
	"594 Holy Boy",
	"383 Bob's Magic Sticky Tears of Meat",
	"248 Bob's Meat of Flies",
	"34 Mom's Spider Tears",
	"314 Mr. Fly Kid",
	"743 Bob's Eye",
	"862 Mr. Evil Spider Head of Shadows",
	"123 Mom's Little Book of Boy",
	"410 Sticky Book of Sack",
	"574 Holy Bomb Ring",
	"895 Lost Gross Poop Baby",
	"774 Halo of Tears",
	"736 Bob's Smelly Smelly Fly Brain 2.0",
	"725 Lost Cube of Sack",
	"390 Mr. Turdy Gross Kid of Secrets",
	"357 Mysterious Bag Worm",
	"829 Magic Coin Tears",
	"628 Mom's Coin Kid",
	"784 Demonic Turdy Book of Brain da Whoop",
	"31 My Evil Book of Box of Shadows",
	"270 Bob's Spider Meat",
	"132 Spider Sack",
	"546 My Magic Meat",
	"179 Mr. Tiny Turdy Bag",
	"400 Guppy's Small Ring",
	"715 Tiny Bag Baby",
	"553 Mom's Smelly Lost Halo of Sack",
	"6 Guppy's Sacred Spider Head",
	"742 Spider Paw",
	"538 Mr. Coin Brain",
	"923 Mom's Little Fly Box 2.0",
	"27 Mr. Sad Sad Fly Sack",
	"943 Mom's Smelly Brain of Shadows",
	"416 Cube of Head of Secrets",
	"359 Bob's Box",
	"830 Mr. Turdy Fly Poop",
	"173 Mysterious Lost Book of Meat",
	"367 Bob's Bomb Box of Cards",
	"992 My Magic Coin Bag",
	"18 Bob's Mysterious Boy of Pills",
	"358 Book of Sack",
	"373 Dead Little Fly Boy of Shadows",
	"504 Book of Box",
	"978 Sad Magic Head of Pills",
	"58 My Spider Paw",
	"565 My Lost Boy",
	"336 Guppy's Gross Rotten Poop",
	"251 Turdy Turdy Cube of Box Worm",
	"70 Sad Box",
	"204 Mom's Small Bomb Sack",
	"429 Sad Rotten Coin Boy",
	"242 Mr. Gross Turdy Coin Box of Shadows",
	"716 Book of Sack of Secrets",
	"408 Bob's Ultra Coin Paw",
	"810 Mr. Sad Ring of Meat",
	"962 Mom's Little Halo of Paw",
	"422 Mom's Cursed Ultra Bomb Sack",
	"93 Mom's Mysterious Sack",
	"897 Spider Head",
	"196 Bomb Tears of Flies",
	"319 Tiny Lost Head of Shadows",
	"946 Ultra Bag Fetus",
	"254 Sticky Turdy Spider Brain",
	"376 Gross Rotten Head Baby",
	"71 Bob's Little Sack",
	"815 Coin Bag",
	"540 My Cube of Ring",
	"95 Mom's Evil Head",
	"343 Mom's Mysterious Kid da Whoop",
	"456 Gross Holy Coin Tears",
	"227 Bob's Sacred Spider Sack Baby",
}
Mod.items["930 Rotten Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["159 Cursed Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.05
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["120 My Holy Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.93
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["468 My Sticky Sticky Bomb Sack of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.29
		end
	end,
}
Mod.items["791 My Rotten Eye 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.73
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.39
		end
	end,
}
Mod.items["785 Mr. Ultra Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["476 Mysterious Little Coin Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
	end,
}
Mod.items["399 Mr. Cursed Head of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["525 My Cube of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.33
		end
	end,
}
Mod.items["83 Mom's Halo of Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["547 Bomb Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.7299999999999995
		end
	end,
}
Mod.items["993 Guppy's Demonic Halo of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.73
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["749 Mysterious Coin Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["304 Mom's Turdy Book of Sack of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.27
		end
	end,
}
Mod.items["163 Bob's Tiny Fly Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
	end,
}
Mod.items["592 My Demonic Halo of Ring of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.94
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["945 Guppy's Sad Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.95
		end
	end,
}
Mod.items["938 Coin Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["956 Sacred Halo of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["929 My Sad Halo of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
	end,
}
Mod.items["937 Sad Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
	end,
}
Mod.items["720 Guppy's Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.64
		end
	end,
}
Mod.items["555 Rotten Fly Eye 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.29
		end
	end,
}
Mod.items["856 Bob's Little Cube of Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["228 Super Halo of Boy of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["640 Mr. Small Bomb Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
	end,
}
Mod.items["787 Tiny Mysterious Bomb Box Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["847 Halo of Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["116 Sacred Ultra Kid of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.1799999999999997
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["707 My Mysterious Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["508 Mr. Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.39999999999999997
		end
	end,
}
Mod.items["377 Guppy's Tiny Gross Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["948 Mom's Rotten Cube of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["983 Holy Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.71
		end
	end,
}
Mod.items["9 Guppy's Ultra Poop of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.42
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["425 Bob's Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["677 My Brain Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.21
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["467 Mr. Holy Book of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.08
		end
	end,
}
Mod.items["69 Guppy's Sad Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.55
		end
	end,
}
Mod.items["631 Guppy's Mysterious Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["384 Mr. Cursed Ultra Halo of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
	end,
}
Mod.items["236 Small Brain da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.67
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
	end,
}
Mod.items["102 Holy Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.72
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["240 Guppy's Cursed Sticky Sack da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["889 Super Brain of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.69
		end
	end,
}
Mod.items["691 Bob's Smelly Magic Cube of Sack da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.67
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["98 Mr. Tears of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["539 Mom's Magic Halo of Ring of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.22
		end
	end,
}
Mod.items["15 My Spider Kid Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["772 Magic Cube of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.94
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["603 Guppy's Lost Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.82
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["53 Sad Brain of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.06
		end
	end,
}
Mod.items["247 Fly Paw of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.73
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["89 Bob's Sad Cube of Tears 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["302 Mysterious Halo of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
	end,
}
Mod.items["407 Mom's Magic Sticky Meat da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.96
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
	end,
}
Mod.items["60 My Lost Spider Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.9800000000000004
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["428 Guppy's Gross Sacred Halo of Box of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.37
		end
	end,
}
Mod.items["482 Guppy's Coin Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.44
		end
	end,
}
Mod.items["705 Mr. Holy Little Kid"] = {
	evaluate_cache = nil,
}
Mod.items["126 Mr. Sad Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["269 Bob's Sticky Holy Cube of Poop of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.21
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["872 Guppy's Turdy Sticky Cube of Boy Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.1
		end
	end,
}
Mod.items["260 My Fly Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["562 Mr. Demonic Sticky Bag 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["209 Mr. Halo of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["277 Sticky Demonic Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["602 Mr. Holy Cube of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.82
		end
	end,
}
Mod.items["300 Mom's Turdy Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["30 Sad Book of Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.27
		end
	end,
}
Mod.items["614 Turdy Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
	end,
}
Mod.items["980 My Demonic Magic Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.67
		end
	end,
}
Mod.items["954 Guppy's Rotten Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["388 Mr. Sad Coin Tears da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.27
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["170 Ultra Evil Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["762 Sad Bomb Brain of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.51
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.1
		end
	end,
}
Mod.items["172 My Holy Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
	end,
}
Mod.items["835 Gross Halo of Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["838 Sticky Smelly Bomb Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["105 Bob's Tiny Halo of Sack da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["439 Ultra Spider Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["462 Mom's Ultra Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["647 Mr. Holy Smelly Spider Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["534 My Rotten Super Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.83
		end
	end,
}
Mod.items["57 Bob's Evil Spider Boy"] = {
	evaluate_cache = nil,
}
Mod.items["575 Bob's Gross Bomb Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.32
		end
	end,
}
Mod.items["171 Bob's Halo of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["648 Mr. Rotten Paw da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.18
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["910 Mom's Cube of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.93
		end
	end,
}
Mod.items["264 Mom's Small Turdy Spider Ring da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["936 My Sticky Fly Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["10 Book of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["740 Turdy Rotten Book of Paw"] = {
	evaluate_cache = nil,
}
Mod.items["543 Cube of Eye 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["842 Holy Cube of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.47
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["706 Super Spider Box of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
	end,
}
Mod.items["133 Guppy's Rotten Evil Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["837 Mom's Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.4
		end
	end,
}
Mod.items["839 Cursed Gross Bag of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
	end,
}
Mod.items["118 My Sack da Whoop"] = {
	evaluate_cache = nil,
}
Mod.items["690 Mr. Tiny Bomb Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.99
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
	end,
}
Mod.items["297 Holy Bomb Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["757 Mr. Book of Eye of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["100 Holy Coin Tears of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.22
		end
	end,
}
Mod.items["780 Small Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.79
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.29
		end
	end,
}
Mod.items["458 Sacred Spider Eye"] = {
	evaluate_cache = nil,
}
Mod.items["818 Super Smelly Cube of Bag"] = {
	evaluate_cache = nil,
}
Mod.items["966 Mom's Spider Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["940 My Bomb Kid Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.42
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["693 Little Turdy Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.28
		end
	end,
}
Mod.items["455 Little Kid 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.63
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["127 My Holy Book of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["382 Cursed Halo of Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.98
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["125 Ultra Book of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.27
		end
	end,
}
Mod.items["653 Mom's Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["16 Bob's Cube of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.5
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["634 Magic Sticky Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.42000000000000004
		end
	end,
}
Mod.items["226 Mom's Tiny Gross Coin Paw of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.28
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["701 Tiny Head of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.16
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["925 Cube of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.29000000000000004
		end
	end,
}
Mod.items["239 Mr. Ultra Brain da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.03
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["738 My Paw of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["673 Turdy Magic Bomb Head"] = {
	evaluate_cache = nil,
}
Mod.items["465 Guppy's Smelly Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.35
		end
	end,
}
Mod.items["481 Sad Mysterious Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["294 Mr. Ultra Small Bomb Box da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.35
		end
	end,
}
Mod.items["346 Book of Tears Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["688 Bob's Dead Tiny Bomb Kid Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.33999999999999997
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["800 Mom's Mysterious Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["230 Mr. Halo of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["975 My Sacred Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.26
		end
	end,
}
Mod.items["681 Coin Paw Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.34
		end
	end,
}
Mod.items["485 Bob's Bag of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
	end,
}
Mod.items["433 Holy Fly Kid Fetus"] = {
	evaluate_cache = nil,
}
Mod.items["103 Lost Tiny Book of Sack 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.23
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["849 My Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.64
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["778 Mom's Sacred Demonic Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["951 Mom's Sacred Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["633 Bob's Mysterious Cube of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["128 Magic Fly Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["340 My Dead Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["763 Mysterious Spider Boy of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.62
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.35
		end
	end,
}
Mod.items["402 Mr. Dead Smelly Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.07
		end
	end,
}
Mod.items["915 Super Bomb Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.24
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["333 Mr. Smelly Sacred Cube of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["549 Evil Eye of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["760 Guppy's Bomb Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["86 Mom's Tiny Coin Box of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["802 Sad Poop"] = {
	evaluate_cache = nil,
}
Mod.items["244 Guppy's Evil Super Paw of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.26
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.3
		end
	end,
}
Mod.items["518 My Super Book of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.25
		end
	end,
}
Mod.items["460 My Gross Tears of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["580 Guppy's Super Poop Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.24
		end
	end,
}
Mod.items["819 Mom's Mysterious Box"] = {
	evaluate_cache = nil,
}
Mod.items["898 Smelly Mysterious Fly Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["522 Rotten Fly Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.94
		end
	end,
}
Mod.items["164 My Super Rotten Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["799 Mom's Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["72 Little Demonic Coin Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["411 Coin Paw"] = {
	evaluate_cache = nil,
}
Mod.items["4 Mom's Small Fly Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["689 Rotten Cube of Paw 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["811 Sacred Book of Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.61
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.27
		end
	end,
}
Mod.items["54 Mr. Smelly Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["888 Smelly Spider Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.2
		end
	end,
}
Mod.items["40 Mr. Dead Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["279 Mom's Spider Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["615 Mr. Fly Head"] = {
	evaluate_cache = nil,
}
Mod.items["207 Turdy Smelly Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["583 Demonic Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["665 Cube of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.39
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.22
		end
	end,
}
Mod.items["64 Mom's Super Magic Halo of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.75
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["261 Rotten Super Book of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["459 My Lost Gross Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["652 Mr. Cursed Ultra Fly Kid of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["708 Mom's Super Eye Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["146 Holy Ring Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
	end,
}
Mod.items["695 Demonic Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.75
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["339 Holy Super Ring of Meat"] = {
	evaluate_cache = nil,
}
Mod.items["291 Sad Cube of Sack 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.61
		end
	end,
}
Mod.items["663 My Ring of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["505 Dead Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["320 Evil Mysterious Halo of Eye"] = {
	evaluate_cache = nil,
}
Mod.items["74 My Cube of Poop"] = {
	evaluate_cache = nil,
}
Mod.items["907 Mom's Sticky Cube of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.23
		end
	end,
}
Mod.items["586 Evil Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["710 Turdy Fly Box of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.26
		end
	end,
}
Mod.items["579 Mr. Halo of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.95
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["878 Sacred Spider Sack of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.01
		end
	end,
}
Mod.items["28 Sacred Bomb Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["630 Guppy's Cursed Sacred Halo of Ring Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.97
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.33
		end
	end,
}
Mod.items["669 Coin Poop 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["828 Tiny Cube of Meat Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.48
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["542 My Rotten Fly Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.77
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["868 My Sticky Book of Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["135 Magic Super Coin Brain of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.93
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["12 Bob's Cube of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["852 My Evil Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["237 Mom's Sad Little Halo of Box 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.0
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["205 My Ultra Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.29
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["850 Sacred Cube of Tears"] = {
	evaluate_cache = nil,
}
Mod.items["94 Turdy Holy Cube of Brain of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.75
		end
	end,
}
Mod.items["223 Mom's Sack of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.49
		end
	end,
}
Mod.items["423 Guppy's Tiny Coin Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.01
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.33
		end
	end,
}
Mod.items["512 Demonic Meat of Flies"] = {
	evaluate_cache = nil,
}
Mod.items["526 Cube of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.33
		end
	end,
}
Mod.items["165 Guppy's Smelly Bomb Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["905 My Fly Sack da Whoop"] = {
	evaluate_cache = nil,
}
Mod.items["79 Guppy's Book of Meat 2.0"] = {
	evaluate_cache = nil,
}
Mod.items["162 Bob's Mysterious Book of Tears Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.49
		end
	end,
}
Mod.items["477 Mom's Mysterious Brain"] = {
	evaluate_cache = nil,
}
Mod.items["445 Gross Mysterious Book of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.2300000000000004
		end
	end,
}
Mod.items["788 Little Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["43 Mom's Magic Box of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
	end,
}
Mod.items["853 My Lost Fly Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.4
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["232 Mom's Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["326 Sticky Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.18
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.23
		end
	end,
}
Mod.items["944 Demonic Mysterious Spider Bag Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["729 Mom's Little Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["144 My Evil Sticky Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.29
		end
	end,
}
Mod.items["904 Sacred Bomb Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.51
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["379 Halo of Tears of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["726 Mr. Demonic Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["273 My Turdy Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.4
		end
	end,
}
Mod.items["914 Smelly Super Cube of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.4
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["851 My Dead Bag"] = {
	evaluate_cache = nil,
}
Mod.items["181 Mom's Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["281 Guppy's Spider Paw of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.25
		end
	end,
}
Mod.items["275 Mom's Bomb Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["608 Guppy's Fly Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["972 Spider Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.33
		end
	end,
}
Mod.items["80 Demonic Sacred Cube of Eye"] = {
	evaluate_cache = nil,
}
Mod.items["511 Guppy's Gross Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.6
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
	end,
}
Mod.items["957 Turdy Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.75
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["446 Mom's Small Brain Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
	end,
}
Mod.items["197 Mom's Sacred Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.3
		end
	end,
}
Mod.items["722 Mom's Ultra Fly Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 5
		end
	end,
}
Mod.items["563 Mysterious Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["366 My Evil Super Book of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["644 Mr. Small Bomb Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["981 Evil Fly Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.30000000000000004
		end
	end,
}
Mod.items["950 My Coin Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["931 Mom's Magic Paw"] = {
	evaluate_cache = nil,
}
Mod.items["63 Smelly Book of Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.74
		end
	end,
}
Mod.items["130 Mom's Turdy Holy Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
	end,
}
Mod.items["548 Lost Super Bomb Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.45
		end
	end,
}
Mod.items["646 Guppy's Turdy Kid of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.38
		end
	end,
}
Mod.items["222 Spider Box 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.16
		end
	end,
}
Mod.items["974 Evil Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.15
		end
	end,
}
Mod.items["732 Little Cube of Sack of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
	end,
}
Mod.items["782 Mom's Smelly Sticky Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
	end,
}
Mod.items["29 Sticky Mysterious Bomb Head of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["958 Bob's Dead Halo of Tears Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.33
		end
	end,
}
Mod.items["873 Bob's Turdy Coin Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.2
		end
	end,
}
Mod.items["822 Bob's Magic Cursed Sack Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.22
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["731 Small Sticky Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.6799999999999999
		end
	end,
}
Mod.items["765 My Little Mysterious Fly Head of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["430 Mom's Dead Tears of Meat"] = {
	evaluate_cache = nil,
}
Mod.items["879 Demonic Boy of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.71
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["806 Bob's Dead Cube of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["375 My Sad Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["591 Guppy's Ultra Lost Cube of Meat"] = {
	evaluate_cache = nil,
}
Mod.items["817 Mr. Cube of Boy Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["441 Magic Holy Book of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.29
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
	end,
}
Mod.items["588 Rotten Boy Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.34
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["894 Bob's Holy Spider Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
	end,
}
Mod.items["285 Mom's Tiny Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.24
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
	end,
}
Mod.items["475 Guppy's Little Cube of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["11 My Sad Brain da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.47
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.23
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["620 Mom's Magic Super Kid Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["489 Bob's Fly Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 6
		end
	end,
}
Mod.items["841 Demonic Turdy Boy Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["659 Bomb Head Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["933 My Magic Bomb Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["61 Sticky Coin Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["278 Mom's Ultra Gross Coin Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["825 Sacred Turdy Box"] = {
	evaluate_cache = nil,
}
Mod.items["916 Mysterious Fly Eye Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["491 Bob's Halo of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.41
		end
	end,
}
Mod.items["864 Guppy's Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.88
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.21
		end
	end,
}
Mod.items["276 My Brain of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.25
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["798 Coin Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.11
		end
	end,
}
Mod.items["922 Bob's Rotten Turdy Coin Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.17
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
	end,
}
Mod.items["831 Sad Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["142 Holy Bomb Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
	end,
}
Mod.items["417 Lost Sacred Bag of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.23
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["855 Sad Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.63
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
	end,
}
Mod.items["431 Guppy's Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["556 Tiny Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
	end,
}
Mod.items["924 Gross Rotten Cube of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
	end,
}
Mod.items["584 Sad Tiny Coin Brain of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.45
		end
	end,
}
Mod.items["97 Dead Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["661 Tiny Turdy Halo of Boy of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["686 Mom's Sticky Spider Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.22
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["329 Ultra Bomb Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.28
		end
	end,
}
Mod.items["741 Mom's Sad Halo of Paw da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["861 Sticky Bag 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["394 Guppy's Small Bomb Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.36
		end
	end,
}
Mod.items["985 Dead Spider Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["233 Evil Bomb Box Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.1
		end
	end,
}
Mod.items["783 Mr. Ultra Mysterious Halo of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.77
		end
	end,
}
Mod.items["174 Mom's Holy Bomb Sack 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["900 Mom's Sad Demonic Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.43
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["655 My Bomb Head of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["886 Sacred Kid of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.27
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.2
		end
	end,
}
Mod.items["495 Mr. Cursed Box of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["751 Mr. Bomb Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.8
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.21
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["767 Ultra Cube of Poop of Shadows"] = {
	evaluate_cache = nil,
}
Mod.items["364 Mom's Box"] = {
	evaluate_cache = nil,
}
Mod.items["899 Rotten Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["38 Mom's Head da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["345 Lost Fly Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["312 Sad Dead Coin Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["272 Turdy Rotten Sack 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.41
		end
	end,
}
Mod.items["212 Mr. Fly Boy of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["692 Magic Eye of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.18
		end
	end,
}
Mod.items["990 Rotten Fly Ring"] = {
	evaluate_cache = nil,
}
Mod.items["711 Sacred Mysterious Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.69
		end
	end,
}
Mod.items["50 Bob's Tiny Eye 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.24
		end
	end,
}
Mod.items["976 Mysterious Super Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["529 Guppy's Magic Eye da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.49
		end
	end,
}
Mod.items["730 Mom's Smelly Small Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["796 Bob's Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["807 Mr. Smelly Sacred Bomb Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.43000000000000005
		end
	end,
}
Mod.items["590 Bob's Turdy Bomb Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["867 Small Spider Ring of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.71
		end
	end,
}
Mod.items["625 Mr. Coin Kid of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.53
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["965 Mom's Super Coin Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["516 Bob's Ultra Demonic Cube of Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.25
		end
	end,
}
Mod.items["875 Super Box"] = {
	evaluate_cache = nil,
}
Mod.items["322 Mom's Sad Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
	end,
}
Mod.items["122 Cursed Evil Poop Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.8600000000000003
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["971 Ultra Coin Paw Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
	end,
}
Mod.items["303 Mr. Tiny Spider Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["355 Guppy's Kid of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["257 My Rotten Bomb Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["541 My Spider Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.52
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["626 Coin Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.72
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["987 Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["564 Evil Demonic Book of Tears of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.12
		end
	end,
}
Mod.items["779 Rotten Turdy Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
	end,
}
Mod.items["578 Guppy's Dead Bomb Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.95
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["113 My Ultra Dead Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["582 Mr. Cursed Fly Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
	end,
}
Mod.items["761 Mr. Little Spider Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["190 Cursed Bomb Poop of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.93
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.29
		end
	end,
}
Mod.items["928 Dead Bomb Paw 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.98
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["959 Mom's Mysterious Smelly Bomb Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.45
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["168 Sacred Tears of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["415 Mr. Small Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["403 Guppy's Rotten Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["166 Ultra Poop of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["325 Halo of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["939 Mom's Halo of Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["816 Turdy Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.0
		end
	end,
}
Mod.items["719 Little Cube of Poop"] = {
	evaluate_cache = nil,
}
Mod.items["180 Bob's Bomb Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.21
		end
	end,
}
Mod.items["66 Mr. Ultra Cube of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.4
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["573 Bob's Cursed Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.04
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["452 Sacred Sacred Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.84
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.37
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["668 Guppy's Sacred Cube of Meat of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["884 Mom's Demonic Bomb Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 5
		end
	end,
}
Mod.items["262 Magic Cube of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.81
		end
	end,
}
Mod.items["766 Mom's Halo of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.65
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["22 Mr. Holy Gross Ring of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["160 Little Coin Ring da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["656 Mr. Sticky Sacred Halo of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
	end,
}
Mod.items["36 Little Halo of Boy 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.44
		end
	end,
}
Mod.items["500 Small Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.92
		end
	end,
}
Mod.items["137 Sticky Eye of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.0
		end
	end,
}
Mod.items["768 Mr. Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
	end,
}
Mod.items["702 Mr. Tears Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["67 Bob's Holy Cube of Poop of Flies"] = {
	evaluate_cache = nil,
}
Mod.items["220 Mr. Cursed Halo of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
	end,
}
Mod.items["650 Guppy's Spider Tears of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.28
		end
	end,
}
Mod.items["87 Sacred Tiny Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["795 Mysterious Poop of Pills"] = {
	evaluate_cache = nil,
}
Mod.items["568 Mom's Turdy Bomb Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.37
		end
	end,
}
Mod.items["280 Bob's Super Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.52
		end
	end,
}
Mod.items["617 Bob's Book of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["108 Guppy's Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["919 My Little Halo of Brain of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.81
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["932 Mom's Ultra Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["621 Mysterious Coin Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["745 Bob's Super Mysterious Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["32 Cursed Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.99
		end
	end,
}
Mod.items["596 Mr. Evil Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.87
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["503 My Rotten Holy Kid of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.5
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["49 Mr. Smelly Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["557 Bomb Poop of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.24
		end
	end,
}
Mod.items["801 Demonic Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["424 Mom's Mysterious Cursed Boy da Whoop"] = {
	evaluate_cache = nil,
}
Mod.items["198 Mr. Turdy Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["921 Ultra Sack of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.03
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
	end,
}
Mod.items["887 Mom's Sacred Bomb Bag of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.3
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.2
		end
	end,
}
Mod.items["282 Bob's Ultra Sack Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.4
		end
	end,
}
Mod.items["255 Guppy's Turdy Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["472 Guppy's Dead Bomb Kid 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 6
		end
	end,
}
Mod.items["502 My Fly Ring Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["454 Mom's Sticky Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["883 Mom's Sack of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.45
		end
	end,
}
Mod.items["20 Turdy Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["437 Mom's Cube of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.62
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.24
		end
	end,
}
Mod.items["348 Ultra Coin Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.4
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["413 Book of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.2
		end
	end,
}
Mod.items["316 Mom's Tiny Halo of Poop of Secrets"] = {
	evaluate_cache = nil,
}
Mod.items["680 Bob's Mysterious Gross Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["821 Bob's Evil Book of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.38
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["550 Rotten Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["865 Guppy's Holy Sad Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.52
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["679 Guppy's Sticky Kid Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 5
		end
	end,
}
Mod.items["153 Mr. Book of Head of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["318 Guppy's Sacred Bag of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["718 Mr. Spider Tears Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["161 Mr. Demonic Smelly Cube of Brain of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["362 Book of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.27
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
	end,
}
Mod.items["24 Guppy's Evil Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["378 Bob's Small Head of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["834 Guppy's Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.68
		end
	end,
}
Mod.items["356 Mr. Smelly Evil Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["82 Mom's Sacred Fly Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
	end,
}
Mod.items["267 Bob's Ultra Little Brain Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.33
		end
	end,
}
Mod.items["115 Rotten Kid 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["844 Coin Boy of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["636 Holy Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.56
		end
	end,
}
Mod.items["714 Little Sticky Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["117 Turdy Ultra Halo of Poop of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
	end,
}
Mod.items["797 Sticky Mysterious Book of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.11
		end
	end,
}
Mod.items["324 Turdy Super Cube of Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.18
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.25
		end
	end,
}
Mod.items["660 Small Demonic Book of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.42000000000000004
		end
	end,
}
Mod.items["744 Fly Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
	end,
}
Mod.items["427 Mom's Eye of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
	end,
}
Mod.items["435 Mom's Sad Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.33
		end
	end,
}
Mod.items["287 Super Halo of Paw of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.31000000000000005
		end
	end,
}
Mod.items["121 Little Cube of Tears da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.45
		end
	end,
}
Mod.items["618 Bomb Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.91
		end
	end,
}
Mod.items["42 My Rotten Book of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["374 Mom's Dead Spider Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["295 My Little Sad Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["723 Rotten Coin Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.33
		end
	end,
}
Mod.items["622 Bob's Cursed Coin Boy of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
	end,
}
Mod.items["649 Mr. Bag da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.46
		end
	end,
}
Mod.items["598 Bob's Sacred Head Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
	end,
}
Mod.items["395 Guppy's Smelly Mysterious Cube of Kid Fetus"] = {
	evaluate_cache = nil,
}
Mod.items["75 Bob's Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["420 Mr. Paw Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.05
		end
	end,
}
Mod.items["182 Little Super Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.82
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.32999999999999996
		end
	end,
}
Mod.items["391 Guppy's Tiny Lost Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["605 Coin Tears"] = {
	evaluate_cache = nil,
}
Mod.items["803 Mom's Sacred Book of Box of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.12
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
	end,
}
Mod.items["694 Guppy's Small Bomb Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["65 Mr. Gross Book of Meat of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.39
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["786 Guppy's Sacred Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.64
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["138 Bob's Sticky Evil Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.0
		end
	end,
}
Mod.items["739 Mom's Sticky Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.84
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["977 Holy Tears of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.33
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["438 My Sacred Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.54
		end
	end,
}
Mod.items["664 Ultra Bomb Bag of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["206 Bob's Sacred Halo of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["629 Guppy's Sad Bomb Ring of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.25
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["876 Guppy's Ultra Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.51
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["632 Super Coin Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.89
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.46
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["192 My Halo of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.71
		end
	end,
}
Mod.items["832 My Tiny Spider Poop Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["245 Tiny Spider Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.27
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["891 Bob's Sacred Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.48
		end
	end,
}
Mod.items["699 Mom's Small Book of Head 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["412 Evil Holy Fly Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.48
		end
	end,
}
Mod.items["585 Tiny Demonic Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["666 Guppy's Bomb Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.22
		end
	end,
}
Mod.items["469 My Evil Sad Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.11
		end
	end,
}
Mod.items["733 Bob's Gross Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.48
		end
	end,
}
Mod.items["92 Sticky Coin Meat Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.25
		end
	end,
}
Mod.items["845 Super Rotten Book of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["498 Guppy's Tiny Box of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.81
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["926 Mr. Demonic Ultra Bomb Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["183 Turdy Halo of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["398 Mysterious Spider Ring"] = {
	evaluate_cache = nil,
}
Mod.items["727 Small Cube of Poop"] = {
	evaluate_cache = nil,
}
Mod.items["44 Turdy Magic Spider Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["151 Bob's Sacred Halo of Meat of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["238 Bob's Boy 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["143 Mom's Super Ring da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["712 My Turdy Ring"] = {
	evaluate_cache = nil,
}
Mod.items["145 Bob's Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["607 Mom's Evil Fly Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["155 Mom's Sticky Spider Meat da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["809 My Little Dead Cube of Bag of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["597 Mr. Demonic Sad Cube of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.87
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 5
		end
	end,
}
Mod.items["667 Mom's Tiny Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
	end,
}
Mod.items["611 Demonic Small Poop of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["139 Bob's Turdy Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
	end,
}
Mod.items["337 Guppy's Holy Coin Boy of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
	end,
}
Mod.items["177 Mr. Smelly Cube of Head da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.32
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["48 Bob's Magic Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["148 Rotten Mysterious Sack of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["986 Halo of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["724 Smelly Meat of Pills"] = {
	evaluate_cache = nil,
}
Mod.items["968 Ultra Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["330 Mysterious Super Eye da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 6
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["341 Bob's Magic Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.25
		end
	end,
}
Mod.items["119 Gross Cube of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.84
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["949 Magic Book of Tears Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.4
		end
	end,
}
Mod.items["880 Mom's Tiny Demonic Head 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.65
		end
	end,
}
Mod.items["419 Guppy's Sticky Fly Sack of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.39
		end
	end,
}
Mod.items["484 Gross Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.26
		end
	end,
}
Mod.items["836 My Sticky Sack of Secrets"] = {
	evaluate_cache = nil,
}
Mod.items["728 My Spider Eye of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["1 Sticky Cube of Box 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.54
		end
	end,
}
Mod.items["167 Smelly Little Halo of Eye of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["637 Mom's Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["147 Bob's Mysterious Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["283 My Dead Eye Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.38
		end
	end,
}
Mod.items["14 Spider Eye of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.59
		end
	end,
}
Mod.items["826 Little Lost Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.53
		end
	end,
}
Mod.items["1000 Mr. Halo of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["8 Little Book of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["488 Bob's Turdy Bomb Ring Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.23
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["286 Guppy's Cursed Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.24
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["52 Bob's Cube of Tears Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["953 Guppy's Lost Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["2 Guppy's Sticky Ultra Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.17
		end
	end,
}
Mod.items["101 Bob's Mysterious Cube of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.42
		end
	end,
}
Mod.items["969 My Sad Turdy Spider Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["490 Spider Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.41
		end
	end,
}
Mod.items["813 Mom's Meat of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["51 Mr. Tears Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["531 Guppy's Mysterious Cube of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.35
		end
	end,
}
Mod.items["737 Halo of Paw Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.31
		end
	end,
}
Mod.items["536 Mr. Sticky Poop of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["979 Mom's Sad Cube of Paw of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.52
		end
	end,
}
Mod.items["327 Mom's Sad Book of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.18
		end
	end,
}
Mod.items["639 Magic Tiny Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 5.95
		end
	end,
}
Mod.items["600 Rotten Halo of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.61
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
	end,
}
Mod.items["46 Guppy's Evil Fly Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.32
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
	end,
}
Mod.items["645 Mr. Little Gross Bag of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["577 Bob's Demonic Mysterious Halo of Brain"] = {
	evaluate_cache = nil,
}
Mod.items["380 Ultra Book of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["311 Guppy's Halo of Boy of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
	end,
}
Mod.items["385 My Small Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.26
		end
	end,
}
Mod.items["988 Lost Sticky Book of Boy da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["344 Bob's Holy Holy Bomb Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.61
		end
	end,
}
Mod.items["902 Fly Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.51
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["342 Cursed Sad Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["713 Little Halo of Paw of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.76
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["442 Bob's Rotten Boy Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.17
		end
	end,
}
Mod.items["501 Rotten Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.31
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["593 Guppy's Evil Turdy Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["216 Gross Smelly Fly Brain 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["450 Bob's Sticky Coin Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.24
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["746 Rotten Meat of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.25
		end
	end,
}
Mod.items["259 Mr. Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["612 Mom's Ultra Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["748 My Lost Spider Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.45
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["328 Holy Tears of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.18
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.28
		end
	end,
}
Mod.items["243 Bob's Cursed Sack of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.41
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["955 Fly Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.75
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["397 My Lost Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["558 Mr. Demonic Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["483 My Smelly Halo of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["871 Mom's Holy Fly Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.6
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["68 My Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.51
		end
	end,
}
Mod.items["890 Coin Bag da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 5.69
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["670 Sad Bomb Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.75
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["908 Bob's Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.6100000000000003
		end
	end,
}
Mod.items["363 Mom's Rotten Bag of Secrets"] = {
	evaluate_cache = nil,
}
Mod.items["351 Mom's Fly Meat"] = {
	evaluate_cache = nil,
}
Mod.items["552 Ultra Cursed Head of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 5.47
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["537 Mr. Holy Fly Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.47
		end
	end,
}
Mod.items["901 Super Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
	end,
}
Mod.items["697 My Dead Halo of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.83
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
	end,
}
Mod.items["776 Sacred Spider Meat Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
	end,
}
Mod.items["854 Mr. Magic Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["866 Guppy's Holy Fly Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.44
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["229 Mr. Sacred Coin Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["893 Halo of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["805 Sticky Super Halo of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 6.12
		end
	end,
}
Mod.items["824 Bob's Turdy Evil Coin Boy of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.25
		end
	end,
}
Mod.items["81 Mom's Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.39
		end
	end,
}
Mod.items["315 Mom's Holy Book of Poop of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.87
		end
	end,
}
Mod.items["877 Mom's Dead Ring"] = {
	evaluate_cache = nil,
}
Mod.items["700 My Holy Spider Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["804 Ultra Fly Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.56
		end
	end,
}
Mod.items["820 My Holy Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.38
		end
	end,
}
Mod.items["47 Magic Little Head Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.27
		end
	end,
}
Mod.items["641 Smelly Book of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.37
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["310 Super Book of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.41
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["859 Guppy's Smelly Little Eye of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.98
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.39
		end
	end,
}
Mod.items["219 Sacred Holy Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["414 Holy Fly Sack of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["754 Gross Cube of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["56 Super Tiny Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.83
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["514 Turdy Bomb Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.16
		end
	end,
}
Mod.items["387 Dead Fly Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["369 Cursed Tears of Pills"] = {
	evaluate_cache = nil,
}
Mod.items["998 Mr. Spider Sack 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.82
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["789 Turdy Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.33
		end
	end,
}
Mod.items["360 Demonic Turdy Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.27
		end
	end,
}
Mod.items["284 Bob's Tiny Fly Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.38
		end
	end,
}
Mod.items["96 Mr. Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["527 Magic Mysterious Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.38
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["528 Holy Cursed Cube of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["114 Mr. Super Fly Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["662 Bob's Cursed Boy 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.69
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["225 Demonic Fly Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.39
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["406 Demonic Gross Sack da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.92
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["301 My Sticky Meat Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 6
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.68
		end
	end,
}
Mod.items["775 Mom's Sack Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["141 Guppy's Boy Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.89
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.48
		end
	end,
}
Mod.items["99 My Small Cube of Meat Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["246 Mr. Holy Bomb Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.73
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.28
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["752 Bob's Dead Dead Ring Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.55
		end
	end,
}
Mod.items["7 Mom's Ultra Sad Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.57
		end
	end,
}
Mod.items["176 Sticky Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.04
		end
	end,
}
Mod.items["947 Guppy's Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 7.14
		end
	end,
}
Mod.items["773 My Coin Paw da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["305 Book of Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.29
		end
	end,
}
Mod.items["39 My Rotten Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["187 My Smelly Halo of Bag of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.64
		end
	end,
}
Mod.items["444 Guppy's Coin Sack Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.2300000000000004
		end
	end,
}
Mod.items["474 Sad Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.39
		end
	end,
}
Mod.items["513 My Gross Book of Eye Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 5.300000000000001
		end
	end,
}
Mod.items["759 Super Head of Cards"] = {
	evaluate_cache = nil,
}
Mod.items["296 Guppy's Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.22
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["169 Sad Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["307 Demonic Spider Box of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.33
		end
	end,
}
Mod.items["624 Bomb Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.890000000000001
		end
	end,
}
Mod.items["443 My Mysterious Ring Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["298 Mom's Brain of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["559 Book of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["13 Cursed Demonic Sack 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["194 Guppy's Tiny Evil Cube of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
	end,
}
Mod.items["682 Ultra Fly Kid"] = {
	evaluate_cache = nil,
}
Mod.items["447 Dead Mysterious Cube of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.45
		end
	end,
}
Mod.items["256 Small Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.44
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["869 Bob's Tiny Sack of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.31
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["331 Super Cube of Meat of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
	end,
}
Mod.items["497 Mr. Spider Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["769 Bomb Bag of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["35 Turdy Spider Poop of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
	end,
}
Mod.items["306 Guppy's Fly Head of Flies"] = {
	evaluate_cache = nil,
}
Mod.items["354 Bob's Fly Kid Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.08
		end
	end,
}
Mod.items["658 Smelly Little Book of Kid of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.66
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.37
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["812 Mr. Gross Cube of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.49
		end
	end,
}
Mod.items["530 Mr. Cursed Book of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.84
		end
	end,
}
Mod.items["790 Bob's Magic Halo of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["323 Mr. Evil Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["687 Turdy Sad Boy da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.24
		end
	end,
}
Mod.items["613 Little Book of Boy of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["840 Bob's Sad Brain Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["989 Magic Gross Paw"] = {
	evaluate_cache = nil,
}
Mod.items["999 Guppy's Demonic Dead Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["464 Mr. Magic Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.35
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["676 Cursed Book of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
	end,
}
Mod.items["619 Holy Sticky Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.54
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["704 Mom's Magic Cube of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.27
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.24
		end
	end,
}
Mod.items["638 Mr. Spider Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.32
		end
	end,
}
Mod.items["45 Mom's Cursed Brain da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.32
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["610 Sacred Cube of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["521 My Book of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.94
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["487 Guppy's Sad Halo of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.46
		end
	end,
}
Mod.items["882 Sacred Coin Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.29000000000000004
		end
	end,
}
Mod.items["492 Mr. Sad Evil Sack Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 6.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["967 Guppy's Sad Boy of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["906 My Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.23
		end
	end,
}
Mod.items["193 My Tiny Halo of Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["554 My Ultra Book of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["794 Mr. Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.75
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.29
		end
	end,
}
Mod.items["770 My Demonic Fly Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["601 Bob's Evil Eye of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["995 Mom's Little Fly Ring of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["721 My Paw da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.66
		end
	end,
}
Mod.items["792 Bob's Lost Halo of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.25
		end
	end,
}
Mod.items["571 Mr. Small Ring of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.05
		end
	end,
}
Mod.items["334 Gross Bag Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["241 Guppy's Lost Bomb Sack Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["201 My Holy Coin Brain"] = {
	evaluate_cache = nil,
}
Mod.items["934 My Rotten Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.57
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["250 Mr. Rotten Mysterious Kid Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["350 Mr. Little Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.31
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["506 Tiny Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.22
		end
	end,
}
Mod.items["73 Bomb Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.29000000000000004
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["599 My Sacred Coin Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
	end,
}
Mod.items["37 My Fly Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
	end,
}
Mod.items["389 Fly Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.27
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.23
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["221 Mr. Magic Bag of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.41
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["870 Mom's Dead Spider Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.6
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["881 Sticky Book of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.3
		end
	end,
}
Mod.items["848 Holy Holy Head"] = {
	evaluate_cache = nil,
}
Mod.items["935 Bob's Smelly Tiny Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.55
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["642 Magic Spider Paw"] = {
	evaluate_cache = nil,
}
Mod.items["827 Coin Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["609 Mom's Bomb Kid of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.35
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["186 Mr. Fly Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.96
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.27
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.31
		end
	end,
}
Mod.items["569 Evil Holy Book of Eye of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["964 Bob's Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["570 My Eye 2.0"] = {
	evaluate_cache = nil,
}
Mod.items["104 Fly Boy of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.54
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["833 Ultra Fly Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["843 Bob's Ultra Sacred Bomb Ring Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.26
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["808 Mysterious Small Book of Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["353 Bob's Bag of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.08
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["41 Mr. Lost Little Sack Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.11
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["480 My Cursed Magic Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.87
		end
	end,
}
Mod.items["896 Bob's Gross Bomb Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.38
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["486 Lost Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.46
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
	end,
}
Mod.items["258 Mom's Super Ring of Flies"] = {
	evaluate_cache = nil,
}
Mod.items["674 Guppy's Spider Poop Worm"] = {
	evaluate_cache = nil,
}
Mod.items["863 My Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["903 Holy Fly Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.51
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
	end,
}
Mod.items["735 Guppy's Cursed Sack of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["136 Book of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.93
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["942 My Cursed Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["288 Little Spider Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.51
		end
	end,
}
Mod.items["675 Mr. Small Small Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["210 Small Bomb Ring of Secrets"] = {
	evaluate_cache = nil,
}
Mod.items["846 Guppy's Small Gross Head Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
	end,
}
Mod.items["332 Ultra Meat Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.81
		end
	end,
}
Mod.items["917 Mr. Smelly Magic Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["21 Fly Paw of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.39
		end
	end,
}
Mod.items["771 Smelly Halo of Head Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.87
		end
	end,
}
Mod.items["234 My Gross Head of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
	end,
}
Mod.items["59 Mr. Sad Evil Coin Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["756 Fly Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.31
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
	end,
}
Mod.items["436 Bob's Ring"] = {
	evaluate_cache = nil,
}
Mod.items["235 Bob's Gross Book of Ring of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["224 Mr. Small Bomb Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.12
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.29000000000000004
		end
	end,
}
Mod.items["214 Cursed Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
	end,
}
Mod.items["493 Guppy's Magic Book of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.48
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.24
		end
	end,
}
Mod.items["566 My Lost Gross Bomb Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.45
		end
	end,
}
Mod.items["927 Mr. Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["368 My Coin Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["189 My Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.32
		end
	end,
}
Mod.items["218 Cube of Eye of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.09
		end
	end,
}
Mod.items["191 Bob's Evil Spider Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["292 Magic Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.1
		end
	end,
}
Mod.items["858 Mr. Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.27
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["545 Mom's Sacred Cube of Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.22
		end
	end,
}
Mod.items["857 Mom's Sticky Evil Meat of Pills"] = {
	evaluate_cache = nil,
}
Mod.items["470 Bob's Smelly Spider Head Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["604 Mr. Little Tiny Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.9299999999999997
		end
	end,
}
Mod.items["764 Super Demonic Book of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["996 Cursed Halo of Bag"] = {
	evaluate_cache = nil,
}
Mod.items["984 Mr. Sad Cube of Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["519 My Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["91 Cursed Coin Paw of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["338 Sad Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.72
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
	end,
}
Mod.items["758 My Cursed Bag of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["5 Small Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.6500000000000004
		end
	end,
}
Mod.items["567 Mom's Book of Box of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.91
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["793 My Boy"] = {
	evaluate_cache = nil,
}
Mod.items["109 Bob's Magic Paw of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.11
		end
	end,
}
Mod.items["466 Mom's Demonic Book of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
	end,
}
Mod.items["973 Mr. Bomb Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["696 Mom's Dead Bomb Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.36
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["560 Bob's Magic Book of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.3
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.26
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["507 Bob's Rotten Eye"] = {
	evaluate_cache = nil,
}
Mod.items["25 Mom's Poop 2.0"] = {
	evaluate_cache = nil,
}
Mod.items["211 My Fly Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.38
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["595 Bob's Little Fly Box Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["523 Cursed Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["479 Fly Kid of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["698 Mr. Turdy Gross Bomb Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["213 Bomb Paw da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["195 Sticky Sticky Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.33
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.21
		end
	end,
}
Mod.items["90 Mr. Dead Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.52
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["561 Super Holy Halo of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["643 Mom's Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 7
		end
	end,
}
Mod.items["88 Little Small Brain of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.69
		end
	end,
}
Mod.items["463 Turdy Sad Halo of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["349 Mom's Evil Mysterious Book of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.4
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["347 Mr. Gross Spider Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.9000000000000004
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["671 Bob's Rotten Fly Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.75
		end
	end,
}
Mod.items["499 Tiny Halo of Kid da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.43
		end
	end,
}
Mod.items["392 Mr. Gross Kid 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.28
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["184 Tiny Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.39
		end
	end,
}
Mod.items["265 Coin Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["426 Guppy's Demonic Book of Boy 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
	end,
}
Mod.items["393 Mysterious Ultra Halo of Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.22
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["268 Gross Lost Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 5.25
		end
	end,
}
Mod.items["365 Mr. Super Cursed Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.75
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
	end,
}
Mod.items["253 Bob's Box da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.22
		end
	end,
}
Mod.items["154 Spider Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["535 Magic Meat Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.83
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
	end,
}
Mod.items["509 Spider Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.39999999999999997
		end
	end,
}
Mod.items["448 Turdy Bomb Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["678 Guppy's Tiny Dead Fly Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.02
		end
	end,
}
Mod.items["289 Guppy's Magic Brain 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.48
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.4
		end
	end,
}
Mod.items["401 Little Coin Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.18
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["920 Mom's Lost Halo of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.81
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["200 Mom's Small Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.42
		end
	end,
}
Mod.items["994 Smelly Bag of Cards"] = {
	evaluate_cache = nil,
}
Mod.items["150 Bob's Fly Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["606 Mom's Book of Boy 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.3
		end
	end,
}
Mod.items["683 My Sad Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["418 Rotten Mysterious Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["461 Mom's Dead Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["709 Mr. Small Cube of Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["421 Sticky Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.53
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
	end,
}
Mod.items["911 Super Book of Head of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.31
		end
	end,
}
Mod.items["892 Smelly Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.25
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["997 Mr. Lost Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.82
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["308 Mr. Ultra Bomb Paw of Secrets"] = {
	evaluate_cache = nil,
}
Mod.items["17 Guppy's Halo of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.5
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["717 Turdy Mysterious Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["252 Mom's Book of Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["473 Magic Fly Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["381 Sticky Coin Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.21
		end
	end,
}
Mod.items["110 Bob's Evil Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.11
		end
	end,
}
Mod.items["404 Lost Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["515 Halo of Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 6.16
		end
	end,
}
Mod.items["202 Mr. Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.09
		end
	end,
}
Mod.items["188 Mom's Sacred Bomb Poop"] = {
	evaluate_cache = nil,
}
Mod.items["544 Ultra Sacred Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 5.77
		end
	end,
}
Mod.items["551 Dead Fly Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.21
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["747 Dead Mysterious Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 7
		end
	end,
}
Mod.items["589 Mr. Bomb Meat Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.13
		end
	end,
}
Mod.items["208 Mr. Spider Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["313 Dead Dead Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["755 Halo of Eye Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.39
		end
	end,
}
Mod.items["961 Smelly Halo of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["157 My Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["970 Demonic Smelly Book of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.57
		end
	end,
}
Mod.items["19 Mr. Turdy Spider Eye da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.65
		end
	end,
}
Mod.items["386 Evil Gross Spider Ring da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.26
		end
	end,
}
Mod.items["158 Guppy's Halo of Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["654 My Sacred Coin Kid 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 5
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["533 Mom's Coin Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.35
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.22
		end
	end,
}
Mod.items["685 Tiny Smelly Eye 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.32
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["532 Bob's Little Meat of Pills"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.64
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["963 Coin Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.23
		end
	end,
}
Mod.items["960 My Coin Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.33
		end
	end,
}
Mod.items["912 My Sticky Halo of Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.23
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["909 Mr. Lost Boy of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.93
		end
	end,
}
Mod.items["178 Ultra Holy Bag Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
	end,
}
Mod.items["913 Smelly Little Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.38
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.23
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["874 Smelly Cursed Coin Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["263 My Small Cube of Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.19
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["77 Turdy Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.62
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["396 Mom's Spider Eye"] = {
	evaluate_cache = nil,
}
Mod.items["299 Sacred Rotten Sack Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.59
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["111 Mom's Dead Sacred Brain of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
	end,
}
Mod.items["753 Mom's Ultra Bomb Eye da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.28
		end
	end,
}
Mod.items["432 Bob's Rotten Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.41000000000000003
		end
	end,
}
Mod.items["271 Bob's Sad Tiny Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["494 Rotten Bomb Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.48
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.33
		end
	end,
}
Mod.items["510 Demonic Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["587 Guppy's Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.42
		end
	end,
}
Mod.items["453 Bob's Lost Fly Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.84
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["572 Smelly Cube of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.46
		end
	end,
}
Mod.items["478 Bob's Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.08
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["623 Mr. Tiny Dead Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.09
		end
	end,
}
Mod.items["860 Mr. Spider Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 4
		end
	end,
}
Mod.items["371 Cube of Sack"] = {
	evaluate_cache = nil,
}
Mod.items["734 My Turdy Coin Ring Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
	end,
}
Mod.items["777 My Box of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.17
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.4
		end
	end,
}
Mod.items["203 Spider Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.22
		end
	end,
}
Mod.items["885 Holy Turdy Bomb Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.04
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["991 Bob's Little Sacred Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["434 Guppy's Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["451 Dead Coin Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.24
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["457 Bob's Poop Fetus"] = {
	evaluate_cache = nil,
}
Mod.items["152 Mom's Ultra Cube of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.26
		end
	end,
}
Mod.items["581 My Spider Kid"] = {
	evaluate_cache = nil,
}
Mod.items["107 Bob's Sacred Dead Paw da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.22
		end
	end,
}
Mod.items["823 Mom's Sticky Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.12
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["781 Halo of Kid of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.49
		end
	end,
}
Mod.items["616 Bob's Spider Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.91
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["982 Mr. Eye da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.67
		end
	end,
}
Mod.items["129 Tiny Kid of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 4.09
		end
	end,
}
Mod.items["657 Super Smelly Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
	end,
}
Mod.items["635 Coin Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.46
		end
	end,
}
Mod.items["814 Mom's Spider Paw Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.26
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.15
		end
	end,
}
Mod.items["941 Mom's Head of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.49
		end
	end,
}
Mod.items["440 Mysterious Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.29
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.6599999999999999
		end
	end,
}
Mod.items["449 Guppy's Sacred Super Coin Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.14
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["62 Cursed Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.74
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.59
		end
	end,
}
Mod.items["594 Holy Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
	end,
}
Mod.items["383 Bob's Magic Sticky Tears of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.6
		end
	end,
}
Mod.items["248 Bob's Meat of Flies"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["34 Mom's Spider Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 6
		end
	end,
}
Mod.items["314 Mr. Fly Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.84
		end
	end,
}
Mod.items["743 Bob's Eye"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["862 Mr. Evil Spider Head of Shadows"] = {
	evaluate_cache = nil,
}
Mod.items["123 Mom's Little Book of Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.31
		end
	end,
}
Mod.items["410 Sticky Book of Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["574 Holy Bomb Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.22
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.22999999999999998
		end
	end,
}
Mod.items["895 Lost Gross Poop Baby"] = {
	evaluate_cache = nil,
}
Mod.items["774 Halo of Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.52
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["736 Bob's Smelly Smelly Fly Brain 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.27
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.16
		end
	end,
}
Mod.items["725 Lost Cube of Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.17
		end
	end,
}
Mod.items["390 Mr. Turdy Gross Kid of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.1
		end
	end,
}
Mod.items["357 Mysterious Bag Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.1
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["829 Magic Coin Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.28
		end
	end,
}
Mod.items["628 Mom's Coin Kid"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["784 Demonic Turdy Book of Brain da Whoop"] = {
	evaluate_cache = nil,
}
Mod.items["31 My Evil Book of Box of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.13
		end
	end,
}
Mod.items["270 Bob's Spider Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.63
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["132 Spider Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 1
		end
	end,
}
Mod.items["546 My Magic Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.45
		end
	end,
}
Mod.items["179 Mr. Tiny Turdy Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.18
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.38
		end
	end,
}
Mod.items["400 Guppy's Small Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.06
		end
	end,
}
Mod.items["715 Tiny Bag Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.27
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 4
		end
	end,
}
Mod.items["553 Mom's Smelly Lost Halo of Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.47
		end
	end,
}
Mod.items["6 Guppy's Sacred Spider Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.37
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["742 Spider Paw"] = {
	evaluate_cache = nil,
}
Mod.items["538 Mr. Coin Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["923 Mom's Little Fly Box 2.0"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.94
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.15
		end
	end,
}
Mod.items["27 Mr. Sad Sad Fly Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.54
		end
	end,
}
Mod.items["943 Mom's Smelly Brain of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["416 Cube of Head of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.19
		end
	end,
}
Mod.items["359 Bob's Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.8
		end
	end,
}
Mod.items["830 Mr. Turdy Fly Poop"] = {
	evaluate_cache = nil,
}
Mod.items["173 Mysterious Lost Book of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.28
		end
	end,
}
Mod.items["367 Bob's Bomb Box of Cards"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
	end,
}
Mod.items["992 My Magic Coin Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.68
		end
	end,
}
Mod.items["18 Bob's Mysterious Boy of Pills"] = {
	evaluate_cache = nil,
}
Mod.items["358 Book of Sack"] = {
	evaluate_cache = nil,
}
Mod.items["373 Dead Little Fly Boy of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.83
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.33
		end
	end,
}
Mod.items["504 Book of Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.79
		end
	end,
}
Mod.items["978 Sad Magic Head of Pills"] = {
	evaluate_cache = nil,
}
Mod.items["58 My Spider Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.34
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.27
		end
	end,
}
Mod.items["565 My Lost Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.48
		end
	end,
}
Mod.items["336 Guppy's Gross Rotten Poop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["251 Turdy Turdy Cube of Box Worm"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 3
		end
	end,
}
Mod.items["70 Sad Box"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["204 Mom's Small Bomb Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.99
		end
	end,
}
Mod.items["429 Sad Rotten Coin Boy"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
	end,
}
Mod.items["242 Mr. Gross Turdy Coin Box of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.16
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["716 Book of Sack of Secrets"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 2.27
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["408 Bob's Ultra Coin Paw"] = {
	evaluate_cache = nil,
}
Mod.items["810 Mr. Sad Ring of Meat"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 1
		end
	end,
}
Mod.items["962 Mom's Little Halo of Paw"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.33
		end
	end,
}
Mod.items["422 Mom's Cursed Ultra Bomb Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.33
		end
	end,
}
Mod.items["93 Mom's Mysterious Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 3
		end
	end,
}
Mod.items["897 Spider Head"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["196 Bomb Tears of Flies"] = {
	evaluate_cache = nil,
}
Mod.items["319 Tiny Lost Head of Shadows"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.12
		end
	end,
}
Mod.items["946 Ultra Bag Fetus"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.0700000000000003
		end
	end,
}
Mod.items["254 Sticky Turdy Spider Brain"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["376 Gross Rotten Head Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_LUCK then
			player.Luck = player.Luck + 2
		end
	end,
}
Mod.items["71 Bob's Little Sack"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.82
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.11
		end
	end,
}
Mod.items["815 Coin Bag"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.0
		end
	end,
}
Mod.items["540 My Cube of Ring"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.11
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.37
		end
	end,
}
Mod.items["95 Mom's Evil Head"] = {
	evaluate_cache = nil,
}
Mod.items["343 Mom's Mysterious Kid da Whoop"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_SPEED then
			player.MoveSpeed = player.MoveSpeed + 0.17
		end
		if flag == CacheFlag.CACHE_SHOTSPEED then
			player.ShotSpeed = player.ShotSpeed + 0.23
		end
	end,
}
Mod.items["456 Gross Holy Coin Tears"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_FIREDELAY then
			player.MaxFireDelay = player.MaxFireDelay - 2
		end
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 1.77
		end
	end,
}
Mod.items["227 Bob's Sacred Spider Sack Baby"] = {
	evaluate_cache = function (self, player, flag)
		if flag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + 3.28
		end
	end,
}
for i, name in pairs(Mod.item_names) do
	local id = Isaac.GetItemIdByName(name)
	local def = Mod.items[id] or Mod.items[name] or {}
	Mod.items[id] = def
	Mod.items[name] = def

	table.insert(Mod.item_ids, id)
	Mod.item_id_to_name[id] = name
	Mod.item_name_to_id[name] = id
end
