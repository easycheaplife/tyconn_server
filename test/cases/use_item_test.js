const BaseTest = require('../lib/base_test');
const assert = require('assert');

class UseItemTest extends BaseTest {
    constructor() {
        super('Use Item Test');
    }

    async test() {
        try {
            // 1. 获取背包信息
            console.log('\nGetting bag info...');
            const bagInfo = await this.client.getBagInfo();
            assert(bagInfo.items && bagInfo.items.length > 0, 'No items in bag');

            // 2. 使用物品
            const item = bagInfo.items[0];
            console.log('\nUsing item:', {
                item_id: item.item_id,
                count: item.count
            });

            const useResult = await this.client.useItem(item.item_id, 1);
            assert(useResult.item, 'No item in use result');
            assert(useResult.item.item_id === item.item_id, 'Item ID mismatch');
            assert(useResult.item.count === item.count - 1, 'Item count not reduced');

            // 3. 验证物品数量
            const newBagInfo = await this.client.getBagInfo();
            if (item.count > 1) {
                // 如果物品数量大于1，应该还存在
                const updatedItem = newBagInfo.items.find(i => i.item_id === item.item_id);
                assert(updatedItem, 'Item should still exist');
                assert(updatedItem.count === item.count - 1, 'Item count should be reduced by 1');
            } else {
                // 如果物品数量为1，使用后应该被删除
                const updatedItem = newBagInfo.items.find(i => i.item_id === item.item_id);
                assert(!updatedItem, 'Item should be removed when count is 0');
            }

            return true;
        } catch (error) {
            console.error('Test failed:', error);
            return false;
        }
    }
}

module.exports = UseItemTest; 