assert((1 ~ 1) == 0, "requires Lua 5.3")
local ops = {"+" , "-" , "*" , "/" , "//" , "^" , "%" , 
		 "&" , "~" , "|" , ">>" , "<<" , ".." , 
		 "<" , "<=" , ">" , ">=" , "==" , "~=" , 
		 "and" , "or"}
local unops = {"-" , "not" , "#" , "~"}

--[[

"return a %s b %s c"
"return (a %s b) %s c"
"return a %s (b %s c)"

"return %s a %s b"
"return (%s a) %s b"
"return %s (a %s b)"

"return a %s b"
"return b %s a"
]]
local meta = {__tostring=function(t) return t.name end}
local known = {}
local log
local function resetLog()
  log = ""
end
local function newTable(name)
  if not known[name] then
    known[name] = setmetatable({name = name}, meta)
  end
  return known[name]
end
local function op(a, b)
  --log = log .. "+"
  return newTable("(" .. tostring(a) .. tostring(b) .. ")")
end
for _, k in ipairs{
  "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__idiv", "__band", "__bor", "__bxor", "__bnot", "__shl", "__shr", "__concat", "__len", "__eq", "__lt", "__le"} do
  meta[k] = op
end
local VALUES = {
  newTable,
  function()
    return nil
  end,
}
local BINARY = {
  "return a %s b %s c",
  "return (a %s b) %s c",
  "return a %s (b %s c)",
}
local UNARY = {
  "return %s b %s c",
  "return (%s b) %s c",
  "return %s (b %s c)",
}

local ENV = {}
local ENV_ = setmetatable({}, {__index = function(_, k) log = log .. k return ENV[k] end})
local function prepareCode(pattern, ...)
  local code = pattern:format(...)
  return assert(load(code, code, "t", ENV_))
end
local function runTest(f)
  resetLog()
  local ok, code = pcall(f)
  return ok, code, log
end

local function analyze(t, opA, opB)
  local fRef = prepareCode(t[1], opA, opB)
  local fA = prepareCode(t[2], opA, opB)
  local fB = prepareCode(t[3], opA, opB)
  local result = nil
  local function setResult(value)
    if result == nil or result == "=" then
      result = value
    elseif value ~= "=" then
      assert(result == value, "?")
    end
  end
  for _, a in ipairs(VALUES) do
    ENV.a = a"a"
    for _, b in ipairs(VALUES) do
      ENV.b = b"b"
      for _, c in ipairs(VALUES) do
        ENV.c = c"c"
        local ok, code, log = runTest(fRef)
        local okA, codeA, logA = runTest(fA)
        local okB, codeB, logB = runTest(fB)
        --assert(ok, code)
        --print(log, code, logA, codeA, logB, codeB)
        if okA == okB and okB == ok and logA == logB and logB == log then
          setResult "="
        elseif okA == ok and log == logA then
          setResult ">"
        elseif okB == ok and log == logB then
          setResult "<"
        end
      end
    end
  end
  return assert(result, opA .. "  " .. opB)
end


local function check(a, b)
  local normal = analyze(BINARY, a, b)
  local reversed = analyze(BINARY, b, a)
  if (normal == "<" and reversed == ">") or (normal == ">" and reversed == "<") then
    return normal
  else
    return "="
  end
end


table.sort(ops, function(a, b)
  local result = check(a, b)
  return result == ">"
end)

local groups = {}
do
  local group
  for _, v in ipairs(ops) do
    if (not group) or (check(v, group[1]) ~= "=") then
      group = {}
      table.insert(groups, group)
    end
    table.insert(group, v)
  end
end
print("Results")
for k, group in ipairs(groups) do
  --determine associativity
  local v = analyze(BINARY, group[1], group[1])
  local associativity = (v == "<") and "right" or " left"
  --unary
  local finishedUnops = {}
  for i, v in pairs(unops) do
    if analyze(UNARY, v, group[1]) ~= "<" then
      unops[i] = nil
      table.insert(finishedUnops, v)
    end
  end
  if #finishedUnops > 0 then
    table.sort(finishedUnops)
    print("            unary: " .. table.concat(finishedUnops, " "))
  end
  --draw group
  table.sort(group)
  print(associativity .. " associative: " .. table.concat(group, " "))
end