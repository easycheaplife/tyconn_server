const ProtoHelper = require('../lib/proto_helper');
const config = require('../config/config');

class HeartbeatBuilder {
    static build(root) {
        const messageId = root.lookup("common.MessageID");
        if (!messageId) {
            console.error("Available types:", ProtoHelper.listTypes(root));
            throw new Error("Required enum not found: common.MessageID");
        }

        const session = {
            sequence: 1,
            messageId: messageId.values["C2G_HEARTBEAT"] || 3,
            timestamp: Date.now(),
            version: config.version
        };

        const heartbeatRequest = {
            timestamp: Date.now(),
            token: global.token  // 使用全局保存的token
        };

        const payload = ProtoHelper.createMessage(root, "command.C2GHeartbeat", heartbeatRequest);
        
        return ProtoHelper.createMessage(root, "common.BaseRequest", {
            session: session,
            payload: payload
        });
    }
}

module.exports = HeartbeatBuilder; 