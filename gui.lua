-- Craft Lookup
-- Copyright 2017 Justin Law

local mod, private = ...
local tablelib = private.tablelib

-- GUI
local gui_search_list_dimenions = {x = 8, y = 4}
local gui_search_list_count = gui_search_list_dimenions.x * gui_search_list_dimenions.y
local gui_search_typedescriptions = {"All","Nodes","Tools","Craft Items","Inventory",}
local gui_search_typedescriptions_reverse = tablelib.inverse(gui_search_typedescriptions)

function mod.set_search_filter(searchterm, searchtype, playercontext, bust_cache)
	local searchterm_old = playercontext.gui_list_search_term
	local searchtype_old = playercontext.gui_list_search_type
	local r
	if searchterm ~= searchterm_old or searchtype ~= searchtype_old or bust_cache then
		playercontext.gui_list_search_term = searchterm
		playercontext.gui_list_search_type = searchtype
		r = mod.get_search_filtered(playercontext, true)
	else
		r = gui_list_search_cache
	end
	return r
end
function mod.get_search_filtered(playercontext, bust_cache)
	local r
	if bust_cache or playercontext.gui_list_search_cache == nil then
		local searchterm = playercontext.gui_list_search_term
		local searchtype = playercontext.gui_list_search_type
		r = mod.filterby_player(mod.database.items, playercontext)
		r = mod.filterby_searchtype(r, searchtype, playercontext)
		r = mod.filterby_searchterm(r, searchterm)
		r = mod.to_indexed_deflist(r)
		table.sort(r, function(a,b) return a.name < b.name end)
		mod.bust_search_filter_cache(playercontext)
		playercontext.gui_list_search_cache = r
		playercontext.gui_list_page = mod.gui_constrain_page(playercontext.gui_list_page, playercontext)
	else
		r = playercontext.gui_list_search_cache
	end
	return r
end
function mod.bust_search_filter_cache(playercontext)
	playercontext.gui_list_search_cache = nil
end
function mod.get_page_count(playercontext)
	local deflist = mod.get_search_filtered(playercontext)
	local itemcount = deflist ~= nil and #deflist or 0
	local r = math.max(1, math.floor((itemcount - 1) / gui_search_list_count) + 1)
	return r
end
function mod.gui_constrain_page(index, playercontext)
	return math.max(1, math.min(index, mod.get_page_count(playercontext)))
end

function mod.get_item_tile(pos_x, pos_y, stack_param, context)
	local r = ""
	local is_empty = false
	if stack_param ~= nil and stack_param ~= "" then
		local stack = (type(stack_param) == "string") and ItemStack(stack_param) or stack_param
		local stackname = stack:get_name()
		if stack:get_count() > 0 then
			local is_group, groupname = mod.is_group(stackname)
			local imagename, special_text, can_be_seen
			if not is_group then
				can_be_seen = (not mod.progressive or mod.is_visible_to(context, stackname))
				special_text = ""
				
				if can_be_seen then
					-- Scan for recipes which lead up to unknown items.
					local itemdef = mod.database.items[stackname]
					local unknown_recipe_count = 0
					if itemdef ~= nil then
						for i,recipe in ipairs(itemdef.recipes_ingredient) do
							if recipe.output ~= nil and recipe.output ~= "" then
								local outputname = ItemStack(recipe.output):get_name()
								if not (mod.is_group(outputname) or mod.is_visible_to(context, outputname)) then
									unknown_recipe_count = unknown_recipe_count + 1
								end
							end
						end
					end
					if unknown_recipe_count > 0 then
						special_text = minetest.colorize("#FFFF00", "\\[".."*"..tostring(unknown_recipe_count).."\\]")
					end
					
					-- Set tile image
					imagename = stackname
				end
			else
				local groupmembers = mod.database.groups[groupname].members
				can_be_seen = false
				for k,v in pairs(groupmembers) do
					if mod.is_visible_to(context, k) then
						imagename = k
						can_be_seen = true
						break
					end
				end
				special_text = "G"
			end
			if can_be_seen then
				-- TODO: Determine whether or not this item has recipes from which a new item can be discovered.
				r = r..string.format("item_image_button[%f,%f;1,1;\"%s\";%s;%s]", pos_x, pos_y, imagename, mod.get_tile_name(stack:get_name()), special_text)
			else
				r = r..string.format("image_button[%f,%f;1,1;craft_lookup_unknown.png;itemtile_unknown;%s]", pos_x, pos_y, special_text)
			end
			if stack:get_count() > 1 then
				r = r..string.format("label[%f,%f;%i]", pos_x + 0.6, pos_y + 0.69, stack:get_count())
			end
		else is_empty = true
		end
	else is_empty = true
	end
	if is_empty then
		r = string.format("item_image_button[%f,%f;1,1;;itemtile_blank;]", pos_x, pos_y)
	end
	return r
