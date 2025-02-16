const BaseTest = require('../lib/base_test');
const assert = require('assert');

class UseItemTest extends BaseTest {
    constructor() {
        super('Use Item Test');
    }

    async test() {
        try {
            // 1. 先获取背包信息
            console.log('\nGetting bag info...');
            const bagInfo = await this.client.getBagInfo();
            
            // 打印完整的响应内容以便调试
            console.log('Bag info response:', JSON.stringify(bagInfo, null, 2));

            // 验证背包信息
            assert(bagInfo.items, 'Missing items in bag');
            assert(Array.isArray(bagInfo.items), 'Items should be an array');
            
            // 找到要使用的物品
            const itemId = 1001;  // 初级经验药水
            const itemToUse = bagInfo.items.find(item => item.item_id === itemId);
            if (!itemToUse) {
                console.error('Item not found in bag:', itemId);
                return false;
            }

            console.log('Found item in bag:', itemToUse);
            
            // 2. 使用物品
            console.log('\nTesting use item...');
            const count = 1;
            console.log('Using item:', {
                item_id: itemId,
                count: count,
                current_count: itemToUse.count
            });

            // 确保物品数量足够
            assert(itemToUse.count >= count, 'Not enough items');

            const useResult = await this.client.useItem(itemId, count);
            if (useResult.error_code !== 0) {
                console.error('Use item failed:', useResult);
                return false;
            }

            // 验证响应结构
            assert(useResult.items, 'Missing items in response');
            assert(Array.isArray(useResult.items), 'Items should be an array');
            
            // 验证使用的物品
            const usedItem = useResult.items.find(item => item.item_id === itemId);
            assert(usedItem, 'Used item not found in response');
            assert(typeof usedItem.count === 'number', 'Invalid count type');
            assert(usedItem.count >= 0, 'Invalid count value');
            assert(usedItem.count === itemToUse.count - count, 'Incorrect remaining count');

            return true;
        } catch (error) {
            console.error('Test failed:', error);
            return false;
        }
    }
}

module.exports = UseItemTest; 