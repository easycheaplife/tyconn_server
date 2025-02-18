const BaseTest = require('../lib/base_test');
const assert = require('assert');

class BagInfoTest extends BaseTest {
    constructor() {
        super('Bag Info Test');
    }

    async test() {
        try {
            // 测试1: 获取背包信息
            console.log('\nTesting get bag info...');
            const response = await this.client.getBagInfo();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(Array.isArray(response.items), 'Items should be an array');
            assert(response.items.length > 0, 'User should have at least one item');

            // 验证物品字段
            for (const item of response.items) {
                // 基本字段验证
                assert(item.id && typeof item.id.low === 'number', 'Item ID should be a Long');
                assert(item.item_id >= 1000 && item.item_id <= 9999, 'Item template ID should be valid');
                assert(item.count > 0, 'Item count should be positive');
                assert(item.create_time && typeof item.create_time.low === 'number', 'Create time should be a Long');
                assert(item.update_time && typeof item.update_time.low === 'number', 'Update time should be a Long');
            }

            // 测试2: 缓存验证
            console.log('\nTesting items cache...');
            const secondResponse = await this.client.getBagInfo();
            assert.deepStrictEqual(response.items, secondResponse.items, 
                'Cached items should match');

            // 测试3: 断开重连验证
            console.log('\nTesting items persistence after reconnect...');
            await this.client.close();
            await this.client.connect();
            const thirdResponse = await this.client.getBagInfo();
            assert.deepStrictEqual(response.items, thirdResponse.items, 
                'Items should persist after reconnect');

            // 测试4: 物品唯一性验证
            console.log('\nTesting item uniqueness...');
            const itemIds = new Set(response.items.map(item => item.id.low));
            assert.strictEqual(itemIds.size, response.items.length, 
                'Each item should have a unique ID');

            // 测试5: 物品数量限制
            console.log('\nTesting item count limits...');
            assert(response.items.length <= 100, 'User should not have more than 100 items');

            // 测试6: 物品模板分布
            console.log('\nTesting item template distribution...');
            const templateIds = new Set(response.items.map(item => item.item_id));
            assert(templateIds.size > 0, 'Should have items from different templates');

            // 测试7: 物品属性范围验证
            console.log('\nTesting item property ranges...');
            for (const item of response.items) {
                // 数量范围
                assert(item.count >= 1 && item.count <= 9999, 
                    'Item count should be between 1 and 9999');
                
                // 时间验证
                assert(item.create_time.low <= item.update_time.low, 
                    'Create time should not be later than update time');
                
                // 当前时间验证
                const now = Date.now() / 1000;
                assert(item.create_time.low <= now, 
                    'Create time should not be in the future');
                assert(item.update_time.low <= now, 
                    'Update time should not be in the future');
            }

            return true;
        } catch (error) {
            console.error('Bag info test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = BagInfoTest; 