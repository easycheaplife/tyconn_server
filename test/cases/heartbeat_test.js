const BaseTest = require('../lib/base_test');

class HeartbeatTest extends BaseTest {
    constructor() {
        super('Heartbeat Test');
    }

    async test() {
        try {
            // 发送心跳
            const response = await this.client.sendHeartbeat();
            console.log('Heartbeat response:', response);

            // 验证心跳响应
            if (!response || !response.timestamp) {
                console.error('Invalid heartbeat response: missing timestamp');
                return false;
            }

            // 验证时间戳是否合理
            const now = Date.now() / 1000; // 转换为秒
            const timestamp = Number(response.timestamp);
            const timeDiff = Math.abs(now - timestamp);

            if (timeDiff > 60) { // 允许60秒的时间差
                console.error(`Timestamp too far from current time. Diff: ${timeDiff}s`);
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