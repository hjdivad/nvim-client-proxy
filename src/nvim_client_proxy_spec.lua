local test_helper = require('test_helper')

local ChildProcessStream = require('nvim.child_process_stream')
local SocketStream = require('nvim.socket_stream')
local Session = require('nvim.session')

local VimProxy = require('nvim_client_proxy')

local nvim_prog = os.getenv('NVIM_PROG') or 'nvim'

test_helper.setup()

describe('VimProxy', function()
  math.randomseed(os.time())

  local vim, child
  local socket_file = string.format('/tmp/nvim.socket-%d', math.random(1000, 9999))

  after_each(function()
    if vim then
      vim:close()
      vim = nil
    end

    if child then
      child:close()
      child = nil
    end

    local fd = io.open(socket_file)
    if fd then
      os.execute(string.format('rm %s', socket_file))
      fd:close()
    end
  end)

  local function create_detached_child_session()
    child = Session.new(ChildProcessStream.spawn({
      nvim_prog, '-u', 'NONE', '--embed', '--headless',
      '--cmd', string.format('call serverstart("%s")', socket_file)
    }))
    child:request('nvim_eval', '1') -- wait for nvim to start

    return child
  end

  describe('.new', function()
    it('creates new client sessions from child process streams', function()
      vim = VimProxy.new(
        ChildProcessStream.spawn({
          nvim_prog, '-u', 'NONE', '--embed',
        })
      )
      assert.equal(0, vim.version().major, 'nvim child process 0.7.0')
      assert.equal(7, vim.version().minor, 'nvim child process 0.7.0')
      assert.equal(0, vim.version().patch, 'nvim child process 0.7.0')
    end)

    it('creates new client sesions from socket streams', function()
      child = create_detached_child_session()
      vim = VimProxy.new(
        SocketStream.open(socket_file)
      )
      assert.equal(0, vim.version().major, 'nvim child process 0.7.0')
      assert.equal(7, vim.version().minor, 'nvim child process 0.7.0')
      assert.equal(0, vim.version().patch, 'nvim child process 0.7.0')
    end)

    it('creates new client sesions from socket addressees', function()
      child = create_detached_child_session()
      vim = VimProxy.new(socket_file)
      assert.equal(0, vim.version().major, 'nvim child process 0.7.0')
      assert.equal(7, vim.version().minor, 'nvim child process 0.7.0')
      assert.equal(0, vim.version().patch, 'nvim child process 0.7.0')
    end)

    it('creates instances from client sessions', function()
      child = Session.new(
        ChildProcessStream.spawn({
          nvim_prog, '-u', 'NONE', '--embed',
        })
      )
      vim = VimProxy.new(child)
      assert.equal(0, vim.version().major, 'nvim child process 0.7.0')
      assert.equal(7, vim.version().minor, 'nvim child process 0.7.0')
      assert.equal(0, vim.version().patch, 'nvim child process 0.7.0')
    end)

    it('defaults to creating a new client session from env.NVIM_LISTEN_ADDRESS', function()
      child = create_detached_child_session()
      -- Mimic VimProxy.new() but with a mock for os.getenv('NVIM_LISTEN_ADDRESS')
      vim = VimProxy.new(nil, { env = { NVIM_LISTEN_ADDRESS = socket_file } })
      assert.equal(0, vim.version().major, 'nvim child process 0.7.0')
      assert.equal(7, vim.version().minor, 'nvim child process 0.7.0')
      assert.equal(0, vim.version().patch, 'nvim child process 0.7.0')
    end)

    it('errors gracefully', function()
      assert.has_error(function()
        VimProxy.new(nil, { env = {} })
      end, 'VimProxy.new(source) requires source or a valid env.NVIM_LISTEN_ADDRESS')
    end)
  end)

  describe('instances', function()
    before_each(function()
      vim = VimProxy.new(
        ChildProcessStream.spawn({
          nvim_prog, '-u', 'NONE', '--embed',
        })
      )
    end)

    it('Proxies nils', function()
      assert.same(nil, vim.probably_nil)
    end)

    it('Proxies functions', function()
      assert.equals('function', type(vim.tbl_count))
      assert.equals(2, vim.tbl_count({ 'a', 'b' }))
      assert.equals(4, vim.tbl_count({ a = 1, b = 2, c = 3, d = 4 }))

      assert.equals('function', type(vim.tbl_get))
      assert.equals(123, vim.tbl_get({ foo = 123 }, 'foo'))
    end)

    it('Proxies booleans', function()
      assert.equals('boolean', type(vim.type_idx))
      assert.equals(true, vim.type_idx)
      assert.equals('boolean', type(vim.val_idx))
      assert.equals(false, vim.val_idx)
    end)

    it('Deep proxies tables', function()
      assert.equals('table', type(vim.fn))
      assert.equals('function', type(vim.fn.exists), 'nested function')
      assert.equals(0, vim.fn.exists('unlikely'), 'nested function invocation')

      assert.equals(nil, vim.g.foo, 'vim.g.foo')
      vim.g.foo = 'hello'
      assert.equals('hello', vim.g.foo, 'vim.g.foo (set)')
    end)

    -- This specific test is pretty annoying because vim has several different
    -- kinds of options:
    --  * global only
    --  * window-local only
    --  * buffer-local only
    --  * global-local window
    --  * buffer-local buffer
    --
    -- In practice this means one should always read `vim.o.${option}` but
    -- write to one of:
    --  * `vim.bo`
    --  * `vim.wo`
    --  * `vim.go`
    it('works with options', function()
      local bufnr_0 = vim.fn.bufnr()
      assert.equals('followic', vim.o.tc, 'vim.bo read initial')
      assert.equals('', vim.o.fcs, 'vim.wo read initial')
      vim.cmd('wincmd n')
      local bufnr_1 = vim.fn.bufnr()
      assert.Not.same(bufnr_0, bufnr_1, 'new window new buffer')
      vim.bo.tc = 'smart'
      vim.wo.fcs = 'stl:^,stlnc:=,'
      assert.equals('smart', vim.o.tc, 'vim.bo. =')
      assert.equals('stl:^,stlnc:=,', vim.o.fcs, 'vim.wo. =')
      vim.cmd('wincmd p')
      assert.equals('followic', vim.o.tc, 'vim.bo local option was set')
      assert.equals('', vim.o.fcs, 'vim.wo local option was set')
      vim.cmd('wincmd p')
      vim.go.tc = 'match'
      vim.go.fcs = 'stl:^,stlnc:=,'
      vim.cmd('wincmd p')
      assert.same(bufnr_0, vim.fn.bufnr(), 'back to initial buffer/window')
      assert.equals('match', vim.o.tc, 'vim.bo global option was set')
      assert.equals('stl:^,stlnc:=,', vim.o.fcs, 'vim.wo global option was set')
    end)

    it('does not cache', function()
      assert.equals('table', type(vim.opt.formatoptions))
      assert.equals(vim.opt.formatoptions, vim.opt.formatoptions, 'proxies claim equality')

      -- grab vim.opt.formatoptions twice, clear the metatable, so that it uses
      -- the default table equality and not VimProxy:__eq
      local nt1 = setmetatable(vim.opt.formatoptions, {})
      local nt2 = setmetatable(vim.opt.formatoptions, {})
      assert.Not.equals(nt1, nt2, 'tables are not actually the same instance')
    end)

    it('supports options API', function()
      assert.equals('tcqj', vim.o.formatoptions, 'default option')
      vim.o.formatoptions = vim.o.formatoptions .. 'o'
      assert.equals('tcqjo', vim.o.formatoptions, 'modified option')

      vim.o.formatoptions = 'cj'
      assert.equals('cj', vim.o.formatoptions, 'modified option')
      assert.same({ c = true, j = true }, vim.opt.formatoptions:get(), 'options API using self')
      assert.same({ c = true, j = true }, vim.opt.formatoptions.get(vim.opt.formatoptions), 'options API sending proxy')
      vim.opt.formatoptions:prepend('t')
      assert.same({ c = true, j = true, t = true }, vim.opt.formatoptions:get(), 'vim.opt.prepend')
      vim.o.formatoptions = 'cj'
      vim.opt.formatoptions:append('q')
      assert.same({ c = true, j = true, q = true }, vim.opt.formatoptions:get(), 'vim.opt.append')

      vim.opt.runtimepath:prepend('/test-prefix');
      assert.matches('^/test%-prefix,', vim.o.runtimepath, 'vim.opt.prepend')

      vim.opt.runtimepath:append('/test-suffix');
      assert.matches('/test%-suffix$', vim.o.runtimepath, 'vim.opt.append')
    end)
  end)
end)
