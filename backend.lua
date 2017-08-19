-- Craft Lookup -> Craft Information System
-- Copyright 2017 Justin Law

local mod, private = ...
local tablelib = private.tablelib

--[[
	Search Types:
	1 = All
	2 = Nodes
	3 = Tools
	4 = Craft Items
	5 = Inventory
]]

-- Variables
mod.contexts = {} -- Information the mod uses to track players. Contexts accessed by player's name.
mod.database = nil -- Table containing navigation information of items.

function private.print(playername, msg)
	minetest.chat_send_player(playername, "[craft_lookup] "..tostring(msg))
end

-- Backend Functions
function mod.catalog_items(force)
	if force or mod.database == nil then
		local database = {}
		
		-- Record stuff
		local itemlist = {}
		local grouplist = {}
		
		-- Function for adding recipes other items are ingredients of.
		local function add_ingredient_record(input_itemname, recipe)
			local is_group, groupname = mod.is_group(input_itemname)
			if not is_group then
				local data2 = itemlist[input_itemname]
				-- Create data if it's not there
				if data2 == nil then
					data2 = {
						name = input_itemname,
						recipes_ingredient = {},
						not_complete = true,
					}
					itemlist[input_itemname] = data2
				end
				if tablelib.indexof(data2.recipes_ingredient, recipe) == nil then
					table.insert(data2.recipes_ingredient, recipe)
				end
			else
				local data2 = grouplist[groupname]
				-- Create data if it's not there
				if data2 == nil then
					data2 = {
						members = {},
						recipes_ingredient = {},
					}
					grouplist[groupname] = data2
				end
				-- Let members know they're being used in a recipe
				if tablelib.indexof(data2.recipes_ingredient, recipe) == nil then
					table.insert(data2.recipes_ingredient, recipe)
					for k,v in pairs(data2.members) do
						if tablelib.indexof(v.recipes_ingredient, recipe) == nil then
							table.insert(v.recipes_ingredient, recipe)
						end
					end
				end
			end
		end
		
		-- Construct recipe information from everything registered to the minetest engine.
		for k,v in pairs(minetest.registered_items) do -- k = item name, v = definition
			if (v.groups and (v.groups.not_in_creative_inventory or 0) < 1
				and v.description and v.description ~= "") then
				local data = {
					name = k,
					def = v,
					recipes_result = minetest.get_all_craft_recipes(k) or {},
					recipes_ingredient = ((itemlist[k] ~= nil and itemlist[k].not_complete) and itemlist[k].recipes_ingredient or {}),
					not_complete = nil,
				}
				
				-- Record self in group data.
				for k2,v2 in pairs(v.groups) do -- k2 = group name, v2 = group level
					if v2 ~= nil and v2 > 0 then
						if grouplist[k2] == nil then
							grouplist[k2] = {
								recipes_ingredient = {},
								members = {},
							}
						end
						grouplist[k2].members[k] = data -- Add self
						
						-- Make group membership imply recipe involvement.
						for i,recipe in ipairs(grouplist[k2].recipes_ingredient) do
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
				for k2,v2 in pairs(data.recipes_result) do -- v2 = recipe
					if v2.type == "normal" or true then
						for k3,v3 in pairs(v2.items) do
							add_ingredient_record(v3, v2)
						end
					end
				end
				
				-- Add self to catalog
				itemlist[k] = data
			end
		end
		
		-- Clean up unfinished item defs.
		for k,v in pairs(table.copy(itemlist)) do
			if v.not_complete then
				itemlist[k] = nil
			end
		end
		database.items = itemlist
		database.groups = grouplist
		mod.database = database
	end
end
function mod.is_group(itemstring)
	local r, r2 = false, nil
	if string.sub(assert(itemstring),1,6) == "group:" then
		r, r2 = true, string.sub(assert(itemstring),7)
	end
  return r, r2
end
function mod.is_visible_to(playercontext, itemname)
	local r = true
	if mod.progressive then
		r = r and mod.discovery.knows(playercontext.playername, itemname)
	end
	return r
end

