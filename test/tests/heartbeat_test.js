const WSClient = require('../lib/ws_client');
const ResponseHandler = require('../lib/response_handler');
const HeartbeatBuilder = require('../builders/heartbeat_builder');
const config = require('../config/config');

class HeartbeatTest {
    constructor(root, loginResponse) {
        this.root = root;
        this.loginResponse = loginResponse;  // 保存完整的登录响应
        this.wsClient = null;
        this.responseHandler = new ResponseHandler(root);
        this.intervalId = null;
        this.heartbeatCount = 0;  // 心跳计数
        this.MAX_HEARTBEAT = 3;   // 最大心跳次数
    }

    async start() {
        try {
            // 使用登录返回的网关地址
            const wsUrl = `ws://${this.loginResponse.ws_addr}:${this.loginResponse.ws_port}`;
            this.wsClient = new WSClient(wsUrl);

            // 连接服务器
            console.log('正在连接网关服务器:', wsUrl);
            await this.wsClient.connect();
            console.log('连接成功，开始心跳...');

            // 启动心跳
            this.intervalId = setInterval(async () => {
                try {
                    this.heartbeatCount++;
                    if (this.heartbeatCount > this.MAX_HEARTBEAT) {
                        this.stop();
                        return;
                    }

                    console.log(`发送第 ${this.heartbeatCount} 次心跳...`);
                    const request = HeartbeatBuilder.build(this.root, this.loginResponse);
                    this.wsClient.send(request);

                    const responseData = await this.wsClient.waitForMessage();
                    const response = this.responseHandler.handleHeartbeatResponse(responseData);

                    if (!response) {
                        console.log('心跳失败');
                        this.stop();
                    }
                } catch (err) {
                    console.error('心跳错误:', err);
                    this.stop();
                }
            }, 5000); // 5秒一次心跳，加快测试速度

        } catch (err) {
            console.error('测试失败:', err);
            this.stop();
        }
    }

    stop() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
        console.log('关闭心跳连接');
        this.wsClient.close();

        // 如果是正常完成所有心跳，退出程序
        if (this.heartbeatCount >= this.MAX_HEARTBEAT) {
            console.log('心跳测试完成');
            process.exit(0);
        }
    }
}

module.exports = HeartbeatTest; 