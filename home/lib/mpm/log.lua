-----------------------------------------------------
--name       : home/lib/mpm/log.lua
--description: gives you a logging function
--author     : mpmxyz
--github page: https://github.com/mpmxyz/ocprograms
--forum page : http://oc.cil.li/index.php?/topic/
-----------------------------------------------------
--TODO: test/document/publish
local logging = {}

function logging.setPath(path, clear)
  local mode = clear and "w" or "a"
  logging.file = assert(io.open(path, mode))
  if mode == "a" then
    logging.log()
  end
  logging.log("mpm.log", os.date())
end

function logging.log(...)
  local values = table.pack(...)
  local text = table.concat(values, "\t", 1, values.n) .. "\n"
  logging.file:write(text)
  if logging.file.flush then
    logging.file:flush()
  end
end

function logging.logMem(...)
  local computer = require("computer")
  local free = 0
  for i = 1, 10 do
    free = math.max(computer.freeMemory(), free)
  end
  logging.log(free .. "B/" .. computer.totalMemory() .. "B free", ...)
end

logging.setPath("/main.log")

return logging
