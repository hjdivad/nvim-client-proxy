-- forked from <https://github.com/Perkovec/stringify-lua/blob/2988d1d7dfa4f055ae8cd8509f33275ca5970eab/src/stringify.lua#L1-L36>

local M = {}

local function stringify_str(s)
  return "'" .. s:gsub("'", [[\']]) .. "'"
end

function M.stringify_table(t, typ)
  local recursive_opts = { ['type'] = typ }
  -- Maybe buffering in a list is faster than constant string concatenation.
  -- This code is not benchmarked or optimized at all.
  local buf = {}
  for key, value in pairs(t) do
    local kt = typ(key)
    local v_string = M.stringify(value, recursive_opts)
    if kt == 'number' then
      table.insert(buf, v_string)
    else -- kt == 'string'
      table.insert(buf, "[" .. stringify_str(key) .. "]=" .. v_string)
    end
  end
  return '{' .. table.concat(buf, ', ') .. '}'
end

function M.stringify(v, ...)
  -- LuaJIT (i.e. Lua5.1) compatible variant onf table.pack(...)[1]
  local opts = ({ ... })[1] or {}
  local typ = opts.type or type

  local v_type = typ(v)
  if v_type == 'string' then
    return stringify_str(v)
  elseif v_type == 'table' then
    return M.stringify_table(v, typ)
  elseif v_type == 'userdata' or v_type == 'thread' or v_type == 'function' then
    error('Cannot stringify ' .. v_type)
  else
    return tostring(v)
  end
end

return M.stringify
