if minetest.settings:get_bool("enable_weather") == false or
		not minetest.global_exists("sscsm") then
	return
end

if (PLATFORM == "Android" or PLATFORM == "iOS") and
		(tonumber(minetest.settings:get("viewing_range")) or 0) <= 50 then
	return
end

local S = minetest.get_translator("weather_lite")

local random = math.random
local snow_covers = minetest.settings:get_bool("weather_snow_covers") ~= false

local weather = {
	type = "none",
	wind = {x = 0, y = 0, z = 0},
	duration = 0
}


--
-- Save and restore weather condition
--

local mod_storage = minetest.get_mod_storage()

do
	local saved_weather = minetest.deserialize(
			mod_storage:get_string("weather"))
	if type(saved_weather) == "table" then
		weather = saved_weather
	end
	weather.duration = weather.duration or random(30, 150)
end

minetest.register_on_shutdown(function()
	mod_storage:set_string("weather", minetest.serialize(
			({type = weather.type, wind = weather.wind})))
end)


--
-- Registration of weather types
--

weather.registered = {}
function weather.register(id, def)
	local ndef = table.copy(def)
	weather.registered[id] = ndef
end

-- Rain
weather.register("rain", {
	desc = S("Rain"),
	falling_speed = 5,
	amount = 6,
	size = 20,
	height = 3,
	vertical = true,
	texture = "weather_lite_rain.png"
})

-- Snow
weather.register("snow", {
	desc = S("Snow"),
	falling_speed = 2,
	amount = 5,
	size = 35,
	height = 2,
	texture = "weather_lite_snow.png"
})


--
-- Change of weather
--

local function weather_change()
	if weather.type == "none" then
		for w in pairs(weather.registered) do
			if random(3) == 1 then
				local duration = random(60, 300)
				weather.set(w, {
					x = random(0, 8),
					y = 0,
					z = random(0, 8)
				}, duration)
				return
			end
		end
	end
	minetest.after(random(1800, 3600), weather_change)
end
minetest.after(random(600, 1800), weather_change)

function weather.set(weather_type, wind, duration)
	weather.type = weather_type
	weather.duration = duration or 0
	if wind then
		weather.wind = wind
	end

	sscsm.com_send_all("weather_lite:set", {
		type = weather_type,
		wind = wind
	})
end


--
-- Processing players
--

local ltimer, wtimer = 0, 0
minetest.register_globalstep(function(dtime)
	local current_downfall = weather.registered[weather.type]
	if current_downfall == nil then
		ltimer, wtimer = 0, 0
		return
	end

	ltimer = ltimer + dtime
	if ltimer > 15 then
		if random(4) == 1 then
			lightning.strike()
		end
		ltimer = 0
	end

	wtimer = wtimer + dtime
	if wtimer > weather.duration then
		weather.set("none")
		wtimer = 0
	end
end)


--
-- Snow will cover the blocks and melt after some time
--

if snow_covers then
	-- Temp node to start the node timer
	minetest.register_node("weather_lite:snow_cover", {
		tiles = {"blank.png"},
		drawtype = "signlike",
		paramtype = "light",
		buildable_to = true,
		groups = {not_in_creative_inventory = 1, dig_immediate = 3},
		on_construct = function(pos)
			minetest.get_node_timer(pos):start(random(60, 180))
			minetest.swap_node(pos, {name = "default:snow"})
		end
	})

	minetest.override_item("default:snow", {
		on_timer = function(pos)
			if weather and weather.type and weather.type == "snow" then
				return true
			end

			minetest.remove_node(pos)
		end
	})

	minetest.register_abm({
		label = "Weather: snow cover",
		nodenames = {"group:crumbly", "group:snappy", "group:cracky", "group:choppy"},
		neighbors = {"air"},
		interval = 15,
		chance = 500,
		catch_up = false,
		action = function(pos, node)
			if weather.type == "snow" then
				if pos.y < -8 or pos.y > 120 then return end
				if minetest.registered_nodes[node.name].drawtype == "normal"
				or minetest.registered_nodes[node.name].drawtype == "allfaces_optional" then
					pos.y = pos.y + 1
					if minetest.get_node(pos).name ~= "air" then return end
					local light_day = minetest.get_node_light(pos, 0.5)
					local light_night = minetest.get_node_light(pos, 0)
					if  light_day   and light_day  == 15
					and light_night and light_night < 10 then
						minetest.add_node(pos, {name = "weather_lite:snow_cover"})
					end
				end
			end
		end
	})
end

minetest.register_privilege("weather", {
	description = "Allows changing the weather",
	give_to_singleplayer = minetest.settings:get_bool("creative_mode")
})

minetest.register_chatcommand("weather", {
	params = S("<weather>"),
	description = S("Setting the weather type"),
	privs = {weather = true},
	func = function(name, param)
		if param and (weather.registered[param] or param == "none") then
			local duration = param ~= "none" and random(60, 300)
			weather.set(param, nil, duration)
			if param == "none" then
				minetest.chat_send_player(name, S("Set clear weather."))
			else
				local setw = weather.registered[param].desc or param:gsub("^%l", string.upper)
				minetest.chat_send_player(name, S("Set weather type: @1.", setw))
			end
		else
			local types = "none"
			for w in pairs(weather.registered) do
				types = types .. ", " .. w
			end
			minetest.chat_send_player(name, S("Available weather types: @1.", types))
		end
	end
})

sscsm.register({
	name = "weather_lite",
	file = minetest.get_modpath("weather_lite") .. "/sscsm.lua"
})

local liquids
sscsm.register_on_sscsms_loaded(function(name)
	if not liquids then
		liquids = {}
		for node, def in pairs(minetest.registered_nodes) do
			if def.drawtype == "liquid" then
				liquids[node] = true
			end
		end
	end

	local player = minetest.get_player_by_name(name)
	sscsm.com_send(name, "weather_lite:set", {
		type = weather.type,
		wind = weather.wind,
		registered = weather.registered,
		cloud_height = player:get_clouds().height,
		liquids = liquids
	})
end)
