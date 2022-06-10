local assert = require('luassert')
local say = require('say')

local function matches(_, args)
  local pattern = args[1]
  local string = args[2]
  return string:find(pattern) ~= nil
end

local assertions_setup = false

local function setup()
  if assertions_setup then
    return
  end

  -- these get formatted in a bad way, probably due to
  -- https://github.com/Olivine-Labs/luassert/blob/e2ab0d218d7a63bbaa2fdebfa861c24a48451e9d/src/assert.lua#L17
  say:set('assertion.matches.positive', 'Expected pattern %s to match string %s')
  say:set('assertion.matches.negative', 'Expected pattern %s to not match string %s')
  assert:register('assertion', 'matches', matches, 'assertion.matches.positive', 'assertion.matches.negative')

  assertions_setup = true
end

return { setup = setup }
