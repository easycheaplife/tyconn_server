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
            
            // 3. 添加高级物品用于分解
            await this.client.gmCommand('add_item', ['1004', '2'])  // 添加2个高级草药
            
            // 4. 获取添加物品后的背包信息，找到物品所在格子
            const bagAfterAdd = await this.client.getBagInfo()
            const mainBag = bagAfterAdd.bags.find(
                bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN
            )
            assert(mainBag)
            
            // 找到高级草药所在的格子
            const advancedHerb = mainBag.items.find(item => item.item_id === 1004)
            assert(advancedHerb, "未找到高级草药物品")
            
            // 5. 执行物品分解
            const decomposeResp = await this.client.decomposeItem([advancedHerb.slot])
            
            // 6. 验证分解结果
            assert(decomposeResp.result_items, "应该返回分解结果物品")
            assert(decomposeResp.result_items.length > 0, "分解结果应该有物品")
            
            // 7. 验证背包状态
            const bagInfoAfter = await this.client.getBagInfo()
            const mainBagAfter = bagInfoAfter.bags.find(
                bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN
            )
            
            // 高级草药应该被消耗掉一个
            const herbAfter = mainBagAfter.items.find(item => item.item_id === 1004)
            if (herbAfter) {
                assert.strictEqual(herbAfter.count, 1, "应该剩余1个高级草药")
            }
            
            // 应该获得分解的基础物品
            const basicHerb = mainBagAfter.items.find(item => item.item_id === 1001)
            assert(basicHerb, "应该获得基础草药")
            
            const gold = mainBagAfter.items.find(item => item.item_id === 2012)
            assert(gold, "应该获得金币物品")
            
            return true
        } catch (error) {
            console.error('Decompose item test failed:', error)
            throw error
        }
    }
}

module.exports = DecomposeItemTest 