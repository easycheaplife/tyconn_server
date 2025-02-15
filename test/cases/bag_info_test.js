const BaseTest = require('../lib/base_test');
const assert = require('assert');

class BagInfoTest extends BaseTest {
    constructor() {
        super('Bag Info Test');
    }

    async test() {
        try {
            // 获取背包信息
            console.log('\nTesting get bag info...');
            const bagInfo = await this.client.getBagInfo();
            
            // 简化输出
            const items = bagInfo.items.map(item => ({
                id: Number(item.id),
                item_id: item.item_id,
                count: item.count,
                create_time: Number(item.create_time),
                update_time: Number(item.update_time)
            }));

            // 验证响应结构
            assert(bagInfo.items, 'Missing items field in response');
            assert(Array.isArray(bagInfo.items), 'Items should be an array');
            assert(bagInfo.items.length > 0, 'New user should have initial items');
            
            // 验证物品数据结构
            for (const item of bagInfo.items) {
                assert(item.id, 'Item should have id');
                assert(item.item_id, 'Item should have item_id');
                assert(typeof item.count === 'number', 'Item should have count');
                assert(item.create_time, 'Item should have create_time');
                assert(item.update_time, 'Item should have update_time');
            }

            return true;
        } catch (error) {
            console.error('Test failed:', error);
            return false;
        }
    }
}

module.exports = BagInfoTest; 