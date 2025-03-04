const assert = require('assert')
const BaseTest = require('../lib/base_test')

class DecomposeItemTest extends BaseTest {
    constructor() {
        super('Decompose Item Test')
    }

    async test() {
        try {
            // 1. 获取初始背包信息
            const initBagInfo = await this.client.getBagInfo()
            assert(initBagInfo.bags)
            
            // 2. 在添加测试物品之前先清空背包
            await this.client.gmCommand('clear_bag', ['1']) // 清空主背包
            
            // 3. 添加测试物品
            await this.client.gmCommand('add_item', ['4301', '1'])  // 添加1个要分解的物品

            // 4. 执行物品分解
            const decomposeResp = await this.client.decomposeItem(4301)
            
            // 5. 验证分解结果
            assert(decomposeResp.result_items, "应该返回分解结果物品")
            assert(decomposeResp.result_items.length > 0, "应该有分解获得的物品")
            
            // 6. 验证背包状态
            const bagInfoAfter = await this.client.getBagInfo()
            const mainBagAfter = bagInfoAfter.bags.find(
                bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN
            )
            
            // 验证原物品已被消耗
            const originalItem = mainBagAfter.items.find(item => item.item_id === 4301)
            assert(!originalItem, "原物品应该被消耗")

            // 验证获得的分解物品
            const resultItem = mainBagAfter.items.find(item => item.item_id === 5301)
            assert(resultItem, "应该获得分解后的物品")
            assert.strictEqual(resultItem.count, 9, "分解应该获得20个碎片")
            
            return true
        } catch (error) {
            console.error('Decompose item test failed:', error)
            throw error
        }
    }
}

module.exports = DecomposeItemTest 