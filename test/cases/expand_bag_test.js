const BaseTest = require('../lib/base_test');
const assert = require('assert');

class ExpandBagTest extends BaseTest {
    constructor() {
        super('Expand Bag Test');
    }

    async test() {
        try {
            // 测试1: 获取背包信息
            console.log('\nTesting get bag info...');
            const response = await this.client.getBagInfo();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(Array.isArray(response.items), 'Items should be an array');
            const initialSize = response.size;
            console.log('initialSize', initialSize);
            // 测试2: 扩展背包
            console.log('\nTesting expand bag...');
            const expandResponse = await this.client.expandBag({
                add_size: 5   // bag_type会在client中设置为BAG_TYPE_MAIN
            });

            // 验证扩展响应
            assert(expandResponse, 'Expand response should not be null');
            assert(expandResponse.code === 0, 'Response code should be success');
            assert(expandResponse.bag_type === 1, 'Bag type should match');
            assert(expandResponse.new_size === initialSize + 5, 'New size should be correct');
            assert(Array.isArray(expandResponse.items), 'Items should be an array');

            // 测试3: 验证物品列表
            for (const item of expandResponse.items) {
                assert(item.id && typeof item.id.low === 'number', 'Item ID should be a Long');
                assert(item.item_id >= 1000 && item.item_id <= 9999, 'Item template ID should be valid');
                assert(item.count > 0, 'Item count should be positive');
                assert(item.create_time && typeof item.create_time.low === 'number', 'Create time should be a Long');
                assert(item.update_time && typeof item.update_time.low === 'number', 'Update time should be a Long');
            }

            // 测试4: 验证缓存
            console.log('\nTesting cache validation...');
            const bagInfoResponse = await this.client.getBagInfo();
            assert.strictEqual(bagInfoResponse.size, expandResponse.new_size, 
                'Cached bag size should match');
            assert.deepStrictEqual(bagInfoResponse.items, expandResponse.items, 
                'Cached items should match');

            // 测试5: 验证错误情况
            console.log('\nTesting error cases...');
            
            // 5.1: 无效的扩展大小
            try {
                await this.client.expandBag({
                    add_size: 0
                });
                assert.fail('Should throw error for invalid size');
            } catch (error) {
                assert(error.errorCode === this.client.protoHelper.ErrorCode.ERROR_CODE_INVALID_PARAM,
                    'Should get invalid param error');
            }

            // 5.2: 超过最大容量
            try {
                await this.client.expandBag({
                    add_size: 1000
                });
                assert.fail('Should throw error for exceeding max size');
            } catch (error) {
                assert(error.errorCode === this.client.protoHelper.ErrorCode.ERROR_CODE_BAG_MAX_SIZE_LIMIT,
                    'Should get max size limit error');
            }

            // 5.3: 无效的背包类型
            try {
                await this.client.expandBag({
                    bag_type: 999,  // 使用无效的背包类型
                    add_size: 5
                });
                assert.fail('Should throw error for invalid bag type');
            } catch (error) {
                console.log('Expected error:', {
                    code: error.errorCode,
                    name: error.errorName,
                    message: error.message
                });
                assert(error.errorCode === this.client.protoHelper.ErrorCode.ERROR_CODE_INVALID_BAG_TYPE,
                    `Should get invalid bag type error, got: ${error.errorName}`);
            }

            return true;
        } catch (error) {
            console.error('Expand bag test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = ExpandBagTest; 