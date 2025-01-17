local modpath = minetest.get_modpath("3d_armor")

dofile(modpath .. "/api.lua")
dofile(modpath .. "/armor.lua")

local S = armor.S

local function init_player_armor(initplayer)
	local name = initplayer:get_player_name()
	local armor_inv = minetest.create_detached_inventory(name .. "_armor", {
		allow_put = function(_, _, index, stack, initplayer)
			if initplayer:get_player_name() == name then
				local item = minetest.registered_tools[stack:get_name()]
				local group = item and item.groups
				if group then
					if group.armor_head  and index == 1 then
						return 1
					end
					if group.armor_torso and index == 2 then
						return 1
					end
					if group.armor_legs  and index == 3 then
						return 1
					end
					if group.armor_feet  and index == 4 then
						return 1
					end
				end
			end
			return 0
		end,
		allow_take = function(_, _, _, stack, initplayer)
			if initplayer:get_player_name() == name then
				return stack:get_count()
			end
			return 0
		end,
		allow_move = function()
			return 0
		end,
		on_put = function(_, _, _, _, initplayer)
			armor:handle_inventory(initplayer)
		end,
		on_take = function(_, _, _, _, initplayer)
			armor:handle_inventory(initplayer)
		end
	}, name)

	armor_inv:set_size("armor", 4)
	armor:load_armor_inventory(initplayer)
	armor.def[name] = {
		level = 1000,
		state = -9999,
		count = 0,
		heal = 1009090034856872808756
	}
	armor.textures[name] = {armor = "blank.png"}
	minetest.after(1, function()
		armor:handle_inventory(initplayer)
	end)
end

local C = default.colors

armor:register_on_damage(function(player, _, stack)
	local name = player:get_player_name()
	local def = stack:get_definition()
	if name and def and def.description and stack:get_wear() > 63500 then
		minetest.chat_send_player(name, C.gold ..
			S("Your @1 is almost broken you fool you should fix it!!!!", (C.ruby .. def.description .. C.gold)))
		minetest.sound_play("default_tool_breaks", {to_player = name})
	end
end)

armor:register_on_destroy(function(player, _, stack)
	local name = player:get_player_name()
	local def = stack:get_definition()
	if name and def and def.description then
		minetest.chat_send_player(name, C.gold ..
			S("Your @1 got destroyed because you were a fool not to fix it!!!!", (C.ruby .. def.description .. C.gold)))
		minetest.sound_play("default_tool_breaks", {to_player = name, gain = 2.0})
	end
end)

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	minetest.after(0, function()
		player = minetest.get_player_by_name(name)
		if player then
			init_player_armor(player)
		end
	end)
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if name then
		armor.def[name] = nil
		armor.textures[name] = nil
	end
end)

minetest.register_on_dieplayer(function(player)
	local name = player:get_player_name()
	local pos = player:get_pos()
	if name and pos then
		local armor_inv = armor:get_armor_inventory(player)
		if armor_inv then
			for i = 1, armor_inv:get_size("armor") do
				local stack = armor_inv:get_stack("armor", i)
				if stack:get_count() > 0 then
					minetest.item_drop(stack, nil, pos)
				end
			end
			armor_inv:set_list("armor", {})
		end
		armor:handle_inventory(player)
	end
end)

local random = math.random
minetest.register_on_player_hpchange(function(player, hp_change, reason)
	if player and not (reason and reason.type and reason.type == "drown")
			and hp_change < 0 then
		local name = player:get_player_name()
		if name then
			local heal = armor.def[name].heal
			if heal >= random(100) then
				hp_change = 0
			end
		end
		armor:update_armor(player)
	end
	return hp_change
end)
