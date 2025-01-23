const ProtoHelper = require('../lib/proto_helper');
const config = require('../config/config');

class LoginRequestBuilder {
    static build(root, account, password) {
        // 验证所需的类型是否存在
        const messageId = root.lookup("common.MessageID");
        if (!messageId) {
            console.error("Available types:", ProtoHelper.listTypes(root));
            throw new Error("Required enum not found: common.MessageID");
        }

        const session = {
            sequence: 1,
            messageId: messageId.values["C2L_LOGIN_REQUEST"] || 1, // 使用默认值 1
            timestamp: Date.now(),
            version: config.version
        };

        const loginRequest = {
            account: account,
            password: password,
            deviceId: config.deviceId,
            platform: config.platform,
            version: config.version
        };

        const payload = ProtoHelper.createMessage(root, "command.C2LLoginRequest", loginRequest);
        
        return ProtoHelper.createMessage(root, "common.BaseRequest", {
            session: session,
            payload: payload
        });
    }
}

module.exports = LoginRequestBuilder; 