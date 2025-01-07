local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, conf)
        if cmd == "start" then
            local gate = skynet.newservice("ws_gate")
            skynet.ret(skynet.pack(skynet.call(gate, "lua", "start", conf)))
        end
    end)
end) 