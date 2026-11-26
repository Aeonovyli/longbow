local S = core.get_translator(core.get_current_modname())

local BOW_DURABILITY = 577.5

local BOW_CHARGE_TIME_HALF = 300000
local BOW_CHARGE_TIME_FULL = 750000

local LONG_BOW_WIELD_SCALE = vector.new(
	mcl_vars.tool_wield_scale.x * 4 / 3,
	mcl_vars.tool_wield_scale.y * 4 / 3,
	mcl_vars.tool_wield_scale.z
)

local PLAYER_USE_BOW_SPEED = tonumber(core.settings:get("movement_speed_crouch")) / tonumber(core.settings:get("movement_speed_walk"))

local BOW_MAX_SPEED = 80
local BOW_FULL_DAMAGE = 22
local BOW_CRITICAL_DAMAGE = 25

local bow_load = {}

local bow_index = {}

local bow_load_level = {}

mcl_fovapi.register_modifier({
	name = "bowcomplete",
	fov_factor = 0.8,
	time = 1,
	reset_time = 0.3,
	is_multiplier = true,
})

function mcl_bows.shoot_arrow(arrow_item, pos, dir, yaw, shooter, power, damage, is_critical, bow_stack, collectable)
	power = power or BOW_MAX_SPEED
	damage = damage or 4.5

	local obj = vl_projectile.create(arrow_item.."_entity", {
		pos = pos,
		dir = dir,
		velocity = power,
		owner = shooter,
	})

	local knockback
	if bow_stack then
		local enchantments = mcl_enchanting.get_enchantments(bow_stack)
		if enchantments.power then
			damage = damage + (enchantments.power + 1) / 4
		end
		if enchantments.punch then
			knockback = enchantments.punch * 4.5
		else
			knockback = 1.5
		end
		if enchantments.flame then
			mcl_burning.set_on_fire(obj, math.huge)
		end
	end
	local le = obj:get_luaentity()
	le._source_object = shooter
	le._damage = damage
	le._is_critical = is_critical
	le._knockback = knockback
	le._collectable = collectable
	le._arrow_item = arrow_item
	local item_def = core.registered_items[le._arrow_item]
	if item_def and item_def._arrow_image then
		obj:set_properties({textures = item_def._arrow_image})
	end
	core.sound_play("mcl_bows_bow_shoot", {pos=pos, max_hear_distance=16}, true)
	if shooter and shooter:is_player() then
		if le.player == "" then
			le.player = shooter
		end
		le.node = shooter:get_inventory():get_stack("main", 1):get_name()
	end
	return obj
end

local function get_arrow(player)
	local inv = player:get_inventory()
	local arrow_stack, arrow_stack_id
	for i=1, inv:get_size("main") do
		local it = inv:get_stack("main", i)
		if not it:is_empty() and core.get_item_group(it:get_name(), "ammo_bow") ~= 0 then
			arrow_stack = it
			arrow_stack_id = i
			break
		end
	end
	return arrow_stack, arrow_stack_id
end

local function player_shoot_arrow(itemstack, player, power, damage, is_critical)
	local arrow_stack, arrow_stack_id = get_arrow(player)
	local arrow_itemstring
	local has_infinity_enchantment = mcl_enchanting.has_enchantment(player:get_wielded_item(), "infinity")
	local infinity_used = false

	if core.is_creative_enabled(player:get_player_name()) then
		if arrow_stack then
			arrow_itemstring = arrow_stack:get_name()
		else
			arrow_itemstring = "mcl_bows:arrow"
		end
		infinity_used = true
	else
		if not arrow_stack then
			return false
		end
		arrow_itemstring = arrow_stack:get_name()
		if has_infinity_enchantment and core.get_item_group(arrow_itemstring, "ammo_bow_regular") > 0 then
			infinity_used = true
		else
			arrow_stack:take_item()
		end
		local inv = player:get_inventory()
		inv:set_stack("main", arrow_stack_id, arrow_stack)
	end
	if not arrow_itemstring then
		return false
	end
	local playerpos = player:get_pos()
	local dir = player:get_look_dir()
	local yaw = player:get_look_horizontal()

	mcl_bows.shoot_arrow(arrow_itemstring, {x=playerpos.x,y=playerpos.y+1.5,z=playerpos.z}, dir, yaw, player, power, damage, is_critical, player:get_wielded_item(), not infinity_used)
	return true
