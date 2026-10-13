-- A small JSON reader for running the game outside the Playdate (tools/sim,
-- tools/story_check.lua): the same json.decodeFile the Playdate SDK has,
-- reading paths from the game's source folder.
--   dofile("json.lua")(sourceDir)  -- sets the global `json`
return function(root)
  local function decode(s)
    local i = 1
    local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
    local value
    local function str()
      local out, j = {}, i + 1
      while true do
        local c = s:sub(j, j)
        if c == '"' then i = j + 1; return table.concat(out) end
        if c == "\\" then
          local e = s:sub(j + 1, j + 1)
          if e == "u" then
            out[#out + 1] = utf8.char(tonumber(s:sub(j + 2, j + 5), 16)); j = j + 6
          else
            out[#out + 1] = ({ n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" })[e] or e; j = j + 2
          end
        elseif c == "" then error("unterminated string")
        else out[#out + 1] = c; j = j + 1 end
      end
    end
    function value()
      ws()
      local c = s:sub(i, i)
      if c == "{" then
        local t = {}; i = i + 1; ws()
        if s:sub(i, i) == "}" then i = i + 1; return t end
        while true do
          ws(); local k = str(); ws(); assert(s:sub(i, i) == ":", "expected : at " .. i); i = i + 1
          t[k] = value(); ws()
          local d = s:sub(i, i); i = i + 1
          if d == "}" then return t end
          assert(d == ",", "expected , at " .. i)
        end
      elseif c == "[" then
        local t = {}; i = i + 1; ws()
        if s:sub(i, i) == "]" then i = i + 1; return t end
        while true do
          t[#t + 1] = value(); ws()
          local d = s:sub(i, i); i = i + 1
          if d == "]" then return t end
          assert(d == ",", "expected , at " .. i)
        end
      elseif c == '"' then return str()
      elseif s:sub(i, i + 3) == "true" then i = i + 4; return true
      elseif s:sub(i, i + 4) == "false" then i = i + 5; return false
      elseif s:sub(i, i + 3) == "null" then i = i + 4; return nil
      else
        local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
        assert(num and #num > 0, "bad JSON at " .. i)
        i = i + #num
        return tonumber(num)
      end
    end
    return value()
  end
  json = {
    decode = decode,
    decodeFile = function(path)
      local f = io.open(root .. "/" .. path)
      if not f then return nil end
      local s = f:read("a"); f:close()
      return decode(s)
    end,
  }
end
