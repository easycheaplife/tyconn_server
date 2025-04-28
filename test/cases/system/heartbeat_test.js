const BaseTest = require('../../lib/base_test');

class HeartbeatTest extends BaseTest {
    constructor() {
        super('Heartbeat Test');
    }

    async test() {
        try {
            // 发送心跳
            const response = await this.client.sendHeartbeat();

            // 验证响应
            if (!response || !response.timestamp) {
                console.error('Invalid heartbeat response: missing timestamp');
                return false;
            }

            return true;
        } catch (error) {
            console.error('Heartbeat test failed:', error);
            return false;
        }
    }
}

module.exports = HeartbeatTest; 