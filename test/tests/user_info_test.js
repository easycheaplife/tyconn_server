const WSClient = require('../lib/ws_client');
const ResponseHandler = require('../lib/response_handler');
const RequestBuilder = require('../builders/request_builder');

class UserInfoTest {
    constructor(root, loginResponse) {
        this.root = root;
        this.loginResponse = loginResponse;
        this.wsClient = null;
        this.responseHandler = new ResponseHandler(root);
    }

    async run() {
        try {
            // 连接网关服务器
            const wsUrl = `ws://${this.loginResponse.ws_addr}:${this.loginResponse.ws_port}`;
            console.log('正在连接网关服务器:', wsUrl);
            this.wsClient = new WSClient(wsUrl);
            await this.wsClient.connect();
            console.log('连接成功');

            // 构建并发送用户信息请求
            const request = RequestBuilder.buildUserInfoRequest(
                this.root,
                this.loginResponse.token
            );

            this.wsClient.send(request);

            // 等待并处理响应
            const response = await this.wsClient.waitForMessage();
            const userInfoResponse = this.responseHandler.handleUserInfoResponse(response);

            // 关闭连接
            this.wsClient.close();

            return userInfoResponse;
        } catch (error) {
            console.error('获取用户信息失败:', error);
            if (this.wsClient) {
                this.wsClient.close();
            }
            return null;
        }
    }
}

module.exports = UserInfoTest; 