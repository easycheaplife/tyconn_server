const BaseTest = require('../lib/base_test');
const assert = require('assert');

class UseItemTest extends BaseTest {
    constructor() {
        super('Use Item Test');
    }

    async test() {
        try {
            // 1. 获取背包信息
            let bagInfo = await this.client.getBagInfo();
            assert(bagInfo, "Failed to get bag info");
            
            // 2. 找到要使用的物品
            let targetItem = null;
            for (let bag of bagInfo.bags) {
                for (let item of bag.items) {
                    if (item.item_id === 1001) {  // 修改为使用经验道具
                        targetItem = item;
                        break;
                    }
                }
            }
            assert(targetItem, "Target item not found");
            
            // 3. 使用部分物品
            let useCount = 1;
            let originalCount = targetItem.count;
            let ok = await this.client.useItem(targetItem.item_id, useCount);
            assert(ok, "Failed to use item");
            
            // 4. 验证物品数量
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
            
            // 测试5: 使用无效数量的物品
            console.log('\nTesting invalid item usage...');
            try {
                await this.client.useItem(targetItem.item_id, -1);
                assert.fail('Should not allow negative usage count');
            } catch (error) {
                // 添加调试信息
                console.log('Error details:', {
                    message: error.message,
                    response: error.response,
                    errorCode: error.response ? error.response.errorCode : undefined,
                    errorMsg: error.response ? error.response.errorMsg : undefined,
                    expectedErrorCode: this.client.protoHelper.ErrorCode.ERROR_CODE_INVALID_PARAM  // ERROR_CODE_INVALID_PARAM
                });

                assert(error.response, 'Should have error response');
                assert.strictEqual(
                    error.response.errorCode,
                    this.client.protoHelper.ErrorCode.ERROR_CODE_INVALID_PARAM,  // ERROR_CODE_INVALID_PARAM
                    'Should have invalid params error code'
                );
                assert.strictEqual(
                    error.response.errorMsg,
                    'Invalid count',
                    'Should have invalid count error message'
                );
            }
            
            // 测试6: 使用不存在的物品
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
            
            // 测试7: 使用超过拥有数量的物品
            console.log('\nTesting excessive item usage...');
            try {
                await this.client.useItem(targetItem.item_id, targetItem.count + 1);
                assert.fail('Should not allow using more items than owned');
            } catch (error) {
                // 添加调试信息
                console.log('Error details:', {
                    message: error.message,
                    response: error.response,
                    errorCode: error.response ? error.response.errorCode : undefined,
                    errorMsg: error.response ? error.response.errorMsg : undefined,
                    expectedErrorCode: this.client.protoHelper.ErrorCode.ERROR_CODE_ITEM_NOT_ENOUGH  // ERROR_CODE_ITEM_NOT_ENOUGH
                });

                assert.strictEqual(
                    error.response.errorCode,
                    this.client.protoHelper.ErrorCode.ERROR_CODE_ITEM_NOT_ENOUGH,
                    'Should have item not enough error code'
                );
            }
            /*
            // 测试7: 验证更新时间
            console.log('\nVerifying update time...');
            const finalBagInfo = await this.client.getBagInfo();
            const finalMainBag = finalBagInfo.bags.find(bag => bag.bag_type === 1);
            const finalItem = finalMainBag.items.find(item => item.item_id === testItem.item_id);
            console.log('---------------------------------Final item:', finalItem);
            console.log('---------------------------------Test item:', testItem);
            assert(finalItem.update_time > testItem.update_time,
                'Update time should be increased after usage');
            */
            return true;
        } catch (error) {
            console.error('Use item test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = UseItemTest; 