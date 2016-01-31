-----------------------------------------------------
--name       : home/bin/ifr.lua
--description: a command line based ifr calculation trainer
--author     : mpmxyz
--github page: https://github.com/mpmxyz/ocprograms
--forum page : http://oc.cil.li/index.php?/topic/
-----------------------------------------------------


local quick = {}
quick.sinTable = {
  [0] = 0,
  [10] = 1/6, --1:60 rule
  [20] = 2/6, --1:60 rule
  [30] = 3/6, --1:60 rule
  [40] = 4/6, --1:60 rule
  [45] = 0.7,
  [50] = 3/4,
  [60] = 0.85,
  [70] = 0.95,
  [80] = 1,
  [90] = 1,
}
for i = 100, 180, 5 do
  if quick.sinTable[180 - i] then
    quick.sinTable[i] = quick.sinTable[180 - i]
  end
end
for i = 190, 360, 5 do
  if quick.sinTable[i - 180] then
    quick.sinTable[i] = -quick.sinTable[i - 180]
  end
end
quick.cosTable = {}
for i = 0, 360, 10 do
  if quick.sinTable[(90 + i) % 360] then
    quick.cosTable[i] = quick.sinTable[(90 + i) % 360]
  end
end

function quick.getApproximation(t, angle)
  local bestDiff = math.huge
  local bestValue
  for a, v in pairs(t) do
    local diff = math.abs((a - angle + 180) % 360 - 180)
    if diff < bestDiff then
      bestDiff = diff
      bestValue = v
    end
  end
  return bestValue
end

function quick.sin(angle)
  return quick.getApproximation(quick.sinTable, angle)
end
function quick.cos(angle)
  return quick.getApproximation(quick.cosTable, angle)
end


local rounded = {}
local random  = {}
local reader  = {}
local checker = {}
local formatter = {}

--basic input function
local function read(typ)
  local value
  repeat
    value = io.read()
    if value then
      if typ then
        value = reader[typ](value)
        if value == nil then
          io.write("Invalid\n")
        end
      end
    else
      os.exit()
    end
  until value
  return value
end