end
function mod.get_tile_name(itemname)
	assert(type(itemname) == "string", "Expected string. Got "..type(itemname))
	return "itemtile_"..string.gsub(itemname,":","_")
end
function mod.get_name_from_tile(tilename)
	if not (tilename == "itemtile_blank" or tilename == "itemtile_unknown") then
		for k,v in pairs(mod.database.items) do
			local tilename2 = mod.get_tile_name(k)
			if tilename == tilename2 then
				return k
			end
		end
		for k,v in pairs(mod.database.groups) do
			local itemname = "group:"..k
			local tilename2 = mod.get_tile_name(itemname)
			if tilename == tilename2 then
				return itemname
			end
		end
	end
	return nil
end
function mod.gui_make_recipe_diagram(pos_x, pos_y, recipe, playercontext)
	local r = {}
	if recipe ~= nil then
		--private.print(playercontext.playername, dump(recipe))
		if (recipe.type == "normal" or recipe.type == "cooking" or recipe.type == "fuel") then
			local xi, yi = 1, 1
			local itemubound = tablelib.ubound(recipe.items)
			local recipewidth = math.min(
				(recipe.width ~= nil and recipe.width ~= 0) and
				recipe.width or math.ceil(math.sqrt(itemubound)), -- If width is not defined, make the grid as square as possible.
				itemubound or 1
			)
			local recipeheight = math.ceil(itemubound / math.max(recipewidth,1)) -- math.max prevents infinite loop.
			local grid_left = 1.5 - (recipewidth / 2)
			local grid_top = 1.5 - (recipeheight / 2)
			table.insert(r, mod.gui_item_grid(pos_x + grid_left, pos_y + grid_top, recipewidth, recipeheight, recipe.items, 0, playercontext))
			table.insert(r, string.format("label[%f,%f;%s]", pos_x + 3, pos_y + 1.8, mod.gui_recipe_type_label(recipe)))
			table.insert(r, string.format("image[%f,%f;1,1;(gui_furnace_arrow_bg.png^[transformR270)]", pos_x + 3, pos_y + 1))
			if recipe.type == "normal" or recipe.type == "cooking" then
				table.insert(r, mod.get_item_tile(pos_x + 4, pos_y + 1, recipe.output, playercontext))
			elseif recipe.type == "fuel" then
				table.insert(r, string.format("image[%f,%f;1,1;default_furnace_fire_fg.png]", pos_x + 4, pos_y + 1))
				table.insert(r, string.format("label[%f,%f;%s seconds]", pos_x + 4, pos_y + 2, tostring(recipe.burntime)))
			end
		else
			table.insert(r, string.format("label[%f,%f;%s recipe methods are currently not supported.]", pos_x + 0.1, pos_y + 1.2, recipe.method))
		end
	else
		table.insert(r, string.format("label[%f,%f;No recipe found.]", pos_x + 0.1, pos_y + 1.2))
	end
	return table.concat(r)
