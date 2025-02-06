const ProtoHelper = require('../lib/proto_helper');
const config = require('../config/config');

class GetUserInfoBuilder {
    static build(root, token) {
        const messageId = root.lookup("common.MessageID");
        if (!messageId) {
            console.error("Available types:", ProtoHelper.listTypes(root));
            throw new Error("Required enum not found: common.MessageID");
        }

        const session = {
            sequence: 1,
            messageId: messageId.values["C2G_USER_INFO_REQUEST"] || 5,  // 消息ID=5
            timestamp: Date.now(),
            version: config.version
        };

        const getUserInfoRequest = {
            token: token.token
        };

        const payload = ProtoHelper.createMessage(root, "command.C2GUserInfoRequest", getUserInfoRequest);
        
        return ProtoHelper.createMessage(root, "common.BaseRequest", {
            session: session,
            payload: payload
        });
    }
}

module.exports = GetUserInfoBuilder; 