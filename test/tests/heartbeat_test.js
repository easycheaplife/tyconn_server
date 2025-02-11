const WSClient = require('../lib/ws_client');
const ResponseHandler = require('../lib/response_handler');
const RequestBuilder = require('../builders/request_builder');

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

            // 连接服务器
            const wsUrl = `ws://${this.ws_addr}:${this.ws_port}`;
            this.wsClient = new WSClient(wsUrl);
            console.log('正在连接网关服务器:', wsUrl);
            await this.wsClient.connect();
            console.log('连接成功，开始心跳...');

            // 开始心跳
            this.intervalId = setInterval(async () => {
                try {
                    this.heartbeatCount++;
                    console.log(`发送第 ${this.heartbeatCount} 次心跳...`);

                    const request = RequestBuilder.buildHeartbeatRequest(this.root, global.token);
                    this.wsClient.send(request);

                    const response = await this.wsClient.waitForMessage();
                    const result = this.responseHandler.handleHeartbeatResponse(response);

                    if (!result) {
                        console.error('心跳失败');
                        this.stop();
                        return;
                    }

                    if (this.heartbeatCount >= this.MAX_HEARTBEAT) {
                        console.log('心跳测试完成');
                        this.stop();
                    }
                } catch (error) {
                    console.error('心跳发送失败:', error);
                    this.stop();
                }
            }, 5000);

        } catch (error) {
            console.error('心跳测试失败:', error);
            this.stop();
        }
    }

    stop() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
        console.log('关闭心跳连接');
        if (this.wsClient) {
            this.wsClient.close();
        }
    }
}

module.exports = HeartbeatTest; 