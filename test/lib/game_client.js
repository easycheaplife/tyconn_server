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
        const response = await this.sendRequest('C2G_HEARTBEAT', heartbeatRequest);
        return this.decodeResponse(response, 'command.G2CHeartbeat');
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