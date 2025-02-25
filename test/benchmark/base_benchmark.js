const Benchmark = require('../lib/benchmark');
const GameClient = require('../lib/game_client');
const LoginClient = require('../lib/login_client');
const config = require('../config/config');

class BaseBenchmark {
    constructor(options = {}) {
        this.options = {
            concurrent: options.concurrent || 200,
            total: options.total || 2000,
            timeout: options.timeout || 1000
        };
    }

    async setup() {
        // 先登录获取token和网关信息
        const loginClient = new LoginClient();
        const loginResult = await loginClient.login(
            config.testAccount,
            config.testPassword
        );

        // 创建一个长连接的客户端
        this.client = new GameClient();
        // 设置认证信息
        this.client.setAuth(loginResult.token, {
            protocol: 'ws',
            host: loginResult.gateInfo.host,
            port: loginResult.gateInfo.port
        });
        
        await this.client.connect();

        // 获取用户信息
        const userInfo = await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_USER_INFO_REQUEST, {
            token: loginResult.token
        });
        console.log('User info:', userInfo);

        return loginResult;
    }

    async teardown() {
        if (this.client) {
            await this.client.close();
        }
    }

    async printReport(report, title = 'Benchmark Results') {
        console.log(`\n${title}:`);
        console.log('-'.repeat(50));
        console.log(`Total Requests: ${report.total}`);
        console.log(`Success: ${report.success}`);
        console.log(`Failed: ${report.failed}`);
        console.log(`Success Rate: ${report.successRate}%`);
        console.log(`Average Time: ${report.avgTime}ms`);
        console.log(`QPS: ${report.qps}`);
        console.log(`P95: ${report.p95}ms`);
        console.log(`P99: ${report.p99}ms`);
        console.log(`Duration: ${(report.duration/1000).toFixed(1)}s`);

        if (Object.keys(report.errors).length > 0) {
            console.log('\nError Distribution:');
            for (const [code, count] of Object.entries(report.errors)) {
                console.log(`- ${code}: ${count}`);
            }
        }
    }

    async run() {
        try {
            await this.setup();
            const benchmark = new Benchmark(this.options);
            const report = await benchmark.run(async () => {
                await this.runTest();
            });
            await this.printReport(report, this.getTitle());
        } finally {
            await this.teardown();
        }
    }

    // 子类需要实现的方法
    async runTest() {
        throw new Error('Subclass must implement runTest method');
    }

    getTitle() {
        return 'Benchmark Results';
    }
}

module.exports = BaseBenchmark; 