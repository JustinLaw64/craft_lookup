-- Craft Lookup
-- Copyright 2017 Justin Law

--[[

What's recorded in the craft database:

* Item names
* Minetest Definitions
* Recipes as Ingredient
* Recipes as Output

Filter layers:

1. Every item that can be seen in creative (Server-Wide; Dictionary)
2. Everything or just what the player knows (Progressive; Dictionary)
3. Search Filter (Cacheable; Array)

Search Types:
1 = All
2 = Nodes
3 = Tools
4 = Craft Items
5 = Inventory

]]

local mod = {}
local private = {}

mod.progressive = minetest.setting_getbool("craft_lookup_progressive") == true
mod.debug_mode = minetest.setting_getbool("craft_lookup_debug_mode") == true
mod.loop_interval = 2
private.modname = "craft_lookup"
private.modpath = minetest.get_modpath("craft_lookup")
private.tablelib = loadfile(private.modpath.."/tablelib.lua")()

loadfile(private.modpath.."/backend.lua")(mod, private)
if mod.progressive then
	loadfile(private.modpath.."/discoverybackend.lua")(mod, private)
end
loadfile(private.modpath.."/gui.lua")(mod, private)

_G.craft_lookup = mod
