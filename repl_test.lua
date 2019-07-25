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





-- get a prefix of a big string
print(json_encode(eval({script=[[
s = "For twelve years, you have been asking: Who is John Galt? This is John Galt speaking. I am the man who loves his life. I am the man who does not sacrifice his love or his values. I am the man who has deprived you of victims and thus has destroyed your world, and if you wish to know why you are perishing—you who dread knowledge—I am the man who will now tell you.” The chief engineer was the only one able to move; he ran to a television set and struggled frantically with its dials. But the screen remained empty; the speaker had not chosen to be seen. Only his voice filled the airways of the country—of the world, thought the chief engineer—sounding as if he were speaking here, in this room, not to a group, but to one man; it was not the tone of addressing a meeting, but the tone of addressing a mind."
]]})))
local ret = explore_expr({script=[[
s
]]})
print(json_encode(ret))
local handle = ret.value.top_object
-- get the rest of mr galt's speech's first paragraph
for i=1,5 do
	print(json_encode(explore_handle({handle=handle})))
end
