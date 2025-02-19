const BaseClient = require('./base_client');
const config = require('../config/config');
const jwt = require('jsonwebtoken');

class LoginClient extends BaseClient {
    constructor() {
        super();
        this.serverInfo = {
            protocol: config.protocol,
            host: config.loginHost,
            port: config.loginPort
        };
    }

    // 登录并获取token
    async login(account, password) {
        try {
            await this.connect();

            const loginRequest = {
                account: account,
                password: password,
                platform: config.platform,
                version: config.version,
                deviceId: config.deviceId
            };

            const response = await this.sendRequest('C2L_LOGIN_REQUEST', loginRequest);
            if (response.errorCode !== 0) {
                throw new Error(`Login failed: ${response.errorMsg}`);
            }

            const loginResponse = this.protoHelper.decodeLoginResponse(response.payload);

            // 检查登录响应的结构
            if (!loginResponse) {
                throw new Error('Empty login response');
            }

            if (!loginResponse.token) {
                throw new Error('No token in login response');
            }

            if (!loginResponse.ws_addr || !loginResponse.ws_port) {
                throw new Error('Game server info not provided in login response');
            }

            console.log("Gateway info:", {
                host: loginResponse.ws_addr,
                port: loginResponse.ws_port,
                key: loginResponse.token
            });

            return {
                token: loginResponse.token,
                gateInfo: {
                    protocol: config.protocol,
                    host: loginResponse.ws_addr,
                    port: loginResponse.ws_port
                }
            };
        } finally {
            await this.close();
        }
    }

    // 解码 token
    decodeToken(token) {
        try {
            // 不验证签名，只解码
            return jwt.decode(token);
        } catch (error) {
            console.error('Failed to decode token:', error);
            return null;
        }
    }

    async useItem(itemId, count) {
        const request = {
            token: this.token,
            item_id: itemId,
            count: count
        };
        
        return await this.sendRequest(
            this.protoHelper.MessageID.C2G_USE_ITEM_REQUEST,
            'command.C2GUseItemRequest',
            request,
            'command.G2CUseItemResponse'
        );
    }
}

module.exports = LoginClient; 