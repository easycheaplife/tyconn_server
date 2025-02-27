const BaseTest = require('../lib/base_test');
const assert = require('assert');

class UseItemTest extends BaseTest {
    constructor() {
        super('Use Item Test');
    }

    async test() {
        try {
            // 1. 使用GM指令添加测试物品
            console.log('\nAdding test items via GM command...');
            let gmResult = await this.client.gmCommand('add_item', ['2012', '10']); // 添加10个金币道具
            assert(gmResult, "Failed to add test items");

            // 2. 获取背包信息
            let bagInfo = await this.client.getBagInfo();
            assert(bagInfo, "Failed to get bag info");
            
            // 3. 找到要使用的物品
            let targetItem = null;
            for (let bag of bagInfo.bags) {
                for (let item of bag.items) {
                    if (item.item_id === 2012) {  // 使用金币道具
                        targetItem = item;
                        break;
                    }
                }
            }
            assert(targetItem, "Target item not found");
            
            // 4. 使用部分物品
            let useCount = 1;
            let originalCount = targetItem.count;
            let ok = await this.client.useItem(targetItem.item_id, useCount);
            assert(ok, "Failed to use item");
            
            // 5. 验证物品数量
            bagInfo = await this.client.getBagInfo();
            let itemExists = false;
            let newCount = 0;
            
            for (let bag of bagInfo.bags) {
                for (let item of bag.items) {
                    if (item.item_id === targetItem.item_id) {
                        itemExists = true;
                        newCount = item.count;
                        break;
                    }
                }
            }
            
            // 如果使用后数量大于0，物品应该还存在
            if (originalCount > useCount) {
                assert(itemExists, "Item should still exist after partial use");
                assert(newCount === originalCount - useCount, 
                    `Item count should be ${originalCount - useCount} but got ${newCount}`);
            } else {
                // 如果使用后数量为0，物品应该被删除
                assert(!itemExists, "Item should be removed after complete use");
            }
            
            // 测试6: 使用无效数量的物品
            console.log('\nTesting invalid item usage...');
            try {
                await this.client.useItem(targetItem.item_id, -1);
                assert.fail('Should not allow negative usage count');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    this.client.protoHelper.ErrorCode.ERROR_CODE_INVALID_PARAM,
                    'Should have invalid params error code'
                );
            }
            
            // 测试7: 使用不存在的物品
            console.log('\nTesting non-existent item usage...');
            try {
                await this.client.useItem(999999, 1);
                assert.fail('Should not allow using non-existent item');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    this.client.protoHelper.ErrorCode.ERROR_CODE_ITEM_NOT_FOUND,
                    'Should have item not found error code'
                );
            }
            
            // 测试8: 使用超过拥有数量的物品
            console.log('\nTesting excessive item usage...');
            try {
                await this.client.useItem(targetItem.item_id, targetItem.count + 1);
                assert.fail('Should not allow using more items than owned');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    this.client.protoHelper.ErrorCode.ERROR_CODE_ITEM_NOT_ENOUGH,
                    'Should have item not enough error code'
                );
            }

            return true;
        } catch (error) {
            console.error('Use item test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = UseItemTest; 