local function nameColumn(name)
  local space = ""
  if #name < 20 then
    space = (" "):rep(20 - #name)
  end
  return name .. ": " .. space
end

local function check(name, typ, target, tolerance)
  io.write(nameColumn(name))
  local value = read(typ)
  local targetText = formatter[typ](target) .. (tolerance > 0 and (" +- " .. formatter[typ](tolerance)) or "")
  if checker[typ](value, target, tolerance) then
    if tolerance == 0 then
      io.write("Perfect!\n")
    else
      io.write("Perfect! (" .. targetText .. ")\n")
    end
    return value
  else
    io.write("Correct value: ".. formatter[typ](target) .. "\n")
  end
end

local function output(name, typ, value)
  io.write(nameColumn(name) .. formatter[typ](value) .. "\n")
end


--value "constructors"
function reader.plain(value)
  return value
end
function checker.plain(value, target)
  return value == target
end
function formatter.plain(value)
  return tostring(value)
end

function reader.filtered(value)
  return value
end
function checker.filtered(value, target)
  return not not target[value]
end
function formatter.filtered(value)
  if type(value) == "table" then
    local text = ""
    for k, v in pairs(value) do
      if v then
        if text ~= "" then
          text = text .. ", "
        end
        text = text .. k
      end
    end
    return text
  end
  return tostring(value)
end

function rounded.speed(speed)
  return math.floor(speed + 0.5)
end
function random.speed(from, to, step)
  from = rounded.speed(from)
  to   = rounded.speed(to)
  step = rounded.speed(step)
  
  local diff = to - from
  local nsteps = math.floor(diff / step)
  return from + step * math.random(0, nsteps)
end
function reader.speed(speed)
  speed = tonumber(speed)
  if speed and speed >= 0 then
    return rounded.speed(speed)
  end
end
function checker.speed(value, target, tolerance)
  return math.abs(value - target) <= tolerance
end
function formatter.speed(value)
  return ("%i kt"):format(value)
end

rounded.seconds = rounded.speed
random.seconds = random.speed
reader.seconds = reader.speed
checker.seconds = checker.speed
function formatter.seconds(value)
  return ("%i s"):format(value)
end


--turn right = positive
--0 <= value < 360
function rounded.direction(direction, delta)
  return math.floor(direction + (delta or 0) + 0.5) % 360
end
function random.direction(step)
  step = step or 10
  return math.random(0, math.floor(360 / step) - 1) * step
end
function reader.direction(direction)
  direction = tonumber(direction)
  if direction and direction <= 360 and direction >= 0 then
    return rounded.direction(direction)
  end
end
function checker.direction(value, target, tolerance)
  return math.abs(rounded.directionChange(value, target)) <= tolerance
end
function formatter.direction(value)
  return ("%u°"):format(value)
end


-- -180 <= value < 180
function rounded.directionChange(from, to)
  if to == nil then
    to = from
    from = 0
  end
  return rounded.direction(to - from + 180) - 180
end
function random.directionChange(range)
  return rounded.directionChange(math.random(-range, range))
end
function reader.directionChange(change)
  change = tonumber(change)
  if change and change <= 180 and change >= -180 then
    return rounded.directionChange(change)
  end
end
checker.directionChange = checker.direction
function formatter.directionChange(value)
  return ("%+i°"):format(value)
end

rounded.variation = rounded.directionChange
function random.variation()
  return math.random(-20, 20)
end
function reader.variation(variation)
  local sign
  variation, sign = variation:match("^(.+)%s*([EW])$")
  variation = variation and tonumber(variation)
  if sign == "E" then
    return rounded.variation(variation)
  elseif sign == "W" then
    return rounded.variation(-variation)
  end
end
checker.variation = checker.direction
function formatter.variation(value)
  if value == 0 then
    return "0°E/W"
  elseif value == -180 then
    return "180°E/W"
  elseif value > 0 then
    return ("%i°E"):format(value)
  else
    return ("%i°W"):format(-value)
  end
end

rounded.deviation = rounded.variation
random.deviation  = random.variation
reader.deviation  = reader.directionChange
checker.deviation = checker.variation
formatter.deviation = formatter.directionChange



--wind coming from right = positive
local function crosswind(state)
  local windAngle = rounded.directionChange(state.course, state.windDirection)
  return rounded.speed(state.windSpeed * quick.sin(windAngle))
end

local function headwind(state)
  local windAngle = rounded.directionChange(state.course, state.windDirection)
  return rounded.speed(state.windSpeed * quick.cos(windAngle))
end

local function wca(state)
  local crosswind = crosswind(state)
  return rounded.directionChange(60 * crosswind / state.airspeed)
end

local function gs(state)
  local headwind = headwind(state)
  return state.airspeed - headwind
end



local function checkTime(f, name)
  local t1 = os.time()
  f()
  local diff = os.difftime(os.time(), t1)
  --TODO: write log file
  io.write(("%is\n"):format(diff))
  io.write("\n")
end

local function getPermutation(n)
  local indices, permutations = {}, {}
  for i = 1, n do
    indices[i] = i
  end
  for i = n, 1, -1 do
    permutations[i] = table.remove(indices, math.random(1, i))
  end
  return permutations
end

local function reversalTraining()
  local course = random.direction(1)
  output("course", "direction", course)
  check("reversed", "direction", rounded.direction(course + 180), 0)
end
local function coursesTraining()
  local names = {"compass", "deviation", "magnetic", "variation", "true"}
  local types = {"direction", "deviation", "direction", "variation", "direction"}
  local values = {}
  values[1] = random.direction(1)
  values[2] = random.deviation()
  values[3] = rounded.direction(values[1] + values[2])
  values[4] = random.variation()
  values[5] = rounded.direction(values[3] + values[4])
  
  local checkedIndices = {}
  do
    local index1 = math.random(1, 5)
    checkedIndices[index1] = true
    if index1 < 3 then
      checkedIndices[math.random(3, 5)] = true
    elseif index1 > 3 then
      checkedIndices[math.random(1, 3)] = true
    else
      local index2 = math.random(1, 4)
      index2 = (index2 >= 3) and index2 + 1 or index2
      checkedIndices[index2] = true
    end
  end
  local permutations = getPermutation(5)
  do
    for j = 1, 5 do
      local i = permutations[j]
      if not checkedIndices[i] then
        output(names[i], types[i], values[i])
      end
    end
    for j = 1, 5 do
      local i = permutations[j]
      if checkedIndices[i] then
        check(names[i], types[i], values[i], 0)
      end
    end
  end
end
local function wcaTraining(method)
  local state = {
    course = random.direction(),
    airspeed = random.speed(60, 240, 10),
    windDirection = random.direction(),
    windSpeed = random.speed(5, 50, 5),
  }
  output("MC", "direction", state.course)
  output("Wind (°)", "direction", state.windDirection)
  output("Wind (kt)", "speed", state.windSpeed)
  output("TAS", "speed", state.airspeed)
  local wca = wca(state, method)
  local gs  = gs(state, method)
  check("WCA", "directionChange", wca, 2)
  check("GS", "speed", gs, 5)
end
local function holdingTraining()
  local outbound = random.direction()
  local inbound = rounded.direction(outbound, 180)
  local course = random.direction()
  local direction = math.random(0, 1) == 0 and "right" or "left"
  
  local state = {
    airspeed = random.speed(60, 240, 10),
    windDirection = random.direction(),
    windSpeed = random.speed(5, 50, 5),
  }
  
  local function getWCA(course)
    state.course = course
    return wca(state)
  end
  local function getHeadwind(course)
    state.course = course
    return headwind(state)
  end
    
  io.write("Hold overhead VOR\n")
  output("QDM", "direction", course)
  output("outbound", "direction", outbound)
  output("turns", "plain", direction)
  output("Wind direction", "direction", state.windDirection)
  output("Wind speed", "speed", state.windSpeed)
  output("TAS", "speed", state.airspeed)

  local entry = {}
  local outboundHeading, outboundTime
  local inboundHeading
  do
    local diff = rounded.directionChange(outbound - course)
    local factor = 1
    if direction == "left" then
      diff = -diff
      factor = -1
    end
    
    entry.parallel = {
      heading = rounded.direction(outbound + getWCA(outbound) * 2),
      time    = rounded.seconds(60 + getHeadwind(outbound)),
    }
    entry.teardrop = {
      heading = rounded.direction(outbound - 30 * factor + getWCA(outbound - 30 * factor) * 2),
      time    = rounded.seconds(60 + getHeadwind(outbound - 30 * factor)),
    }
    entry.direct = {}
    
    if diff < -5 or diff > 75 then
      entry.teardrop = nil
    elseif diff < 0 or diff > 70 then
      entry.teardrop.secondary = true
    end
    if diff < -115 or diff > 5 then
      entry.parallel = nil
    elseif diff < -110 or diff > 0 then
      entry.parallel.secondary = true
    end
    if diff > -105 and diff < 65 then
      entry.direct = nil
    elseif diff > -110 and diff < 70 then
      entry.direct.secondary = true
    end
    entry.p = entry.parallel
    entry.t = entry.teardrop
    entry.d = entry.direct
    
    outboundHeading = rounded.direction(outbound + getWCA(outbound) * 3)
    outboundTime    = rounded.seconds(60 + getHeadwind(outbound))
    inboundHeading  = rounded.direction(inbound  + getWCA(inbound))
  end
  local usedEntry = check("entry type", "filtered", entry, 0)
  for k, v in pairs(entry) do
    if v.heading then
      if usedEntry == nil then
        usedEntry = k
      elseif entry[usedEntry].secondary and not v.secondary then
        usedEntry = k
      elseif #usedEntry < #k then
        usedEntry = k
      end
    end
  end
  if usedEntry and entry[usedEntry].heading then
    io.write("Calculations for " .. usedEntry .. " entry:\n")
    check("heading", "direction", entry[usedEntry].heading, 2)
    check("time", "seconds", entry[usedEntry].time, 5)
    io.write("\n")
  end
  check("outbound heading", "direction", outboundHeading, 2)
  check("outbound time", "seconds", outboundTime, 5)
  check("inbound heading", "direction", inboundHeading, 2)
end
local function coldTemperatureTraining()
  
end
local function altitudeTraining()

end

local trainers = {
  reversal = reversalTraining,
  courses = coursesTraining,
  wca = wcaTraining,
  holding = holdingTraining,
}

local args = table.pack(...)
math.randomseed(os.time())

local names = {}
if args[1] then
  for _, name in ipairs(args) do
    if trainers[name] then
      table.insert(names, name)
    end
  end
else
  for name in pairs(trainers) do
    table.insert(names, name)
  end
end

while true do
  local name = names[math.random(1, #names)]
  local trainer = trainers[name]
  checkTime(trainer)
end
