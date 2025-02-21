const BaseTest = require('../lib/base_test');
const assert = require('assert');

class UseItemTest extends BaseTest {
    constructor() {
        super('Use Item Test');
    }

    async test() {
        try {
            // 测试1: 获取初始背包信息
            console.log('\nGetting initial bag info...');
            const initialBag = await this.client.getBagInfo();
            assert(initialBag.items.length > 0, 'User should have items to test with');
            
            // 选择第一个物品进行测试
            const testItem = initialBag.items[0];
            const originalCount = testItem.count;
            
            // 测试2: 使用有效数量的物品
            console.log('\nTesting valid item usage...');
            const useCount = Math.min(testItem.count, 1);
            const useResponse = await this.client.useItem(testItem.item_id, useCount);
            
            // 验证使用物品响应
            assert(useResponse, 'Use item response should not be null');
            assert(Array.isArray(useResponse.items), 'Response should contain items array');
            
            // 测试3: 验证物品数量更新
            console.log('\nVerifying item count update...');
            const updatedBag = await this.client.getBagInfo();
            const updatedItem = updatedBag.items.find(item => item.id.low === testItem.id.low);
            assert(updatedItem, 'Item should still exist after partial use');
            assert.strictEqual(updatedItem.count, originalCount - useCount, 
                'Item count should be reduced by used amount');
            
            // 测试4: 使用无效数量的物品
            console.log('\nTesting invalid item usage...');
            try {
                await this.client.useItem(testItem.item_id, -1);
                assert.fail('Should not allow negative usage count');
            } catch (error) {
                // 添加调试信息
                console.log('Error details:', {
                    message: error.message,
                    response: error.response,
                    errorCode: error.response ? error.response.errorCode : undefined,
                    errorMsg: error.response ? error.response.errorMsg : undefined,
                    expectedErrorCode: 2  // ERROR_CODE_INVALID_PARAM
                });

                assert(error.response, 'Should have error response');
                assert.strictEqual(
                    error.response.errorCode,
                    2,  // ERROR_CODE_INVALID_PARAM
                    'Should have invalid params error code'
                );
                assert.strictEqual(
                    error.response.errorMsg,
                    'Invalid count',
                    'Should have invalid count error message'
                );
            }
            
            // 测试5: 使用不存在的物品
            console.log('\nTesting non-existent item usage...');
            try {
                await this.client.useItem(999999, 1);
                assert.fail('Should not allow using non-existent item');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    13,  // ERROR_CODE_ITEM_NOT_FOUND
                    'Should have item not found error code'
                );
            }
            
            // 测试6: 使用超过拥有数量的物品
            console.log('\nTesting excessive item usage...');
            try {
                await this.client.useItem(testItem.item_id, testItem.count + 1);
                assert.fail('Should not allow using more items than owned');
            } catch (error) {
                // 添加调试信息
                console.log('Error details:', {
                    message: error.message,
                    response: error.response,
                    errorCode: error.response ? error.response.errorCode : undefined,
                    errorMsg: error.response ? error.response.errorMsg : undefined,
                    expectedErrorCode: 14  // ERROR_CODE_ITEM_NOT_ENOUGH
                });

                assert.strictEqual(
                    error.response.errorCode,
                    14,  // ERROR_CODE_ITEM_NOT_ENOUGH
                    'Should have item not enough error code'
                );
            }
            
            // 测试7: 验证更新时间
            console.log('\nVerifying update time...');
            const finalBag = await this.client.getBagInfo();
            const finalItem = finalBag.items.find(item => item.id.low === testItem.id.low);
            assert(finalItem.update_time.low > testItem.update_time.low,
                'Update time should be increased after usage');

            return true;
        } catch (error) {
            console.error('Use item test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = UseItemTest; 