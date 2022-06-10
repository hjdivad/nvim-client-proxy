package = "nvim-client-proxy"
version = "0.1.0"
source = {
  url = 'https://github.com/hjdivad/nvim-client-proxy/archive/' .. version .. '.tar.gz',
}
description = {
  homepage = "https://github.com/hjdivad/nvim-client-proxy/",
  license = "MIT"
}
dependencies = {
  'lua >= 5.1',
  'nvim-client >= 0.2.3-2',
}
build = {
  type = "builtin",
  modules = {
    nvim_client_proxy = "src/nvim_client_proxy.lua",
    ['nvim_client_proxy._stringify'] = 'src/nvim_client_proxy/_stringify.lua'
  }
}
