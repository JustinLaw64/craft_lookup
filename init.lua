-- Craft Lookup
-- Copyright 2017 Justin Law

-- What's saved into the database:
-- 
-- * Item names
-- * Minetest Definitions
-- * Recipes as Ingredient
-- * Recipes as Output
-- 
-- Filter layers:
--
-- 1. Every item that can be seen in creative (Server-Wide; Dictionary)
-- 2. Everything or just what the player knows (Progressive; Dictionary)
-- 3. Search Filter (Cacheable; Array)

local mod = {}
local private = {
	modname = "craft_lookup",
	modpath = minetest.get_modpath("craft_lookup")
}
private.tablelib = assert(loadfile(private.modpath.."/tablelib.lua")())
_G.craft_lookup = mod

-- Settings
mod.progressive = (minetest.setting_getbool("craft_lookup_progressive") == true)
mod.debug_mode = (minetest.setting_getbool("craft_lookup_debug_mode") == true)
mod.loop_interval = 2

assert(loadfile(private.modpath.."/backend.lua"), "Failed to load lua script!")(mod, private)
assert(loadfile(private.modpath.."/gui.lua"), "Failed to load lua script!")(mod, private)

