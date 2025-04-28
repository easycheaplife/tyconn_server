const BaseBenchmark = require('./base_benchmark');

class StackItemBenchmark extends BaseBenchmark {
    async setup() {
        const loginResult = await super.setup();

        // 先使用GM命令添加大量的同一物品，测试自动堆叠
        await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_GM_COMMAND_REQUEST, {
            token: loginResult.token,
            command: "add_item",
            params: ["1001", "2000"]  // 添加大量物品，超过堆叠上限
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

        // 找到主背包
        const mainBag = bagInfo.bags.find(bag => bag.bag_type === 1);
        if (!mainBag || !mainBag.items || mainBag.items.length === 0) {
            console.error('No items in main bag');
            return;
        }

        // 找到所有相同ID的物品
        const sameItems = mainBag.items.filter(item => item.item_id === 1001);
        console.log('Found items with same ID:', sameItems);

        // 分析堆叠情况
        console.log('\nStack Analysis:');
        console.log('-'.repeat(50));
        console.log(`Total stacks: ${sameItems.length}`);
        sameItems.forEach((item, index) => {
            console.log(`Stack ${index + 1}: Slot ${item.slot}, Count ${item.count}`);
        });

        // 计算总数
        const totalCount = sameItems.reduce((sum, item) => sum + item.count, 0);
        console.log(`Total items: ${totalCount}`);
    }

    async runTest() {
        // 只测试获取背包信息
        await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_BAG_INFO_REQUEST, {
            token: this.client.token
        });
    }

    getTitle() {
        return 'Stack Item Test Results';
    }
}

module.exports = (options) => new StackItemBenchmark(options).run(); 