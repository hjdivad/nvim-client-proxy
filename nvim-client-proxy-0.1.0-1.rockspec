---@diagnostic disable: lowercase-global

package = "nvim-client-proxy"
version = "0.1.0-1"
source = {
  url = 'git://github.com/hjdivad/nvim-client-proxy',
  tag = 'v0.1.0',
}
description = {
  homepage = "https://github.com/hjdivad/nvim-client-proxy/",
  license = "MIT"
}
dependencies = {
  'lua >= 5.1',
  'nvim-client >= 0.2.3-1',
}
build = {
  type = "builtin",
  modules = {
    nvim_client_proxy = "src/nvim_client_proxy.lua",
    ['nvim_client_proxy._stringify'] = 'src/nvim_client_proxy/_stringify.lua'
  }
}
