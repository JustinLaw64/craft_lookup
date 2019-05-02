-- Craft Lookup
-- Copyright 2017 Justin Law

local mod, private = ...
local tablelib = private.tablelib

-- Variables
mod.contexts = {} -- Information the mod uses to track players. Contexts accessed by player's name.
mod.database = nil -- Table containing navigation information of items and crafting recipes.

function private.print(playername, msg)
	minetest.chat_send_player(playername, "[craft_lookup] "..tostring(msg))
end

-- Backend Functions
function mod.catalog_items()
	if mod.database == nil then
		-- Create skeleton database structure.
		local itemlist = {}
		local grouplist = {}
		local database = {
			items = itemlist,
			groups = grouplist,
		}
		
		local get_group_data, add_ingredient_record
		function get_group_data(groupname)
			local r = grouplist[groupname]
			if r == nil then
				r = {
					members = {},
					recipes_ingredient = {},
				}
				grouplist[groupname] = r
			end
			return r
		end
		-- Function for adding recipes other items are ingredients of.
		function add_ingredient_record(input_itemname, recipe)
			local is_group, groupname = mod.is_group(input_itemname)
			if not is_group then
				-- Create item data if it's not there
				local data2 = itemlist[input_itemname]
				if data2 == nil then
					data2 = {
						name = input_itemname,
						recipes_ingredient = {},
						not_complete = true,
					}
					itemlist[input_itemname] = data2
				end
				-- Add this recipe to the item data.
				if tablelib.indexof(data2.recipes_ingredient, recipe) == nil then
					table.insert(data2.recipes_ingredient, recipe)
				end
			else
				-- Add this recipe to the relevant group data, and let existing
				-- members know they are used in a recipe.
				local data2 = get_group_data(groupname)
				if tablelib.indexof(data2.recipes_ingredient, recipe) == nil then
					table.insert(data2.recipes_ingredient, recipe)
					for k, v in pairs(data2.members) do
						if tablelib.indexof(v.recipes_ingredient, recipe) == nil then
							table.insert(v.recipes_ingredient, recipe)
						end
					end
				end
			end
		end
		
		-- Construct recipe information from everything registered to the minetest engine.
		for k,v in pairs(minetest.registered_items) do -- k = item name, v = definition
			if v.groups and (v.groups.not_in_creative_inventory or 0) < 1
				and v.description and v.description ~= "" then
				local data = {
					name = k,
					def = v,
					recipes_result = minetest.get_all_craft_recipes(k) or {},
					recipes_ingredient = ((itemlist[k] ~= nil and itemlist[k].not_complete) and itemlist[k].recipes_ingredient or {}),
					not_complete = nil,
				}
				
				-- Record self in group data.
				for k2, v2 in pairs(v.groups) do -- k2 = group name, v2 = group level
					if v2 ~= nil and v2 > 0 then
						get_group_data(k2).members[k] = data -- Add self
						
						-- Make group membership imply recipe involvement.
						for i, recipe in ipairs(grouplist[k2].recipes_ingredient) do
							add_ingredient_record(k, recipe)
						end
					end
				end
				
				-- Reconstruct fuel recipe in recipes_ingredient if one is around
				local fuel_output_info, fuel_decremented_input =
					minetest.get_craft_result({method = "fuel", width = 1, items = {ItemStack(k)}})
				if fuel_output_info.time > 0 then
					table.insert(data.recipes_ingredient, {
						type = "fuel",
						method = "fuel",
						burntime = fuel_output_info.time,
						items = {k},
						width = 1,
					})
				end
				
				-- Add recipes other items are ingredients of.
				for k2, v2 in pairs(data.recipes_result) do -- v2 = recipe
					for k3,v3 in pairs(v2.items) do
						add_ingredient_record(v3, v2)
					end
				end
				
				-- Add self to catalog
				itemlist[k] = data
			end
		end
		
		-- Clean up unfinished item defs.
		for k, v in pairs(itemlist) do
			if v.not_complete then
				itemlist[k] = nil
			end
		end
		
		mod.database = database
	end
end
function mod.is_group(itemstring)
	assert(type(itemstring) == "string")
	
	local r, r2 = false, nil
	if string.sub(itemstring, 1, 6) == "group:" then
		r, r2 = true, string.sub(assert(itemstring), 7)
	end
	return r, r2
