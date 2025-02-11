const WSClient = require('../lib/ws_client');
const ResponseHandler = require('../lib/response_handler');
const RequestBuilder = require('../builders/request_builder');
const config = require('../config/config');

class LoginTest {
    constructor(root) {
        this.root = root;
        this.wsClient = null;
        this.responseHandler = new ResponseHandler(root);
    }

    async run() {
        try {
            // 连接登录服务器
            console.log('正在连接登录服务器:', config.loginServer);
            this.wsClient = new WSClient(config.loginServer);
            await this.wsClient.connect();
            console.log('连接登录服务器成功');

            // 构建并发送登录请求
            const request = RequestBuilder.buildLoginRequest(
                this.root,
                config.account,
                config.password,
                config.deviceId,
                config.platform
            );

            this.wsClient.send(request);

            // 等待并处理响应
            const response = await this.wsClient.waitForMessage();
            const loginResponse = this.responseHandler.handleLoginResponse(response);

            // 关闭连接
            this.wsClient.close();

            return loginResponse;
        } catch (error) {
            console.error('登录测试失败:', error);
            if (this.wsClient) {
                this.wsClient.close();
            }
            return null;
        }
    }
}

module.exports = LoginTest; 