end
function mod.gui_item_grid(pos_x, pos_y, size_columns, size_rows, defarray, indexoffset, playercontext)
		-- Compatible with both inventory lists and def arrays.
		assert(type(pos_x) == "number","pos_x expected number. Got "..type(pos_x))
		assert(type(pos_y) == "number","pos_y expected number. Got "..type(pos_y))
		assert(type(size_columns) == "number","size_columns expected number. Got "..type(size_columns))
		assert(type(size_rows) == "number","size_rows expected number. Got "..type(size_rows))
		assert(type(defarray) == "table","defarray expected an indexed table of craft_lookup definitions.")
		assert(type(indexoffset) == "number","indexoffset expected number. Got "..type(indexoffset))
		assert(type(playercontext) == "table","playercontext expected a craft_lookup player context.")
		
		local r = {}
		
		local i = indexoffset
		for i1 = 0, size_rows - 1 do -- y derived
			for i2 = 0, size_columns - 1 do -- x derived
				i = i + 1
				local x, y = i2 + pos_x, i1 + pos_y
				local def = defarray[i]
				table.insert(
					r,
					mod.get_item_tile(x, y, (type(def) == "table" and def.name or def), 
					playercontext
				))
			end
		end
		
		return table.concat(r)
end
function mod.gui_recipe_type_label(recipe)
	local r1, r2 -- r1 = Recipe type text, r2 = Recipe type image
	if recipe.type == "normal" and recipe.width ~= nil then
		r1 = recipe.width > 0 and "Crafting" or "Mixing"
	elseif recipe.type == "fuel" then
		r1 = "Fuel"
	else
		r1 = recipe.type
	end
	return r1, r2
end

