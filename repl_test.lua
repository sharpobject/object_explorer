local repl = require"repl"
local eval = repl.eval
local explore_expr = repl.explore_expr
local explore_handle = repl.explore_handle
local json = require"dkjson"
local json_decode = json.decode
local json_encode = json.encode


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
