const BaseClient = require('./base_client');

class GameClient extends BaseClient {
    constructor(token, serverInfo) {
        super();
        this.setAuth(token, serverInfo);
    }

    // 发送心跳
    async sendHeartbeat(token) {
        const heartbeatRequest = {
            token: token || this.token,
            timestamp: Date.now()
        };

        console.log('\nSending heartbeat request:', heartbeatRequest);
        const response = await this.sendRequest('C2G_HEARTBEAT_REQUEST', heartbeatRequest);
        return this.decodeResponse(response, 'command.G2CHeartbeatResponse');
    }

    // 获取用户信息
    async getUserInfo() {
        const userInfoRequest = {
            token: this.token
        };

        console.log('\nSending user info request:', userInfoRequest);
        const response = await this.sendRequest('C2G_USER_INFO_REQUEST', userInfoRequest);
        return this.decodeResponse(response, 'command.G2CUserInfoResponse');
    }

    // 获取用户卡牌
    async getUserCards() {
        const userCardsRequest = {
            token: this.token
        };

        console.log('\nSending user cards request:', userCardsRequest);
        const response = await this.sendRequest('C2G_USER_CARDS_REQUEST', userCardsRequest);
        return this.decodeResponse(response, 'command.G2CUserCardsResponse');
    }

    // 获取背包信息
    async getBagInfo() {
        const bagInfoRequest = {
            token: this.token
        };

        console.log('\nSending bag info request:', bagInfoRequest);
        try {
            const response = await this.sendRequest('C2G_BAG_INFO_REQUEST', bagInfoRequest);
            return this.decodeResponse(response, 'command.G2CBagInfoResponse');
        } catch (error) {
            console.error('Failed to get bag info:', error);
            throw error;
        }
    }

    // 使用物品
    async useItem(itemId, count) {
        // 确保已经初始化
        if (!this.protoHelper.initialized) {
            await this.protoHelper.init();
        }

        // 获取正确的消息ID
        const messageId = this.protoHelper.MessageID["C2G_USE_ITEM_REQUEST"];
        if (!messageId) {
            throw new Error("Message ID not found for C2G_USE_ITEM_REQUEST");
        }

        const useItemRequest = {
            token: this.token,
            item_id: itemId,
            count: count || 1
        };

        console.log('\nSending use item request:', useItemRequest);
        const response = await this.sendRequest(messageId, useItemRequest);
        return this.decodeResponse(response, 'command.G2CUseItemResponse');
    }

    // 扩展背包
    async expandBag(params) {
        // 确保已经初始化
        if (!this.protoHelper.initialized) {
            await this.protoHelper.init();
        }

        // 如果指定了bag_type，使用指定的值，否则使用默认值
        let bag_type = params.bag_type;
        if (bag_type === undefined) {
            bag_type = 1;  // BAG_TYPE_MAIN
        }

        // 构造请求
        const expandBagRequest = {
            token: this.token,
            bag_type: bag_type,
            add_size: Number(params.add_size)
        };

        // 打印请求信息
        console.log('\nSending expand bag request:', expandBagRequest);

        try {
            const response = await this.sendRequest('C2G_EXPAND_BAG_REQUEST', expandBagRequest);
            return this.decodeResponse(response, 'command.G2CExpandBagResponse');
        } catch (error) {
            console.error('Failed to expand bag:', error);
            throw error;
        }
    }

    decodeResponse(response, responseType) {
        // 检查基础响应中的错误码
        if (response.errorCode !== 0) {
            console.error('Request failed with error code:', response.errorCode);
            throw new Error(`Invalid token (error code: ${response.errorCode})`);
        }

        if (!response.payload) {
            console.error('Empty response payload');
            throw new Error('Empty response payload');
        }

        try {
            // 获取消息类型定义
            const messageType = this.protoHelper.root.lookupType(responseType);
            console.log('\nMessage type fields:', messageType.toJSON().fields);

            // 解码消息
            const decoded = this.protoHelper.decodeMessage(responseType, response.payload);
            
            // 显示完整字段，包括默认值和未设置的字段
            const fullFields = {};
            for (const [fieldName, field] of Object.entries(messageType.fields)) {
                if (fieldName === 'user' && decoded[fieldName]) {
                    const userType = this.protoHelper.root.lookupType('common.UserInfo');
                    const userFields = {};
                    for (const [userField, userFieldDef] of Object.entries(userType.fields)) {
                        userFields[userField] = decoded[fieldName][userField] ?? 
                            (userFieldDef.type === 'string' ? '' : 
                             userFieldDef.type === 'bool' ? false : 0);
                    }
                    fullFields[fieldName] = userFields;
                } else {
                    fullFields[fieldName] = decoded[fieldName] ?? 
                        (field.type === 'string' ? '' : 
                         field.type === 'bool' ? false : 0);
                }
            }

            console.log('Decoded payload (with all fields):', JSON.stringify(fullFields, null, 2));
            return decoded;
        } catch (error) {
            console.error('Failed to decode response:', error);
            throw error;
        }
    }
}

module.exports = GameClient; 