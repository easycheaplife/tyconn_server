const BaseClient = require('./base_client');

class GameClient extends BaseClient {
    constructor(token, serverInfo) {
        super();
        this.setAuth(token, serverInfo);
    }

    // 发送心跳
    async sendHeartbeat() {
        const heartbeatRequest = {
            token: this.token,
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

    // 获取卡包信息
    async getCardBag() {
        const cardBagRequest = {
            token: this.token
        };

        console.log('\nSending card bag request:', cardBagRequest);
        const response = await this.sendRequest('C2G_USER_CARD_BAG_REQUEST', cardBagRequest);
        return this.decodeResponse(response, 'command.G2CUserCardBagResponse');
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
        const useItemRequest = {
            token: this.token,
            item_id: itemId,
            count: count || 1
        };

        console.log('\nSending use item request:', useItemRequest);
        try {
            const response = await this.sendRequest('C2G_USE_ITEM_REQUEST', useItemRequest);
            return this.decodeResponse(response, 'command.G2CUseItemResponse');
        } catch (error) {
            console.error('Failed to use item:', error);
            throw error;
        }
    }

    // 解码响应数据
    decodeResponse(response, responseType) {
        console.log(`\nDecoding response for type: ${responseType}`);
        
        if (response.errorCode !== 0) {
            console.error('Request failed:', response.errorMsg);
            throw new Error(`Request failed: ${response.errorMsg}`);
        }

        if (!response.payload) {
            console.error('Empty response payload');
            throw new Error('Empty response payload');
        }

        try {
            const decoded = this.protoHelper.decodeMessage(responseType, response.payload);
            console.log('Decoded payload:', JSON.stringify(decoded, null, 2));
            return decoded;
        } catch (error) {
            console.error('Failed to decode response:', error);
            throw error;
        }
    }
}

module.exports = GameClient; 