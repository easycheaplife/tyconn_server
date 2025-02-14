const ProtoHelper = require('../lib/proto_helper');
const config = require('../config/config');

class HeartbeatBuilder {
    static build(root, token) {
        const heartbeatRequest = {
            token: token || global.token,
            timestamp: Math.floor(Date.now() / 1000)
        };

        console.log('发送心跳请求:', heartbeatRequest);

        const payload = root.lookupType("command.C2GHeartbeat")
            .encode(heartbeatRequest)
            .finish();

        const baseRequest = {
            session: {
                messageId: root.lookupEnum("common.MessageID").values.C2G_HEARTBEAT_REQUEST,
                sequence: 1,
                timestamp: Date.now(),
                version: "1.0.0"
            },
            payload: payload
        };

        console.log('心跳请求基础信息:', baseRequest);

        return root.lookupType("common.BaseRequest")
            .encode(baseRequest)
            .finish();
    }
}

module.exports = HeartbeatBuilder; 