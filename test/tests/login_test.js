const WSClient = require('../lib/ws_client');
const ResponseHandler = require('../lib/response_handler');
const LoginRequestBuilder = require('../builders/login_request_builder');
const config = require('../config/config');

class LoginTest {
    constructor(root) {
        this.root = root;
        this.wsClient = new WSClient(config.loginServer);
        this.responseHandler = new ResponseHandler(root);
    }

    async run() {
        try {
            // 连接服务器
            console.log('正在连接登录服务器:', config.loginServer);
            await this.wsClient.connect();
            console.log('连接登录服务器成功');

            // 发送登录请求
            console.log('开始登录测试...');
            const loginRequest = LoginRequestBuilder.build(
                this.root, 
                config.account, 
                config.password
            );
            
            this.wsClient.send(loginRequest);

            // 等待并处理响应
            const responseData = await this.wsClient.waitForMessage();
            const loginResponse = this.responseHandler.handleLoginResponse(responseData);

            if (!loginResponse || !loginResponse.token) {
                console.log('登录失败，终止测试');
                process.exit(1);
            }

            console.log('登录成功');
            return loginResponse;

        } catch (err) {
            console.error('测试失败:', err);
            process.exit(1);
        } finally {
            this.wsClient.close();
        }
    }
}

module.exports = LoginTest; 