end

core.register_tool("longbow:longbow", {
	description = S("Longbow"),
	_tt_help = S("Launches arrows"),
	_doc_items_longdesc = S("Longbows are powerful ranged weapons to shoot arrows at your foes.").."\n"..
S("The speed and damage of the arrow increases the longer you charge. The regular damage of the arrow is between 1 and 22. At full charge, there's also a 20% chance of a critical hit, dealing 25 damage instead.").."\n"..
S("The longbow can be combined with a regular bow on an anvil. Put the longbow in the first slot to keep the result a longbow."),
	_doc_items_usagehelp = S("To use the bow, you first need to have at least one arrow anywhere in your inventory (unless in Creative Mode). Hold down the right mouse button (or the zoom key) to charge, release to shoot."),
	_doc_items_durability = BOW_DURABILITY,
	inventory_image = "longbow.png",
	wield_scale = LONG_BOW_WIELD_SCALE,
	stack_max = 1,
	range = 4,
	on_use = function() return end,
	on_place = function(itemstack, player, pointed_thing)
		if pointed_thing and pointed_thing.type == "node" then
			local node = core.get_node(pointed_thing.under)
			if player and not player:get_player_control().sneak then
				if core.registered_nodes[node.name] and core.registered_nodes[node.name].on_rightclick then
					return core.registered_nodes[node.name].on_rightclick(pointed_thing.under, node, player, itemstack) or itemstack
				end
			end
		end

		itemstack:get_meta():set_string("active", "true")
		return itemstack
	end,
	on_secondary_use = function(itemstack)
		itemstack:get_meta():set_string("active", "true")
		return itemstack
	end,
	groups = {weapon=1,weapon_ranged=1,bow=1,cannot_block=1,enchantability=1},
	touch_interaction = "short_dig_long_place",
	_mcl_uses = 577.5,
})

local function is_longbow(itemstack)
	local name = itemstack:get_name()
	return name == "longbow:longbow" or name == "longbow:longbow_enchanted"
end

local function is_regular_bow(itemstack)
	local name = itemstack:get_name()
	return name == "mcl_bows:bow" or name == "mcl_bows:bow_enchanted"
end

core.register_on_mods_loaded(function()
	local enchanted_longbow = "longbow:longbow_enchanted"
	core.override_item("longbow:longbow", {
		_mcl_enchanting_enchanted_tool = enchanted_longbow,
	})
	core.override_item("longbow:longbow_enchanted", {
		_mcl_enchanting_enchanted_tool = enchanted_longbow,
	})

	local original_combine = mcl_enchanting.combine
	mcl_enchanting.combine = function(itemstack, combine_with)
		local first_is_longbow = is_longbow(itemstack)
		local second_is_longbow = is_longbow(combine_with)
		local is_bow_pair = (first_is_longbow and is_regular_bow(combine_with))
			or (is_regular_bow(itemstack) and second_is_longbow)
		if not is_bow_pair then
			return original_combine(itemstack, combine_with)
		end

		local first_name = itemstack:get_name()
		local second_name = combine_with:get_name()
		if first_is_longbow then
			itemstack:set_name(first_name == "longbow:longbow_enchanted"
				and "mcl_bows:bow_enchanted" or "mcl_bows:bow")
		end
		if second_is_longbow then
			combine_with:set_name(second_name == "longbow:longbow_enchanted"
				and "mcl_bows:bow_enchanted" or "mcl_bows:bow")
		end

		local combined = original_combine(itemstack, combine_with)

		if first_is_longbow then
			itemstack:set_name(itemstack:get_name() == "mcl_bows:bow_enchanted"
				and "longbow:longbow_enchanted" or "longbow:longbow")
		end
		if second_is_longbow then
			combine_with:set_name(second_name)
		end

		return combined or next(mcl_enchanting.get_enchantments(combine_with)) == nil
	end
end)

