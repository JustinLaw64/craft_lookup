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

Notes on mod structure:

The mod uses the name "mod" as a local variable throughout most of its lua files. This simplifies
writing the mod, as the mod table can be referred to by a short name, saving me from writing
"Craft_Lookup" everywhere. Don't worry! This does not pollute the global table.

"private" is also another variable used internally. However, it is intentionally marked private
to discourage mod developers from depending on its contents when other means are more appropriate.

]]

-- Set up the mod table.
local mod, private = {}, {}
mod.private = private

-- Nothing other than this mod's table is added to the global namespace.
_G.craft_lookup = mod

-- Set up the most important values used in the mod.
private.modname = "craft_lookup"
private.modpath = minetest.get_modpath("craft_lookup")
private.tablelib = loadfile(private.modpath .. "/tablelib.lua")()
mod.progressive_mode = minetest.setting_getbool("craft_lookup_progressive") == true
mod.debug_mode = minetest.setting_getbool("craft_lookup_debug_mode") == true
mod.discovery_datafilepath = minetest.get_worldpath() .. "/craft_lookup_discovery"
mod.discovery_version = 0
mod.discovery_check_interval = 2
mod.discovery_save_interval = 120
mod.gui_search_list_dimensions = {x = 8, y = 4}
mod.gui_search_list_count = mod.gui_search_list_dimensions.x * mod.gui_search_list_dimensions.y
mod.gui_search_typedescriptions = {"All", "Nodes", "Tools", "Craft Items", "Inventory"}
mod.gui_search_typedescriptions_reverse = private.tablelib.inverse(mod.gui_search_typedescriptions)

-- Start the other files.
loadfile(private.modpath .. "/backend.lua")(mod, private)
if mod.progressive_mode then
	loadfile(private.modpath .. "/discoverybackend.lua")(mod, private)
end
loadfile(private.modpath .. "/gui.lua")(mod, private)
