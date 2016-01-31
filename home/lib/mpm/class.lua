-----------------------------------------------------
--name       : home/lib/mpm/class.lua
--description: another OOP library
--author     : mpmxyz
--github page: https://github.com/mpmxyz/ocprograms
--forum page : http://oc.cil.li/index.php?/topic/
-----------------------------------------------------
--TODO: redo everything
local Object={}

local function Class(...)
  local supers = {...}
  if supers[1] == nil then
    --no super classes implies Object as superclass
    supers[1] = Object
  end
  return function(content)
    local DO_CACHING = content.__cached
    content.supers  = supers  --remember super classes
    content.class   = content --to make objects able to refer to class
    content.__index = content --the class is the objects metatable
    content.__superList = {}  --cache for super classes
    local metatable = {}
    --inheritance
    if supers[2] == nil then
      --only one super class
      content.super     = supers[1]
      --Object has no __index metamethod
      if content ~= Object then
        metatable.__index = supers[1]
      end
    else
      --multiple super classes
      if DO_CACHING then
        local nils = {}
        function metatable.__index(t, key)
          if nils[key] then
            return nil
          end
          for _, super in ipairs(t.supers) do
            local value = super[key]
            if value ~= nil then
              t[key] = value
              return value
            end
          end
          if DO_CACHING ~= "nonil" then
            nils[key] = true
          end
          return nil
        end
      else
        function metatable.__index(t, key)
          for _, super in ipairs(t.supers) do
            local value = super[key]
            if value ~= nil then
              return value
            end
          end
          return nil
        end
      end
    end
    --protecting metatable
    metatable.__metatable="blocked"
    --avoid unnecessary creation of tables 
    local tableBuffer={}
    --Constructor functions can ignore the given self table and return their own table, but then they are not allowed to modify the self table.
    function content:new(...)
      local newTable=tableBuffer
      setmetatable(newTable, self) --applying class metatable
      local init=self.__init
      if type(init)=="function" then
        --
        local otherTable=init(newTable,...)
        if otherTable~=nil and otherTable~=newTable then
          setmetatable(otherTable,self) --applying class as metatable
          return otherTable
        end
      end
      tableBuffer={}
      return newTable
    end
    --type checking
    function content:is(class)
      if type(class)~="table" then
        error("Expecting")
      end
      --uses caching
      local result=self.__superList[class]
      if result~=nil then
        return result
      end
      if class==content or class==Object then
        --shortcut for trivial solutions
        result=true
      else
        --iteration of super classes
        result=false
        local i,superClass
        for i,superClass in ipairs(self.supers) do
          if superClass:is(class) then
            result=true
            break
          end
        end
      end
      self.__superList[class]=result
      return result
    end
    setmetatable(content, metatable)
    return content
  end
end

--Object is its own super class
Object = Class(Object)(Object)

return Class
--[[
  Test=Class(super){
    __init = function(self,params)
      
    end,
  }
  
]]--
