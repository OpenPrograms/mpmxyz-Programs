local parser = require("parser.main")
local lua = require("parser.lua")

local lrtable = parser.loadLanguage(lua)
parser.saveLRTable(lrtable, "parser/lualr.lua")