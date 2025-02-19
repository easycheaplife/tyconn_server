const Benchmark = require('../lib/benchmark');
const GameClient = require('../lib/game_client');
const LoginClient = require('../lib/login_client');
const config = require('../config/config');

async function bagBenchmark(options = {}) {
    // 先登录获取token
    const loginClient = new LoginClient();
    const loginResult = await loginClient.login(
        config.testAccount,
        config.testPassword
    );

    const benchmark = new Benchmark({
        concurrent: options.concurrent || 50,
        total: options.total || 500,
        timeout: options.timeout || 3000
    });

    const report = await benchmark.run(async () => {
        const client = new GameClient(loginResult.gateInfo);
        await client.connect();
        await client.auth(loginResult.token);
        await client.getBagInfo();
        await client.close();
    });

    // 打印报告
    console.log('\nBag Info Benchmark Results:');
    console.log('-'.repeat(50));
    console.log(`Total Requests: ${report.total}`);
    console.log(`Success: ${report.success}`);
    console.log(`Failed: ${report.failed}`);
    console.log(`Success Rate: ${report.successRate}%`);
    console.log(`Average Time: ${report.avgTime}ms`);
    console.log(`QPS: ${report.qps}`);
    console.log(`Duration: ${(report.duration/1000).toFixed(1)}s`);

    if (Object.keys(report.errors).length > 0) {
        console.log('\nError Distribution:');
        for (const [code, count] of Object.entries(report.errors)) {
            console.log(`- ${code}: ${count}`);
        }
    }
}

module.exports = bagBenchmark; 