const ProtoHelper = require('../lib/proto_helper');
const config = require('../config/config');

class CardBagBuilder {
    static build(root, token) {
        const cardBagRequest = {
            token: token || global.token,
            timestamp: Math.floor(Date.now() / 1000)
        };

        console.log('\n[CardBag] 请求详情:', cardBagRequest);

        const payload = root.lookupType("command.C2GUserCardBagRequest")
            .encode(cardBagRequest)
            .finish();

        const baseRequest = {
            session: {
                messageId: root.lookupEnum("common.MessageID").values.C2G_USER_CARD_BAG_REQUEST,
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

module.exports = CardBagBuilder; 