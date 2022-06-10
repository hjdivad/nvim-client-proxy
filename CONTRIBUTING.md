# Contributing

## Build

> **Warning**
> Building on OSX requires patches to both libmpack-lua and nvim-client

```bash
make
```

## Test

```bash
# run tests from the shell
make test

# run tests in watch mode
watchexec -- ./.deps/usr/bin/busted --lpath='./src/?.lua\;./test/?.lua' src/
```

```lua
-- configure vim-test to run busted correctly
vim.g['test#lua#busted#executable'] = './.deps/usr/bin/busted --lpath="./src/?.lua;./test/?.lua"'

```
