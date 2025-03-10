const BaseTest = require('../lib/base_test');
const assert = require('assert');

class UseItemTest extends BaseTest {
    constructor() {
        super('Use Item Test');
    }

    async test() {
        try {
            await this.client.gmCommand('clear_bag', ['1']) // 清空主背包

            // 测试经验道具
            console.log('\nTesting EXP item usage...');
            await this.testExpItem();

            // 测试金币道具
            console.log('\nTesting GOLD item usage...');
            await this.testGoldItem();

            return true;
        } catch (error) {
            console.error('Use item test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }

    async testExpItem() {
        try {
            // 1. 添加经验道具
            console.log('Adding EXP items...');
            let gmResult = await this.client.gmCommand('add_item', ['2011', '5']); // 添加5个经验道具
            assert(gmResult, "Failed to add exp items");

            // 2. 获取背包信息
            console.log('Getting bag info...');
            let bagInfo = await this.client.getBagInfo();
            assert(bagInfo, "Failed to get bag info");
            console.log('Current bag info:', JSON.stringify(bagInfo, null, 2));
            
            // 3. 找到经验道具
            let expItem = null;
            let originalBag = null;
            for (let bag of bagInfo.bags) {
                for (let item of bag.items) {
                    if (item.item_id === 2011) {
                        expItem = item;
                        originalBag = bag;
                        break;
                    }
                }
                if (expItem) break;
            }
            assert(expItem, "EXP item not found");
            console.log('Found EXP item:', JSON.stringify(expItem, null, 2));

            // 4. 使用经验道具
            let useCount = 1;
            let originalCount = expItem.count;
            console.log(`Using EXP item (ID: ${expItem.item_id}, Count: ${useCount})...`);
            
            // 构建使用物品请求
            const useRequest = {
                token: this.client.token,
                item_id: expItem.item_id,
                count: useCount,
                bag_type: originalBag.bag_type,
                slot: expItem.slot
            };
            console.log('Use item request:', JSON.stringify(useRequest, null, 2));
            
            let useResult = await this.client.useItem(useRequest.item_id, useRequest.count);
            assert(useResult, "Failed to use exp item");
            assert(useResult.bags, "Response should contain bags array");
            console.log('Use item response:', JSON.stringify(useResult, null, 2));

            // 5. 验证物品数量变化
            let itemFound = false;
            let newCount = 0;
            for (let bag of useResult.bags) {
                if (bag.bag_type === originalBag.bag_type) {
                    for (let item of bag.items) {
                        if (item.item_id === expItem.item_id) {
                            itemFound = true;
                            newCount = item.count;
                            break;
                        }
                    }
                }
            }
            assert(itemFound, "EXP item should still exist after use");
            assert(newCount === originalCount - useCount, 
                `EXP item count should be ${originalCount - useCount} but got ${newCount}`);
            
        } catch (error) {
            console.error('Test EXP item failed:', error);
            if (error.details) {
                console.error('Error details:', JSON.stringify(error.details, null, 2));
            }
            throw error;
        }
    }

    async testGoldItem() {
        try {
            // 1. 添加金币道具
            console.log('Adding GOLD items...');
            let gmResult = await this.client.gmCommand('add_item', ['2012', '5']); // 添加5个金币道具
            assert(gmResult, "Failed to add gold items");

            // 2. 获取背包信息
            console.log('Getting bag info...');
            let bagInfo = await this.client.getBagInfo();
            assert(bagInfo, "Failed to get bag info");
            console.log('Current bag info:', JSON.stringify(bagInfo, null, 2));
            
            // 3. 找到金币道具
            let goldItem = null;
            let originalBag = null;
            for (let bag of bagInfo.bags) {
                for (let item of bag.items) {
                    if (item.item_id === 2012) {
                        goldItem = item;
                        originalBag = bag;
                        break;
                    }
                }
                if (goldItem) break;
            }
            assert(goldItem, "Gold item not found");
            console.log('Found GOLD item:', JSON.stringify(goldItem, null, 2));

            // 4. 使用金币道具
            let useCount = 1;
            let originalCount = goldItem.count;
            console.log(`Using GOLD item (ID: ${goldItem.item_id}, Count: ${useCount})...`);
            
            // 构建使用物品请求
            const useRequest = {
                token: this.client.token,
                item_id: goldItem.item_id,
                count: useCount,
                bag_type: originalBag.bag_type,
                slot: goldItem.slot
            };
            console.log('Use item request:', JSON.stringify(useRequest, null, 2));
            
            let useResult = await this.client.useItem(useRequest.item_id, useRequest.count);
            assert(useResult, "Failed to use gold item");
            assert(useResult.bags, "Response should contain bags array");
            console.log('Use item response:', JSON.stringify(useResult, null, 2));

            // 5. 验证物品数量变化
            let itemFound = false;
            let newCount = 0;
            for (let bag of useResult.bags) {
                if (bag.bag_type === originalBag.bag_type) {
                    for (let item of bag.items) {
                        if (item.item_id === goldItem.item_id) {
                            itemFound = true;
                            newCount = item.count;
                            break;
                        }
                    }
                }
            }
            assert(itemFound, "Gold item should still exist after use");
            assert(newCount === originalCount - useCount, 
                `Gold item count should be ${originalCount - useCount} but got ${newCount}`);

            // 6. 错误测试用例
            console.log('\nTesting error cases...');
            
            // 6.1 使用无效数量
            try {
                await this.client.useItem(goldItem.item_id, -1);
                assert.fail('Should not allow negative usage count');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    this.client.protoHelper.ErrorCode.ERROR_CODE_INVALID_PARAM,
                    'Should have invalid params error code'
                );
            }

            // 6.2 使用不存在的物品
            try {
                await this.client.useItem(999999, 1);
                assert.fail('Should not allow using non-existent item');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    this.client.protoHelper.ErrorCode.ERROR_CODE_INVALID_PARAM,
                    'Should have item not found error code'
                );
            }

            // 6.3 使用超量物品
            try {
                await this.client.useItem(goldItem.item_id, goldItem.count + 1);
                assert.fail('Should not allow using more items than owned');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    this.client.protoHelper.ErrorCode.ERROR_CODE_INVALID_PARAM,
                    'Should have item not enough error code'
                );
            }
        } catch (error) {
            console.error('Test GOLD item failed:', error);
            if (error.details) {
                console.error('Error details:', JSON.stringify(error.details, null, 2));
            }
            throw error;
        }
    }
}

module.exports = UseItemTest; 