local function reset_bows(player)
	local inv = player:get_inventory()
	local list = inv:get_list("main")
	for place, stack in pairs(list) do
	if stack:get_name() == "longbow:longbow"
    	or stack:get_name() == "longbow:longbow_enchanted" then
    	stack:get_meta():set_string("active", "")
    	stack:get_meta():set_string("inventory_image", "")
		elseif stack:get_name()=="longbow:bow_0" or stack:get_name()=="longbow:bow_1" or stack:get_name()=="longbow:bow_2" then
			stack:set_name("longbow:bow")
			stack:get_meta():set_string("active", "")
			list[place] = stack
		elseif stack:get_name()=="longbow:bow_0_enchanted" or stack:get_name()=="longbow:bow_1_enchanted" or stack:get_name()=="longbow:bow_2_enchanted" then
			stack:set_name("longbow:bow_enchanted")
			stack:get_meta():set_string("active", "")
			list[place] = stack
		end
	end
	inv:set_list("main", list)
end

local function reset_bow_state(player, also_reset_bows)
	mcl_fovapi.remove_modifier(player, "bowcomplete")

	bow_load[player:get_player_name()] = nil
	bow_index[player:get_player_name()] = nil
	bow_load_level[player:get_player_name()] = nil
	if core.get_modpath("playerphysics") then
		playerphysics.remove_physics_factor(player, "speed", "longbow:use_bow")
	end
	if also_reset_bows then
		reset_bows(player)
	end
end

for level=0, 2 do
	core.register_tool("longbow:bow_"..level, {
		description = S("Longbow"),
		_doc_items_create_entry = false,
		inventory_image = "longbow.png^vl_unknown.png",
		wield_scale = LONG_BOW_WIELD_SCALE,
		stack_max = 1,
		range = 0,
		groups = {not_in_creative_inventory=1, not_in_craft_guide=1, bow=1, cannot_block=1, enchantability=1},
		on_use = function(_, user) reset_bow_state(user, true) return end,
		on_drop = function(itemstack, dropper, pos)
			reset_bow_state(dropper)
			itemstack:get_meta():set_string("active", "")
			if mcl_enchanting.is_enchanted(itemstack:get_name()) then
				itemstack:set_name("longbow:longbow_enchanted")
			else
				itemstack:set_name("longbow:longbow")
			end
			core.item_drop(itemstack, dropper, pos)
			itemstack:take_item()
			return itemstack
		end,
		on_place = function(itemstack, placer)
			reset_bow_state(placer, true)
			return itemstack
		end,
		touch_interaction = "short_dig_long_place",
		_mcl_uses = 385,
	})
end


controls.register_on_release(function(player, key, time)
	if key~="RMB" and key~="zoom" then return end
	local wielditem = player:get_wielded_item()
	local name = wielditem:get_name()
	if name == "longbow:longbow" or name == "longbow:longbow_enchanted" then
		local meta = wielditem:get_meta()
		if not core.is_yes(meta:get("active")) then
			reset_bow_state(player)
			return
		end
		local enchanted = mcl_enchanting.is_enchanted(name)
		local speed, damage
		local p_load = bow_load[player:get_player_name()]
		local charge
		if type(p_load) == "number" then
			charge = core.get_us_time() - p_load
		else
			charge = 0
			core.log("warning", "[mcl_bows] Player "..player:get_player_name().." fires arrow with non-numeric bow_load!")
		end
		charge = math.max(math.min(charge, BOW_CHARGE_TIME_FULL), 0)

		local charge_ratio = charge / BOW_CHARGE_TIME_FULL
		charge_ratio = math.max(math.min(charge_ratio, 1), 0)

		local is_critical = false
		if charge >= BOW_CHARGE_TIME_FULL then
			speed = BOW_MAX_SPEED
			local r = math.random(1,5) + mcl_luck.get_luck(player:get_player_name())
			if r > 4 then
				damage = BOW_CRITICAL_DAMAGE
				is_critical = true
			else
				damage = BOW_FULL_DAMAGE
			end
		else
			speed = math.max(4, BOW_MAX_SPEED * charge_ratio)
			damage = math.max(1, math.floor(BOW_FULL_DAMAGE * charge_ratio))
		end

		local has_shot = player_shoot_arrow(wielditem, player, speed, damage, is_critical)

		if has_shot and not core.is_creative_enabled(player:get_player_name()) then
			local durability = BOW_DURABILITY
			local unbreaking = mcl_enchanting.get_enchantment(wielditem, "unbreaking")
			if unbreaking > 0 then
				durability = durability * (unbreaking + 1)
			end
			wielditem:add_wear(65535/durability)
			tt.reload_itemstack_description(wielditem)
		end
		player:set_wielded_item(wielditem)
		reset_bow_state(player, true)
	end
end)

