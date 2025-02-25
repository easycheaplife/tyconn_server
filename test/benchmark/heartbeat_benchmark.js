const BaseBenchmark = require('./base_benchmark');

class HeartbeatBenchmark extends BaseBenchmark {
    async setup() {
        const loginResult = await super.setup();

        // 发送一次心跳测试
        const heartbeatResponse = await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_HEARTBEAT_REQUEST, {
            token: loginResult.token,
            timestamp: Date.now()
        });
        console.log('Test heartbeat response:', heartbeatResponse);
    }

    async runTest() {
        await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_HEARTBEAT_REQUEST, {
            token: this.client.token,
            timestamp: Date.now()
        });
    }

    getTitle() {
        return 'Heartbeat Benchmark Results';
    }
}

module.exports = (options) => new HeartbeatBenchmark(options).run(); 