const WSClient = require('../lib/ws_client');
const ResponseHandler = require('../lib/response_handler');
const HeartbeatBuilder = require('../builders/heartbeat_builder');
const config = require('../config/config');

class HeartbeatTest {
    constructor(root, ws_addr, ws_port) {
        this.root = root;
        this.ws_addr = ws_addr;
        this.ws_port = ws_port;
        this.wsClient = null;
        this.responseHandler = new ResponseHandler(root);
        this.intervalId = null;
        this.heartbeatCount = 0;
        this.MAX_HEARTBEAT = 3;
    }

    async start() {
        try {
            // 检查token是否存在
            if (!global.token) {
                throw new Error('No token available');
            }

            // 使用构造时传入的网关地址
            const wsUrl = `ws://${this.ws_addr}:${this.ws_port}`;
            this.wsClient = new WSClient(wsUrl);

            console.log('正在连接网关服务器:', wsUrl);
            await this.wsClient.connect();
            console.log('连接成功，开始心跳...');

            this.intervalId = setInterval(async () => {
                try {
                    this.heartbeatCount++;
                    if (this.heartbeatCount > this.MAX_HEARTBEAT) {
                        this.stop();
                        return;
                    }

                    console.log(`发送第 ${this.heartbeatCount} 次心跳...`);
                    const request = HeartbeatBuilder.build(this.root);
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
            }, 5000);

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

        if (this.heartbeatCount >= this.MAX_HEARTBEAT) {
            console.log('心跳测试完成');
            process.exit(0);
        }
    }
}

module.exports = HeartbeatTest; 