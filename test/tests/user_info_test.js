const WSClient = require('../lib/ws_client');
const ResponseHandler = require('../lib/response_handler');
const GetUserInfoBuilder = require('../builders/get_user_info_builder');
const config = require('../config/config');

class UserInfoTest {
    constructor(root, token) {
        this.root = root;
        this.token = token;
        this.wsClient = null;
        this.responseHandler = new ResponseHandler(root);
    }

    async run() {
        try {
            // 使用登录返回的网关地址
            const wsUrl = `ws://${this.token.ws_addr}:${this.token.ws_port}`;
            this.wsClient = new WSClient(wsUrl);

            // 连接服务器
            console.log('正在连接网关服务器:', wsUrl);
            await this.wsClient.connect();
            console.log('连接成功');

            // 发送获取用户信息请求
            console.log('开始获取用户信息...');
            const request = GetUserInfoBuilder.build(this.root, this.token);
            this.wsClient.send(request);

            // 等待并处理响应
            const responseData = await this.wsClient.waitForMessage();
            const response = this.responseHandler.handleUserInfoResponse(responseData);

            if (!response) {
                console.log('获取用户信息失败');
                process.exit(1);
            }

            console.log('获取用户信息成功');
            return response;

        } catch (err) {
            console.error('测试失败:', err);
            process.exit(1);
        } finally {
            if (this.wsClient) {
                this.wsClient.close();
            }
        }
    }
}

module.exports = UserInfoTest; 