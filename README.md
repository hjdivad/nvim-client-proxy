# nvim_client_proxy

A proxy around neovim's [lua client](https://github.com/neovim/lua-client) that provides an interface that matches the `vim` object within neovim.

```lua
local VimProxy = require('nvim_client_proxy')

-- create a proxy to the neovim running at NVIM_LISTEN_ADDRESS, e.g. the parent
-- neovim instance for a neovim terminal
local vim = VimProxy.new()

print(vim.o.grepprg)
--=> rg --vimgrep
```

The intended use case is to have convenient access to the parent neovim instance in a lua REPL, rather than using command-mode or something similar for testing neovim's API.

## Install

> **Warning**
> These instructions are preliminary. This rock is not published yet

```bash
luarocks install neovim-client-proxy
```

For instructions on building locally, see [CONTRIBUTING.md](./CONTRIBUTING.md)

## Usage

Create an instance of a proxy from any of the following sources:
* *default* The os environment variable `NVIM_LISTEN_ADDRESS`
* A string whose value is the path to a neovim socket (e.g. the same path passed to `nvim --listen <address>`)
* An existing [Session][session.lua]
* An existing [SocketStream][socket_stream.lua], [ChildProcessStream][child_process_stream.lua] or [TcpStream][tcp_stream.lua]

The proxy can do the following in the neovim session:
* Read strings, booleans and numbers
* Recursively read tables
* Invoke functions
* Set strings, booleans, numbers and arbitrarily nesteed tables

It cannot set any of:
* userdata
* thread
* function

```lua
local VimProxy = require('nvim_client_proxy')

-- connect to the parent neovim process listening on NVIM_LISTEN_ADDRESS
local vim = VimProxy.new()

local ChildProcessStream = require('nvim.child_process_stream')
-- create a new instance of neovim and attach a proxy to it
local child_vim = VimProxy.new(ChildProcessStream.new({
  'nvim', '-u', 'NONE', '--embed'
}))

-- read vim options
print(vim.o.filetype)
print(vim.bo.autoread)
print(vim.wo.number)

--set vim options
vim.wo.number = true

--set vim options using the options api
vim.opt.runtimepath:append('/some/path')
```

[session.lua]: https://github.com/neovim/lua-client/blob/387fdb32b2e787347aea4a0c896d8b3ffd0491df/nvim/session.lua
[socket_stream.lua]: https://github.com/neovim/lua-client/blob/387fdb32b2e787347aea4a0c896d8b3ffd0491df/nvim/socket_stream.lua
[child_process_stream.lua]: https://github.com/neovim/lua-client/blob/387fdb32b2e787347aea4a0c896d8b3ffd0491df/nvim/child_process_stream.lua
[tcp_stream.lua]: https://github.com/neovim/lua-client/blob/387fdb32b2e787347aea4a0c896d8b3ffd0491df/nvim/tcp_stream.lua
