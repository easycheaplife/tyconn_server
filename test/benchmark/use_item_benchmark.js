const Benchmark = require('../lib/benchmark');
const GameClient = require('../lib/game_client');
const LoginClient = require('../lib/login_client');
const config = require('../config/config');

async function useItemBenchmark(options = {}) {
    // 先登录获取token
    const loginClient = new LoginClient();
    const loginResult = await loginClient.login(
        config.testAccount,
        config.testPassword
    );

    // 创建客户端并获取背包信息
    const client = new GameClient(loginResult.gateInfo);
    await client.connect();
    await client.auth(loginResult.token);
    const bagInfo = await client.getBagInfo();

    // 确保有可用的物品
    if (!bagInfo.items || bagInfo.items.length === 0) {
        console.error('No items available for testing');
        return;
    }

    const testItem = bagInfo.items[0];
    const benchmark = new Benchmark({
        concurrent: options.concurrent || 20,
        total: options.total || 100,
        timeout: options.timeout || 3000
    });

    const report = await benchmark.run(async () => {
        await client.useItem(testItem.id, 1);
    });

    // 关闭连接
    await client.close();

    // 打印报告
    console.log('\nUse Item Benchmark Results:');
    console.log('-'.repeat(50));
    console.log(`Item ID: ${testItem.id}`);
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

module.exports = useItemBenchmark; 