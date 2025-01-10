root = "./"
skynet_root = "./skynet/"

-- C服务路径
cpath = skynet_root.."cservice/?.so"

-- Lua加载器
lualoader = skynet_root.."lualib/loader.lua"

-- Lua服务路径
luaservice = root.."service/?.lua;"..
            root.."service/game/?.lua;"..
            root.."service/gate/?.lua;"..
            root.."service/?/init.lua;"..
            skynet_root.."service/?.lua"

-- Lua模块路径
lua_path = root.."lualib/?.lua;"..
          root.."service/?.lua;"..     -- 添加 service 目录
          root.."service/game/?.lua;".. -- 添加 game 子目录
          root.."etc/?.lua;"..
          skynet_root.."lualib/?.lua;"..
          skynet_root.."lualib/?/init.lua"

-- C模块路径
lua_cpath = root.."luaclib/?.so;"..
           skynet_root.."luaclib/?.so"

-- protobuf 路径
proto_path = root.."proto/"
