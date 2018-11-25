-- Justin's Table Manipulation Library Extension for Lua
-- Copyright 2017 Justin Law

local lib = {}

function lib.count(table,item)
	local r = 0
	for k,v in pairs(table) do
		r = r + 1
	end
	return r
end
function lib.indexof(table,item)
	local r = nil
	for k,v in pairs(table) do
		if v == item then
			r = k
			break
		end
	end
	return r
end
function lib.inverse(table) -- Swap every pair so that keys may be looked up by values.
	local r = {}
	for k,v in pairs(table) do
		r[v] = k
	end
	return r
end
function lib.ubound(table)
	local r = nil
	for i,v in pairs(table) do
		if type(i) == "number" and (r == nil or i > r) then
			r = i
		end
	end
	return r
end
function lib.lbound(table)
	local r = nil
	for i,v in pairs(table) do
		if type(i) == "number" and (r == nil or i < r) then
			r = i
		end
	end
	return r
end

return lib
