require"util"
require"class"
require"queue"
local json = require"dkjson"
local json_decode = json.decode
local json_encode = json.encode
local loadstring = loadstring
local type = type
local setmetatable = setmetatable
local select = select
local table_remove = table.remove
local traceback = debug.traceback
local str_sub = string.sub
local print = print
local max = math.max
local q = Queue()
q.push = q.push
q.pop = q.pop
q.len = q.len
q.clear = q.clear
--local socket = require"socket"
local BUDGET_PER_QUERY = 200

local hijacknil = setmetatable({}, {__tostring=function() return "nil" end})
local function capture(...)
	local tbl = {}
	for i=1,select("#", ...) do
		local item = select(i, ...)
		if type(item) == nil then
			tbl[i] = hijacknil
		else
			tbl[i] = item
		end
	end

	return tbl
end

local function xp_handler(msg)
	local stack = traceback()
	return tostring(msg).."\n"..stack
end

-- commands:
-- E: evaluate this code
-- X: explore by expression
-- H: explore by handle
local function eval(t)
	local script = t.script
	local func,err = loadstring(script, "=weblua")
	if type(func) ~= "function" then
		func = loadstring("return "..script, "=weblua")
		if type(func) ~= "function" then
			return {error = err}
		end
	end
	local stuff = capture(xpcall(func, xp_handler))
	if stuff[1] then
		table_remove(stuff, 1)
		return {value = stuff}
	else
		return {error = stuff[2]}
	end
end

-- tables with weak keys
local obj_to_id = setmetatable({}, {__mode="k"})
local obj_to_extras = setmetatable({}, {__mode="k"})
-- table with weak values
local id_to_obj = setmetatable({}, {__mode="v"})
local updated = {}
local nxt_id = 1

local function register(obj)
	--print("registering "..tostring(obj).." "..tostring(nxt_id))
	obj_to_id[obj] = nxt_id
	id_to_obj[nxt_id] = obj
	updated[nxt_id] = true
	nxt_id = nxt_id + 1
end

local function get_repr(id)
	--print("id "..id)
	--if id ~= 10 then print("obj "..json.encode(id_to_obj[id])) end
	local extras = obj_to_extras[id_to_obj[id]]
	return extras.repr
end

local function get_meta(id)
	local extras = obj_to_extras[id_to_obj[id]]
	return {
		type=extras.type,
		len=extras.len,
		cursor=extras.cursor,
	}
end

local credit = 0

local function do_explore_obj(obj, is_multiple_return)
	updated = {}
	q:clear()
	q:push({
		k=obj,
		is_multiple_return=is_multiple_return,
	})
	while credit >= 20 and q:len() > 0 do
		local stuff = q:pop()
		local k = stuff.k
		local v = stuff.v
		local parent = stuff.parent
		is_multiple_return = stuff.is_multiple_return
		for _,obj in ipairs{k,v} do
			if obj_to_id[obj] and obj_to_extras[obj].repr then
				credit = credit - 20
				goto cntinue
			end
			if not obj_to_id[obj] then
				credit = max(credit, 20)
				register(obj)
			end
			if type(obj) == "table" and obj ~= hijacknil then
				local prev_keys = setmetatable({}, {__mode="k"})
				local extras = obj_to_extras[obj]
				if extras then
					prev_keys = extras.exported_keys
				end
				credit = credit - 20
				local len = 0
				for k,v in pairs(obj) do
					len = len + 1
				end
				local typ = "table"
				if is_multiple_return then
					typ = "multiple return"
				end
				obj_to_extras[obj] = {
					repr = {},
					rlen = 0,
					len = len,
					type = typ,
					exported_keys = prev_keys,
					cursor = 1,
				}
				for k,v in pairs(obj) do
					if not prev_keys[k] then
						q:push({
							k=k,
							v=v,
							parent=obj,
						})
					end
				end
			elseif type(obj) == "string" then
				if credit >= #obj then
					credit = credit - #obj
					obj_to_extras[obj] = {
						repr = obj,
						len = #obj,
						type = "string",
						cursor = #obj+1,
					}
				else
					obj_to_extras[obj] = {
						repr = obj:sub(1, credit),
						len = #obj,
						type = "string",
						cursor = credit+1,
					}
					credit = 0
				end
			else
				credit = credit - 20
				local typ = type(obj)
				if obj == hijacknil then
					typ = "nil"
				end
				local repr = obj
				if type(obj) ~= "number" and type(obj) ~= "boolean" then
					repr = tostring(obj)
				end
				obj_to_extras[obj] = {
					repr = repr,
					type = typ,
				}
			end
			::cntinue::
		end
		if parent then
			local extras = obj_to_extras[parent]
			local rlen = extras.rlen
			local repr = extras.repr
			extras.exported_keys[k] = true
			repr[rlen+1] = {obj_to_id[k], obj_to_id[v]}
			extras.rlen = rlen + 1
			updated[obj_to_id[parent]] = true
		end
	end
end

local function explore_obj(obj, is_multiple_return)
	credit = BUDGET_PER_QUERY
	do_explore_obj(obj, multiple_return)
	local value = {}
	local new_objects = {}
	local meta = {}
	for k,_ in pairs(updated) do
		new_objects[k] = get_repr(k)
		meta[k] = get_meta(k)
	end
	value.new_objects = new_objects
	value.meta = meta
	value.top_object = obj_to_id[obj]
	return {value = value}
end

local function explore_expr(t)
	local script = "return "..t.script
	local func,err = loadstring(script, "=weblua")
	if type(func) ~= "function" then
		return {error = err}
	end
	local stuff = capture(xpcall(func, xp_handler))
	if stuff[1] then
		table_remove(stuff, 1)
	else
		return {error = stuff[2]}
	end
	local start_idx = nxt_idx
	local ret
	local multiple_return = true
	if #stuff <= 1 then
		stuff = stuff[1]
		multiple_return = false
	end
	return explore_obj(stuff, multiple_return)
end

local function explore_handle(t)
	local id = t.handle
	local obj = id_to_obj[id]
	if not obj then
		return {error = "No object with handle "..id}
	end
	local extras = obj_to_extras[obj]
	extras.repr = nil
	return explore_obj(obj)
end

local handlers = {
	eval=eval,
	explore_expr=explore_expr,
	explore_handle=explore_handle,
}

local function handle(line)
	local blob, _, err = json_decode(line)
	if not blob then
		return {error = "Could not decode json: "..err}
	end
	local method = blob.method
	local args = blob.args
	if not method or not args then
		return {error = "method and args are required my dude"}
	end
	local handler = handlers[method]
	if not handler then
		return {error = "unknown method "..method}
	end
	return handler(args)
end

print(json_encode(eval({script=[[
a = 1+2+3*4
print("hello")
return a

	]]})))

print(json_encode(eval({script=[[
a = a * 2
return a

	]]})))

-- test with self-referential object
print(json_encode(eval({script=[[
t = {}
t[1] = t

	]]})))
print(json_encode(explore_expr({script=[[
t

	]]})))
-- add a key to the object
print(json_encode(eval({script=[[
t[14] = 100
]]
})))
-- get the new stuff only
print(json_encode(explore_handle({handle=1})))

print(json_encode(eval({script=[[
other_t = {2,4,6,8,10,12,14,16,18,20,22,24,26,28,30}
]]})))
-- get just the first few entries of a big object
print(json_encode(explore_expr({script=[[
other_t
]]})))
-- get more of the entries
print(json_encode(explore_handle({handle=5})))
print(json_encode(explore_handle({handle=5})))
-- this returns an empty success result
-- because we already got all the stuff
print(json_encode(explore_handle({handle=5})))