-- List Processing
function mod.filterby_group(deflist, groupname)
	local r, all = {}, true
	for k,v in pairs(deflist) do
		if (v.def.groups[groupname] or 0) > 0 then
			r[v.name] = v
		else all = false
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
		else all = false
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
	if type(deflist) ~= "table" then error("deflist unexpected type. Expected table.") end
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
			for i,v in ipairs(playerinv:get_list("main")) do
				if v ~= nil and v:get_count() > 0 and list[v:get_name()] ~= nil then
					table.insert(r,list[v:get_name()])
				end
			end
		else
			error("Can't filter by inventory (5) without knowing who's inventory to use.")
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
	for k,v in pairs(deflist) do
		table.insert(r,v)
	end
	return r
end
function mod.to_named_deflist(deflist)
	local r = {}
	for k,v in pairs(deflist) do
		r[v.name] = v
	end
	return r
end

-- Events
minetest.register_on_joinplayer(function(player)
	local playername = player:get_player_name()
	if mod.contexts[playername] == nil then
		local context = {
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
		mod.contexts[playername] = context
		
		if mod.database == nil then
			mod.catalog_items()
		end
	end
end)
minetest.register_on_leaveplayer(function(player)
	local playername = player:get_player_name()
	if mod.contexts[playername] ~= nil then
		local context = mod.contexts[playername]
		mod.contexts[playername] = nil
	end
end)

-- Discovery tracking system
if mod.progressive then
	local discovery = {}
	mod.discovery = discovery
	
	discovery.version = 0
	discovery.datafile = minetest.get_worldpath().."/discovery.db"
	discovery.database = nil -- format is {version = version, players = {<player> = {items = {}}}}
	
	function discovery.get_database()
		local r
		if discovery.database ~= nil then
			r = discovery.database
		else
			local filehandle = io.open(discovery.datafile,"r")
			if filehandle ~= nil then
				local filecontents = filehandle:read()
				filehandle:close()
				r = minetest.deserialize(filecontents)
				print("[discovery] Loaded database.")
			else
				r = {
					version = discovery.version,
					players = {},
				}
			end
			discovery.database = r
		end
		return r
	end
	function discovery.save_database()
		if discovery.database ~= nil then
			local filehandle = io.open(discovery.datafile,"w")
			if filehandle ~= nil then
				filehandle:write(minetest.serialize(discovery.database))
				filehandle:close()
				print("[discovery] Saved database.")
			else
				print("[discovery] Failed to save database.")
			end
		end
	end
	
	function discovery.knows(playername, itemname)
		local database = discovery.get_database()
		return (database.players[playername].items[itemname] ~= nil or not mod.progressive)
	end
	function discovery.discover(playername, itemname)
		if discovery.discoverable(itemname) then
			local database = discovery.get_database()
			local discovereditems = database.players[playername].items
			local oldvalue = discovereditems[itemname]
			if oldvalue ~= true then
				discovereditems[itemname] = true
				private.print(playername, "You discovered "..(minetest.registered_items[itemname].description or itemname).."!")
			end
		end
	end
	function discovery.forget(playername, itemname)
		local database = discovery.get_database()
		database.players[playername].items[itemname] = nil
	end
	function discovery.loop_start()
		if not discovery.loop_started then
			minetest.after(1, discovery.loop)
			discovery.loop_started = true
		end
	end
	function discovery.loop(...)
		local database = discovery.get_database()
		for playername, playerdata in pairs(database.players) do
			local player = minetest.get_player_by_name(playername)
			local playerinv = player:get_inventory()
			local list = playerinv:get_list("main")
			for i,v in ipairs(list) do
				if v ~= nil and v:get_count() > 0 then
					discovery.discover(playername, v:get_name())
				end
			end
		end
		
		discovery.save_database()
		
		minetest.after(mod.loop_interval, discovery.loop)
	end
	
	function discovery.discoverable(itemname)
		return mod.database.items[itemname] ~= nil
	end
	
	minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
		if puncher.get_player_name ~= nil and node ~= nil and node.name ~= nil then
			local playername = puncher:get_player_name()
			discovery.discover(playername, node.name)
		end
	end)
	minetest.register_on_joinplayer(function(player)
		local playername = player:get_player_name()
		local database = discovery.get_database()
		if database.players[playername] == nil then
			local playerdata = {items = {}}
			database.players[playername] = playerdata
			discovery.save_database()
		end
		
		discovery.loop_start()
	end)
	minetest.register_on_leaveplayer(function(player)
		discovery.save_database()
	end)
end


