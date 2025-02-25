const BaseBenchmark = require('./base_benchmark');
const GameClient = require('../lib/game_client');
const LoginClient = require('../lib/login_client');
const config = require('../config/config');

class UseItemBenchmark extends BaseBenchmark {
    async setup() {
        const loginResult = await super.setup();

        // 先使用GM命令添加测试物品
        await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_GM_COMMAND_REQUEST, {
            token: loginResult.token,
            command: "add_item",
            params: ["1001", "10"]  // 参数列表：物品ID和数量
        });

        // 获取背包信息
        const bagResponse = await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_BAG_INFO_REQUEST, {
            token: loginResult.token
        });
        
        console.log('Raw bag response:', bagResponse);

        // 解码背包信息响应
        const bagInfo = this.client.decodeResponse(bagResponse, 'command.G2CBagInfoResponse');
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
        this.testItem = mainBag.items[0];
        console.log(`Testing with item ID: ${this.testItem.item_id}`);
    }

    async runTest() {
        await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_USE_ITEM_REQUEST, {
            token: this.client.token,
            item_id: this.testItem.item_id,
            count: 1
        });
    }

    async printReport(report) {
        await super.printReport(report, 'Use Item Benchmark Results');
        // 添加物品ID信息到报告中
        if (this.testItem) {
            console.log(`Item ID: ${this.testItem.item_id}`);
        }
    }

    getTitle() {
        return 'Use Item Benchmark Results';
    }
}

module.exports = (options) => new UseItemBenchmark(options).run(); 