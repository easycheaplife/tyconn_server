const ProtoHelper = require('../lib/proto_helper');
const config = require('../config/config');

class UserCardsBuilder {
    static build(root, token) {
        const userCardsRequest = {
            token: token || global.token,
            timestamp: Math.floor(Date.now() / 1000)
        };

        console.log('\n[UserCards] 请求详情:', userCardsRequest);

        const payload = root.lookupType("command.C2GUserCardsRequest")
            .encode(userCardsRequest)
            .finish();

        const baseRequest = {
            session: {
                messageId: root.lookupEnum("common.MessageID").values.C2G_USER_CARDS_REQUEST,
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

module.exports = UserCardsBuilder; 