controls.register_on_hold(function(player, key, time)
	local name = player:get_player_name()
	local creative = core.is_creative_enabled(name)
	if (key ~= "RMB" and key ~= "zoom") or not (creative or get_arrow(player)) then
		return
	end
	local wielditem = player:get_wielded_item()
	local meta = wielditem:get_meta()
	if bow_load[name] == nil
		and (wielditem:get_name()=="longbow:longbow" or wielditem:get_name()=="longbow:longbow_enchanted")
		and (core.is_yes(meta:get("active")) or key == "zoom") and (creative or get_arrow(player)) then
			local enchanted = mcl_enchanting.is_enchanted(wielditem:get_name())
			local im_string = "longbow_longbow_0.png"
			if enchanted then im_string = im_string .. mcl_enchanting.overlay end
			meta:set_string("inventory_image", im_string)
			player:set_wielded_item(wielditem)
			if core.get_modpath("playerphysics") then
				playerphysics.add_physics_factor(player, "speed", "longbow:use_bow", PLAYER_USE_BOW_SPEED)
			end
			bow_load[name] = core.get_us_time()
			bow_load_level[name] = 0
			bow_index[name] = player:get_wield_index()

			mcl_fovapi.apply_modifier(player, "bowcomplete")
	else
		if player:get_wield_index() == bow_index[name] then
			if type(bow_load[name]) == "number" then
				local level = 0
				if core.get_us_time() - bow_load[name] >= BOW_CHARGE_TIME_FULL then
					if bow_load_level[name] == 2 then return end
					level = 2
					bow_load_level[name] = 2
				elseif core.get_us_time() - bow_load[name] >= BOW_CHARGE_TIME_HALF then
					if bow_load_level[name] == 1 then return end
					level = 1
					bow_load_level[name] = 1
				else return end
				local im_string = "longbow_longbow_"..level..".png"
				if wielditem:get_name() == "longbow:longbow_enchanted" then
					im_string = im_string .. mcl_enchanting.overlay
				end
				meta:set_string("inventory_image", im_string)
			else
				meta:set_string("inventory_image", "")
				bow_load_level[name] = nil
			end
			player:set_wielded_item(wielditem)
		elseif bow_load[name] then
			reset_bow_state(player, true)
		end
	end
end)

core.register_globalstep(function(dtime)
	for _, player in pairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local wielditem = player:get_wielded_item()
		local wieldindex = player:get_wield_index()
		if type(bow_load[name]) == "number"
				and ((wielditem:get_name()~="longbow:longbow" and wielditem:get_name()~="longbow:longbow_enchanted")
				or wieldindex ~= bow_index[name]) then
			reset_bow_state(player, true)
		end
	end
end)

core.register_on_joinplayer(function(player)
	reset_bows(player)
end)

core.register_on_leaveplayer(function(player)
	reset_bow_state(player, true)
end)

if core.get_modpath("mcl_core") and core.get_modpath("mcl_mobitems") then
	core.register_craft({
		output = "longbow:longbow",
		recipe = {
			{"", "mcl_core:stick", "mcl_mobitems:string"},
			{"mcl_core:stick", "", "mcl_mobitems:string"},
			{"", "mcl_core:stick", "mcl_mobitems:string"},
		}
	})
	core.register_craft({
		output = "longbow:longbow",
		recipe = {
			{"mcl_mobitems:string", "mcl_core:stick", ""},
			{"mcl_mobitems:string", "", "mcl_core:stick"},
			{"mcl_mobitems:string", "mcl_core:stick", ""},
		}
	})
end

core.register_craft({
	type = "fuel",
	recipe = "longbow:longbow",
	burntime = 15,
})

core.register_craft({
    output = "longbow:longbow",
    recipe = {
        {"", "group:wood", "mcl_mobitems:string"},
        {"group:wood", "", "mcl_mobitems:string"},
        {"", "group:wood", "mcl_mobitems:string"},
    }
})

core.register_craft({
    output = "longbow:longbow",
    recipe = {
        {"mcl_mobitems:string", "group:wood", ""},
        {"mcl_mobitems:string", "", "group:wood"},
        {"mcl_mobitems:string", "group:wood", ""},
    }
})