end
function mod.is_visible_to(playercontext, itemname)
	return not mod.progressive_mode or mod.discovery.knows(playercontext.playername, itemname)
end

-- List Processing
function mod.filterby_group(deflist, groupname)
	local r, all = {}, true
	for k, v in pairs(deflist) do
		if (v.def.groups[groupname] or 0) > 0 then
			r[v.name] = v
		else
			all = false
		end
	end
	return (all and deflist or r), all
end
function mod.filterby_deflist(deflist, deflist2)
	-- You can merely use names and booleans key-value-pairs in deflist2.
	local r, all = {}, true
	for k,v in pairs(deflist) do
		if deflist2[v.name] then
			r[v.name] = v
		else
			all = false
		end
	end
	return (all and deflist or r), all
end
function mod.filterby_searchterm(deflist, searchterm)
	local r, all
	local is_group, groupname = mod.is_group(searchterm)
	if is_group then
		r, all = mod.filterby_group(deflist, groupname), false
	else
		r, all = {}, true
		if searchterm ~= nil and searchterm ~= "" then
			for k,v in pairs(deflist) do
				if string.match(v.name, searchterm) or string.match(v.def.description or "", searchterm) then
					r[v.name] = v
				else all = false
				end
			end
		else
			for k,v in pairs(deflist) do
				r[v.name] = v
			end
		end
	end
	return (all and deflist or r), all
end
function mod.filterby_searchtype(deflist, searchtype, playercontext)
	if type(deflist) ~= "table" then
		error("deflist unexpected type. Expected table.")
	end
	local r
	if searchtype == 1 then
		r = deflist
	elseif searchtype == 2 then
		r = mod.filterby_deflist(deflist, minetest.registered_nodes)
	elseif searchtype == 3 then
		r = mod.filterby_deflist(deflist, minetest.registered_tools)
	elseif searchtype == 4 then
		r = mod.filterby_deflist(deflist, minetest.registered_craftitems)
	elseif searchtype == 5 then -- Only situation where playercontext is required.
		if tablelib.indexof(mod.contexts, playercontext) ~= nil then
			r = {}
			local list = mod.to_named_deflist(deflist)
			local player = minetest.get_player_by_name(playercontext.playername)
			local playerinv = player:get_inventory()
			for i, v in ipairs(playerinv:get_list("main")) do
				if v ~= nil and v:get_count() > 0 and list[v:get_name()] ~= nil then
					table.insert(r, list[v:get_name()])
				end
			end
		else
			error("Can't filter by inventory (5) without knowing whoes inventory to use.")
		end
	else
		error("searchtype is unexpected value.")
	end
	return r
end
function mod.filterby_player(deflist, playercontext)
	local r, all = {}, true
	for k,v in pairs(deflist) do
		if mod.is_visible_to(playercontext, k) then
			r[v.name] = v
		else
			all = false
		end
	end
	return (all and deflist or r), all
end
function mod.to_indexed_deflist(deflist)
	local r = {}
	for k, v in pairs(deflist) do
		table.insert(r, v)
	end
	table.sort(r, function(defa, defb)
		return defa.name < defb.name
	end)
	return r
end
function mod.to_named_deflist(deflist)
	local r = {}
	for k, v in pairs(deflist) do
		r[v.name] = v
	end
	return r
end

minetest.register_on_joinplayer(function(player)
	-- Ensures the craft database is created before a player does anything.
	mod.catalog_items()
	
	-- Set up an environment specific to the player.
	local playername = player:get_player_name()
	mod.contexts[playername] = {
		playername = playername,
		known_items = {}, -- Item name is key and boolean is value
		gui_list_search_term = "",
		gui_list_search_type = 1,
		gui_list_search_cache = nil, -- Indexed
		gui_list_page = 1,
		gui_recipe_item = nil,
		gui_recipe_page = 1,
		gui_recipe_mode = 1, -- 1 = As output, 2 = As ingredient
	}
end)
minetest.register_on_leaveplayer(function(player)
	mod.contexts[player:get_player_name()] = nil
end)
minetest.after(0.01, function()
	mod.catalog_items()
end)