-- sfinv page
sfinv.register_page("craft_lookup:page", { -- The "context"s mentioned here are not the type this mod uses.
	title = "Craft Lookup",
	get = function(self, player, context)
		local playercontext = mod.contexts[player:get_player_name()]
		local formspec_table = {}
		
		-- Recipe Viewer
		local recipe_count = 0
		local recipe_itemname = playercontext.gui_recipe_item
		if recipe_itemname ~= nil then
			local entry = mod.database.items[recipe_itemname]
			local recipe_lookup_location = playercontext.gui_recipe_mode == 1 and entry.recipes_result or entry.recipes_ingredient
			recipe_count = tablelib.count(recipe_lookup_location)
			playercontext.gui_recipe_page = math.max(1, math.min(playercontext.gui_recipe_page, recipe_count))
			--private.print(playercontext.playername, dump(mod.database.items[recipe_itemname]))
			table.insert(formspec_table, mod.get_item_tile(0, 0, recipe_itemname, playercontext))
			table.insert(formspec_table, 
				string.format(
					"label[1,0;%s as %s]",
					(mod.database.items[recipe_itemname].def.description or recipe_itemname)..
						(mod.debug_mode and string.format(" (%s)", recipe_itemname) or ""),
					(playercontext.gui_recipe_mode == 1 and "result" or "ingredient")
				)
			)
			
			local recipe = recipe_lookup_location[playercontext.gui_recipe_page]
			--private.print(playercontext.playername, dump(recipe))
			table.insert(formspec_table, mod.gui_make_recipe_diagram(1.5, 0.5, recipe, playercontext))
		else
			playercontext.gui_recipe_page = 1
		end
		table.insert(formspec_table, "button[5.5,2.9;0.8,1;recipe_prev;<]")
		table.insert(formspec_table, string.format("label[6.3,3.1;%i / %i]",playercontext.gui_recipe_page,recipe_count))
		table.insert(formspec_table, "button[7.2,2.9;0.8,1;recipe_next;>]")
		
		-- Catalog
		local deflist = mod.get_search_filtered(playercontext)
		local pagenumber = playercontext.gui_list_page
		local pageoffset = (pagenumber - 1) * gui_search_list_count
		table.insert(
			formspec_table,
			mod.gui_item_grid(
				0, 3.9,
				gui_search_list_dimenions.x,
				gui_search_list_dimenions.y,
				deflist, pageoffset,
				playercontext
			)
		)
		-- Catalog Navigation
		table.insert(formspec_table, string.format("dropdown[0,8.1;2,1;search_type_dropdown;%s;%i]", table.concat(gui_search_typedescriptions, ","), playercontext.gui_list_search_type))
		table.insert(formspec_table, "field[2.2,8.3;2.7,1;search_text;Search:;"..playercontext.gui_list_search_term.."]")
		table.insert(formspec_table, "image_button[4.5,7.9;1,1;craft_lookup_search.png;search_button;]")
		table.insert(formspec_table, "tooltip[search_button;Search / Refresh]")
		table.insert(formspec_table, "button[5.5,7.9;0.8,1;search_page_prev;<]")
		table.insert(formspec_table, string.format("label[6.3,8.1;%i / %i]", playercontext.gui_list_page, mod.get_page_count(playercontext)))
		table.insert(formspec_table, "button[7.2,7.9;0.8,1;search_page_next;>]")
		table.insert(formspec_table, "field_close_on_enter[search_text;false]")
		
		return sfinv.make_formspec(player, context, table.concat(formspec_table))
	end,
	on_enter = function(self, player, context)
		local playercontext = mod.contexts[player:get_player_name()]
		mod.bust_search_filter_cache(playercontext)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		local RefreshWarranted = true
		local playercontext = mod.contexts[player:get_player_name()]
		local function error_protected_function(...)
			--private.print(playercontext.playername, dump(fields))
			if fields.recipe_prev ~= nil then
				playercontext.gui_recipe_page = playercontext.gui_recipe_page - 1
			elseif fields.recipe_next ~= nil then
				playercontext.gui_recipe_page = playercontext.gui_recipe_page + 1
			elseif fields.search_page_prev ~= nil then
				playercontext.gui_list_page = mod.gui_constrain_page(playercontext.gui_list_page - 1, playercontext)
			elseif fields.search_page_next ~= nil then
				playercontext.gui_list_page = mod.gui_constrain_page(playercontext.gui_list_page + 1, playercontext)
			elseif fields.search_button ~= nil or fields.key_enter_field == "search_text" then
				if fields.search_type_dropdown ~= nil and fields.search_text ~= nil then
					local searchtype = gui_search_typedescriptions_reverse[fields.search_type_dropdown]
					if searchtype ~= nil then
						mod.set_search_filter(fields.search_text or "", searchtype, playercontext, true)
					end
				end
			else
				RefreshWarranted = false
				
				for k,v in pairs(fields) do
					if string.sub(k,1,9) == "itemtile_" and k ~= "itemtile_blank" and k ~= "itemtile_unknown" then
						local itemname = mod.get_name_from_tile(k)
						if itemname ~= nil then
							local isgroup, groupname = mod.is_group(itemname)
							if mod.database.items[itemname] ~= nil or isgroup then
								if not isgroup then
									if itemname ~= playercontext.gui_recipe_item then
										playercontext.gui_recipe_item = itemname
										playercontext.gui_recipe_page = 1
									else
										playercontext.gui_recipe_mode = ((playercontext.gui_recipe_mode == 1) and 2 or 1)
									end
								else
									mod.set_search_filter(itemname, 1, playercontext, true)
								end
								RefreshWarranted = true
								--private.print(playercontext.playername, itemname)
								break
							else
								private.print(playercontext.playername, "Failed to identify tile.")
							end
						else
							private.print(playercontext.playername, "Could not figure out tile name.")
						end
					end
				end
			end
			
			if RefreshWarranted then
				sfinv.set_player_inventory_formspec(player)
			end
		end
		if mod.debug_mode then -- Calls the function body defined above.
			error_protected_function()
		else
			local r, errormsg = pcall(error_protected_function)
			if errormsg ~= nil then
				private.print(playercontext.playername, errormsg)
			end
		end
	end,
})
