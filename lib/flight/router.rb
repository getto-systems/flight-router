require "flight/router/version"

module Flight
  module Router
    autoload :HashEx,    "flight/router/hash_ex"
    autoload :Drawer,    "flight/router/drawer"
    autoload :Container, "flight/router/container"
    autoload :MapBase,   "flight/router/map_base"
    autoload :Map,       "flight/router/map"
    autoload :App,       "flight/router/app"
  end
end
