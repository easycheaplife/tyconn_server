const Benchmark = require('../lib/benchmark');
const GameClient = require('../lib/game_client');
const LoginClient = require('../lib/login_client');
const config = require('../config/config');

async function heartbeatBenchmark(options = {}) {
    // 先登录获取token
    const loginClient = new LoginClient();
    const loginResult = await loginClient.login(
        config.testAccount,
        config.testPassword
    );

    const benchmark = new Benchmark({
        concurrent: options.concurrent || 200,
        total: options.total || 2000,
        timeout: options.timeout || 1000
    });

    // 创建一个长连接的客户端
    const client = new GameClient(loginResult.gateInfo);
    await client.connect();
    await client.auth(loginResult.token);

    const report = await benchmark.run(async () => {
        await client.heartbeat();
    });

    // 关闭连接
    await client.close();

    // 打印报告
    console.log('\nHeartbeat Benchmark Results:');
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

module.exports = heartbeatBenchmark; 