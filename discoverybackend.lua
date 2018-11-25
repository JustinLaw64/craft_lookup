-- Craft Lookup
-- Copyright 2017 Justin Law

local mod, private = ...
local tablelib = private.tablelib

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
			local filehandle = io.open(discovery.datafile, "r")
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
		return not mod.progressive or database.players[playername].items[itemname] ~= nil
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
			for i, v in ipairs(list) do
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
