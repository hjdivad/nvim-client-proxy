---@class ChildProcessStream
local ChildProcessStream = require('nvim.child_process_stream')
---@class TcpStream
local TcpStream = require('nvim.tcp_stream')
---@class SocketStream
---@field open function
local SocketStream = require('nvim.socket_stream')
---@class Session
---@field new function
local Session = require('nvim.session')

local stringify = require('nvim_client_proxy/_stringify')

---A proxy around a neovim client session. Interact with this object as you
---would that session's own `vim` object. Getting or setting properties will be
---proxied to the underlying neovim instance.
---
---Because `VimProxy:new` defaults to reading `NVIM_LISTEN_ADDRESS`, this proxy
---can be used to interact with your actual neovim client in a neovim tui.
---
---**Example**:
---```lua
--- local vim = VimProxy.new()
--- vim.fn.bufname() --=> term://something/or/other
---
--- -- Modifies &rtp of your actual neovim instance
--- vim.opt.runtimepath.append('/some/path')
---```
---
---@class VimProxy
local VimProxy = {
  _path = nil,
  _session = nil,
  _log = false,
}

---Report equality for nested tables.
---
---**Example**
---```lua
--- vim = VimProxy.new()
--- vim.opt.runtimepath == vim.opt.runtimepath
---```
---
---This is needed because nested proxies are not cached (as doing so would give
---incorrect values when anything changed).
---
---@param b any the rhs of an equality operation to check
---@return boolean true iff `b` proxies the same vim path for the same session
function VimProxy:__eq(b)
  -- We check metatable + path equality rather than strict equality because in
  -- __index we do not cache nested tables, so rawget(vim.opt, 'foo') ~= rawget(vim.opt, 'foo')
  return getmetatable(b) == VimProxy and self._session == b._session and self._path == b._path
end

---Return the potentially proxied value for key `k`
---
---Known properties are not proxied (e.g. `_session`), as well as any property
---on the metatable `VimProxy`.
---
---Otherwise return either:
--- 1. The primitive value for key `k` at the current path (e.g. `vim.type_idx`)
--- 2. A nested `VimProxy` for a table (e.g. `vim.bo`)
--- 3. A proxy function that, when invoked, will invoke the same function `k`
--- at the current path (e.g. `vim.fn.bufname()`)
---
---@param k string the property to resolve
---@return any
function VimProxy:__index(k)
  if k == '_path' or k == '_session' or k == '_log' then
    return rawget(self, k)
  end

  local method = rawget(VimProxy, k)
  if method then
    return method
  end

  local path_k = self._path .. '["' .. k .. '"]'
  local value_type = self:rpc('return type(' .. path_k .. ')')

  if value_type == 'nil' then
    return nil
  elseif value_type == 'function' then
    return function(...)
      local params = { ... }
      if self == params[1] then
        -- self call, e.g. vim.opt.formatoptions:get()
        return self:rpc('return ' .. path_k .. '(' .. self._path .. ', ...)', table.unpack(params, 2, #params))
      else
        return self:rpc('return ' .. path_k .. '(...)', ...)
      end
    end
  elseif value_type == 'thread' or value_type == 'userdata' then
    error('Cannot proxy type: ' .. value_type)
  elseif value_type == 'table' then
    return setmetatable({
      _path = path_k,
      _session = self._session,
      _log = self._log,
    }, VimProxy)
  else
    return self:rpc('return ' .. path_k)
  end
end

---Assign the property `v` to `k` in the underlying proxy.
---
---**Note** the following types for `v` are not valid and will throw an error
--- * `thread`
--- * `userdata`
--- * `function`
---
---@param k string the key to set at the current path
---@param v string|table|boolean|number|nil
function VimProxy:__newindex(k, v)
  local string_v = stringify(v)
  self:rpc(self._path .. '["' .. k .. '"] = ' .. string_v)
end

-- This is how we would support iterating the vim proxy, but __pairs is a lua
-- 5.2 feature and luajit 2.0 only implements lua 5.1
--
-- function VimProxy:__pairs()
--   local function next(table, idx)
--   end

--   return next, self, nil
-- end


function VimProxy:rpc(fn_str, ...)
  if self._log then
    print('rpc: ' .. fn_str);
  end

  local success, result = self._session:request('nvim_exec_lua', fn_str, { ... })

  if not success then
    print('')
    for _, value in ipairs(result) do
      print(value)
    end
    error('failed to run: ' .. fn_str)
  end

  return result
end

---Close the underlying neovim client session from `nvim.session`
---
---@see Session:close
function VimProxy:close()
  if self._session then
    self._session:close()
  end
end

local EnvProxy = setmetatable({}, {
  __index = function(_, k)
    return os.getenv(k)
  end
})

---Create a new proxy around a neovim client. In general try to accept any
---valid kind of `source`, whether an existing `Session`, or any of the streams
---that a `Session` would accept.
---
---If no `source` is provided, read the os environment variable
---`NVIM_LISTEN_ADDRESS` and try to open a `SocketStream` at that address. In
---practice this means that in a lua REPL running in a neovim terminal, all
---that's needed is `VimProxy.new()` to get a vim proxy to the parent vim session.
---
---**Example**:
---```lua
--- -- Open a proxy connecting to the socket at env.NVIM_LISTEN_ADDRESS
--- local VimProxy = require('nvim_client_proxy')
---
--- vim = VimProxy.new()
---```
---**Example**:
---```lua
--- local ChildProcessStream = require('nvim.child_process_stream')
--- local VimProxy = require('nvim_client_proxy')
---
--- -- Create a vim proxy around a new embedded neovim process
--- vim = VimProxy.new(ChildProcessStream.spawn({
---   'nvim', '-u', 'NONE', '--embed'
--- }))
---```
---
---@param source nil|string|Session|SocketStream|ChildProcessStream|TcpStream
---@return VimProxy
function VimProxy.new(source, ...)
  local opts = ({ ... })[1] or {}
  local env = opts.env or EnvProxy
  local session

  if nil == source then
    -- create a session from NVIM_LISTEN_ADDRESS


    local nvim_addr = env.NVIM_LISTEN_ADDRESS

    if not nvim_addr then
      error('VimProxy.new(source) requires source or a valid env.NVIM_LISTEN_ADDRESS')
    end

    local socket = SocketStream.open(nvim_addr)
    session = Session.new(socket)
  elseif type(source) == 'string' then
    -- create a session from socket at path `source`

    local socket = SocketStream.open(source)
    session = Session.new(socket)
  else
    local smt = getmetatable(source)
    if smt == Session then
      -- create a wrapper around an existing session
      session = source
    elseif smt == SocketStream or smt == TcpStream or smt == ChildProcessStream then
      -- create a session from an existing stream
      session = Session.new(source)
    else
      error('VimProxy.new(source) cannot create nvim client session from source: ' .. source)
    end
  end


  return setmetatable({
    _path = 'vim',
    _session = session,
    _log = false,
  }, VimProxy)
end

return VimProxy
