const BaseClient = require('./base_client');
const config = require('../config/config');

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
        await this.connect();

        const loginRequest = {
            account: account,
            password: password,
            platform: config.platform,
            version: config.version,
            deviceId: config.deviceId
        };

        // 打印可用的消息类型（调试用）
        console.log('Available message types:', this.protoHelper.listAvailableTypes());

        const response = await this.sendRequest('C2L_LOGIN_REQUEST', loginRequest);
        if (response.errorCode !== 0) {
            throw new Error(`Login failed: ${response.errorMsg}`);
        }

        const loginResponse = this.protoHelper.decodeLoginResponse(response.payload);
        console.log('Login response:', loginResponse);

        // 检查登录响应的结构
        if (!loginResponse) {
            throw new Error('Empty login response');
        }

        if (!loginResponse.token) {
            throw new Error('No token in login response');
        }

        // 从响应中获取游戏服务器信息
        const gameHost = loginResponse.ws_addr || config.gameHost || config.loginHost;
        const gamePort = loginResponse.ws_port || config.gamePort || '8022';

        console.log(`Game server: ${gameHost}:${gamePort}`);

        this.close();

        return {
            token: loginResponse.token,
            gateInfo: {
                protocol: config.protocol,
                host: gameHost,
                port: gamePort
            }
        };
    }
}

module.exports = LoginClient; 