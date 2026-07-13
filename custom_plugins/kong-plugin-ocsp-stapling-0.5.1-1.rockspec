package = "kong-plugin-ocsp-stapling"
-- keep in sync with VERSION in kong/plugins/ocsp-stapling/handler.lua
version = "0.5.1-1"

source = {
  url = "git+https://github.com/StuAtKong/kongpose.git",
  branch = "ocsp-stapling-plugin",
  -- the plugin lives under custom_plugins/ within the kongpose repo
}

description = {
  summary = "OCSP stapling for certificates served dynamically by Kong (POC, unsupported)",
  license = "Apache 2.0",
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.ocsp-stapling.handler"] = "kong/plugins/ocsp-stapling/handler.lua",
    ["kong.plugins.ocsp-stapling.schema"] = "kong/plugins/ocsp-stapling/schema.lua",
  },
}
