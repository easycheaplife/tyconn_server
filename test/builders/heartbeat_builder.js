const ProtoHelper = require('../lib/proto_helper');
const config = require('../config/config');

class HeartbeatBuilder {
    static build(root, token) {
        const heartbeatRequest = {
            token: token || global.token,
            timestamp: Math.floor(Date.now() / 1000)
        };

        const payload = root.lookupType("command.C2GHeartbeat")
            .encode(heartbeatRequest)
            .finish();

        const baseRequest = {
            session: {
                messageId: root.lookupEnum("common.MessageID").values.C2G_HEARTBEAT,
                sequence: 1,
                timestamp: Date.now(),
                version: "1.0.0"
            },
            payload: payload
        };

        return root.lookupType("common.BaseRequest")
            .encode(baseRequest)
            .finish();
    }
}

module.exports = HeartbeatBuilder; 