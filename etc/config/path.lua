cpath = "./skynet/cservice/?.so"

lualoader = "./skynet/lualib/loader.lua"

luaservice = "./service/?.lua;"..
            "./service/game/?.lua;"..
            "./service/gate/?.lua;"..
            "./service/?/init.lua;"..
            "./skynet/service/?.lua"

lua_path = "./lualib/?.lua;" .. "./etc/?.lua;" .. "./lualib/?.lua;" .. "./skynet/lualib/?.lua;" .. "./skynet/lualib/?/init.lua;"

lua_cpath = "./luaclib/?.so;" .. "./skynet/luaclib/?.so"
