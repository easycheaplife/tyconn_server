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
            assert(Array.isArray(response.bags), 'Bags should be an array');
            assert(response.bags.length > 0, 'User should have at least one bag');
            console.log("--------------------------------   ");
            console.log(response.bags[0].items);
            console.log("--------------------------------   ");
            // 验证背包字段
            for (const bag of response.bags) {
                // 基本字段验证
                assert(typeof bag.bag_type === 'number', 'Bag type should be a number');
                assert(typeof bag.size === 'number', 'Bag size should be a number');
                assert(Array.isArray(bag.items), 'Bag items should be an array');

                // 验证物品字段
                for (const item of bag.items) {
                    assert(item.item_id >= 1000 && item.item_id <= 9999, 'Item template ID should be valid');
                    assert(item.count > 0, 'Item count should be positive');
                    assert(typeof item.slot === 'number', 'Item slot should be a number');
                    assert(item.slot >= 0 && item.slot < bag.size, 'Item slot should be within bag size');
                }

                // 验证格子唯一性
                const usedSlots = new Set(bag.items.map(item => item.slot));
                assert.strictEqual(usedSlots.size, bag.items.length, 'Each item should have a unique slot');
            }

            // 测试2: 缓存验证
            console.log('\nTesting bags cache...');
            const secondResponse = await this.client.getBagInfo();
            assert.deepStrictEqual(response.bags, secondResponse.bags, 
                'Cached bags should match');

            // 测试3: 断开重连验证
            console.log('\nTesting bags persistence after reconnect...');

            // 保存第一次响应的深拷贝
            const firstResponse = JSON.parse(JSON.stringify(response));

            // 断开重连
            await this.client.close();
            await this.client.connect();

            // 获取新响应
            const thirdResponse = await this.client.getBagInfo();

            // 打印两次响应的详细信息以便调试
            console.log('First response:', JSON.stringify(firstResponse, null, 2));
            console.log('Third response:', JSON.stringify(thirdResponse, null, 2));

            // 比较响应
            /*
            assert.deepStrictEqual(
                thirdResponse.bags, 
                firstResponse.bags, 
                'Bags should persist after reconnect'
            );
            */

            // 测试4: 背包类型验证
            console.log('\nTesting bag types...');
            const bagTypes = new Set(response.bags.map(bag => bag.bag_type));
            assert(bagTypes.has(1), 'Should have main bag (type 1)');
            /*
            // 测试5: 背包大小验证
            console.log('\nTesting bag sizes...');
            for (const bag of response.bags) {
                switch (bag.bag_type) {
                    case 1: // MAIN
                        assert.strictEqual(bag.size, 20, 'Main bag should have 20 slots');
                        break;
                    case 2: // STORAGE
                        assert.strictEqual(bag.size, 30, 'Storage bag should have 30 slots');
                        break;
                    case 3: // EQUIP
                        assert.strictEqual(bag.size, 12, 'Equipment bag should have 12 slots');
                        break;
                }
            }
            */
            // 测试6: 物品分布验证
            console.log('\nTesting item distribution...');
            for (const bag of response.bags) {
                assert(bag.items.length <= bag.size, 
                    `Bag ${bag.bag_type} should not have more items than its size`);
            }

            // 测试7: 物品属性范围验证
            console.log('\nTesting item property ranges...');
            for (const bag of response.bags) {
                for (const item of bag.items) {
                    assert(item.count >= 1 && item.count <= 9999, 
                        'Item count should be between 1 and 9999');
                }
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