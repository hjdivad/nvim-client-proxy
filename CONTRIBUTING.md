# Contributing

## Build

> **Warning**
> Building on OSX requires a patched [libmpack-lua][libmpack-patch]

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
## Release

To release version `Y` from `X` do the following:

1. Rename `nvim-client-proxy-${X}.rockspec` to `nvim-client-proxy-${Y}.rockspec`
2. Update `version` in the rockspec to `Y`
3. Add a section at the top of [CHANGELOG.md](./CHANGELOG.md). Be sure to keep the right format. Two things to keep in mind:
  a. Blank lines need spaces 😭.
  b. You can test the release notes with `make Release.txt`
4. Create a commit with the updated [CHANGELOG.md](./CHANGELOG.md) and push it (optionally merge to master via a PR).
5. Tag the commit `git tag v${Y}` and push the tag.

Pushing a tag will automatically trigger the release workflow, which releases to:
* GitHub and
* LuaRocks


[libmpack-patch]: https://github.com/libmpack/libmpack-lua/pull/31
