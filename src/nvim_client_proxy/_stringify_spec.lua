local stringify = require('nvim_client_proxy/_stringify')

describe('stringify', function()
  it('stringifies non-string primitives', function()
    assert.equals('nil', stringify(nil))
    assert.equals('true', stringify(true))
    assert.equals('false', stringify(false))
    assert.equals('123.45', stringify(123.45))
  end)

  it('stringifies strings', function()
    assert.equals([['hello']], stringify('hello'))
    assert.equals([['o\'he"ll\'o']], stringify([[o'he"ll'o]]))
    assert.equals([['o\'o\'\'\'o']], stringify([[o'o'''o]]))
  end)

  it('stringifies tables', function()
    assert.equals([[{'one', 'two', 'three', 'four'}]], stringify({ 'one', 'two', 'three', 'four' }), 'stringifies lists')
    assert.equals([[{['str']='str', ['num']=123.45, ['bool']=true, ['bad\'str']='badstr'}]], stringify({ str = 'str', bool = true, num = 123.45, ["bad'str"] = 'badstr' }), 'stringifies dictionaries')
    assert.equals([[{'one', 'two', ['three']='three', ['four']=true}]], stringify({ 'one', 'two', three = 'three', four = true }), 'stringifies mixed tables')
  end)

  it('stringifies tables recursively', function()
    assert.equals([[{{{1}}, {'two'}, 'three'}]], stringify({ { { 1 } }, { 'two' }, 'three' }), 'stringifies recursive lists')
    assert.equals([[{{['A']={['B']=true}}, ['a']={['b']={['c']={'d'}}}}]], stringify({ a = { b = { c = { 'd' } } }, { A = { B = true } } }), 'stringifies recursive dictionaries')
    assert.equals([[{'a', 2, ['b\'\'']={3, {['What\'s this key']=true}}}]], stringify({ 'a', 2, ["b''"] = { 3, { ["What's this key"] = true } } }), 'stringifies complex tables')
  end)

  it('errors on functions', function()
    local function fn()
      return stringify(function() end)
    end

    assert.has_error(fn, 'Cannot stringify function')
  end)

  it('errors on userdata', function()
    local function mock_type()
      return 'userdata'
    end

    local function fn()
      return stringify(nil, { ['type'] = mock_type })
    end

    assert.has_error(fn, 'Cannot stringify userdata')
  end)

  it('errors on threads', function()
    local function mock_type()
      return 'thread'
    end

    local function fn()
      return stringify(nil, { ['type'] = mock_type })
    end

    assert.has_error(fn, 'Cannot stringify thread')
  end)
end)
