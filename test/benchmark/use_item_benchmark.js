const Benchmark = require('../lib/benchmark');
const GameClient = require('../lib/game_client');
const LoginClient = require('../lib/login_client');
const config = require('../config/config');

async function useItemBenchmark(options = {}) {
    // 先登录获取token和网关信息
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
    const client = new GameClient();
    // 设置认证信息
    client.setAuth(loginResult.token, {
        protocol: 'ws',
        host: loginResult.gateInfo.host,
        port: loginResult.gateInfo.port
    });
    
    await client.connect();

    // 获取用户信息
    const userInfo = await client.sendRequest(client.protoHelper.MessageID.C2G_USER_INFO_REQUEST, {
        token: loginResult.token
    });
    console.log('User info:', userInfo);

    // 先使用GM命令添加测试物品
    await client.sendRequest(client.protoHelper.MessageID.C2G_GM_COMMAND_REQUEST, {
        token: loginResult.token,
        command: "add_item",
        params: ["1001", "10"]  // 参数列表：物品ID和数量
    });

    // 获取背包信息
    const bagResponse = await client.sendRequest(client.protoHelper.MessageID.C2G_BAG_INFO_REQUEST, {
        token: loginResult.token
    });
    
    console.log('Raw bag response:', bagResponse);

    // 解码背包信息响应
    const bagInfo = client.decodeResponse(bagResponse, 'command.G2CBagInfoResponse');
    console.log('Decoded bag info:', bagInfo);

    // 检查背包列表
    if (!bagInfo.bags || bagInfo.bags.length === 0) {
        console.error('No bags available');
        return;
    }

    // 找到主背包 - 直接使用数字 1 表示主背包
    const mainBag = bagInfo.bags.find(bag => bag.bag_type === 1);  // BAG_TYPE_MAIN = 1
    if (!mainBag || !mainBag.items || mainBag.items.length === 0) {
        console.error('No items in main bag');
        return;
    }

    console.log('Main bag items:', mainBag.items);  // 添加日志
    const testItem = mainBag.items[0];
    console.log(`Testing with item ID: ${testItem.item_id}`);  // 使用 item_id 而不是 id

    const report = await benchmark.run(async () => {
        await client.sendRequest(client.protoHelper.MessageID.C2G_USE_ITEM_REQUEST, {
            token: loginResult.token,
            item_id: testItem.item_id,  // 使用 item_id 而不是 itemId
            count: 1
        });
    });

    // 关闭连接
    await client.close();

    // 打印报告
    console.log('\nUse Item Benchmark Results:');
    console.log('-'.repeat(50));
    console.log(`Item ID: ${testItem.item_id}`);
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

module.exports = useItemBenchmark; 