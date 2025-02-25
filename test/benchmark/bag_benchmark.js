const BaseBenchmark = require('./base_benchmark');

class BagBenchmark extends BaseBenchmark {
    async setup() {
        const loginResult = await super.setup();

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

        console.log('Main bag items:', mainBag.items);
    }

    async runTest() {
        await this.client.sendRequest(this.client.protoHelper.MessageID.C2G_BAG_INFO_REQUEST, {
            token: this.client.token
        });
    }

    getTitle() {
        return 'Bag Info Benchmark Results';
    }
}

module.exports = (options) => new BagBenchmark(options).run(); 