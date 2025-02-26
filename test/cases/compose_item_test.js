const assert = require('assert')
const BaseTest = require('../lib/base_test')

class ComposeItemTest extends BaseTest {
    constructor() {
        super('Compose Item Test')
    }

    async test() {
        try {
            // 1. 获取初始背包信息
            const initBagInfo = await this.client.getBagInfo()
            assert(initBagInfo.bags)
            
            // 2. 在添加测试物品之前先清空背包
            await this.client.gmCommand('clear_bag', ['1']) // 清空主背包
            
            // 3. 添加测试物品（不指定格子，让服务器决定）
            await this.client.gmCommand('add_item', ['1001', '5'])  // 添加5个草药
            await this.client.gmCommand('add_item', ['2012', '3'])  // 添加3个金币物品而不是水晶
            
            // 4. 获取添加物品后的背包信息，找到物品所在格子
            const bagAfterAdd = await this.client.getBagInfo()
            const mainBag = bagAfterAdd.bags.find(
                bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN
            )
            assert(mainBag)
            
            // 找到草药和金币物品所在的格子
            const herb = mainBag.items.find(item => item.item_id === 1001)
            const gold = mainBag.items.find(item => item.item_id === 2012)
            
            assert(herb, "未找到草药物品")
            assert(gold, "未找到金币物品")
            
            // 5. 执行物品合成，使用找到的物品格子
            const composeResp = await this.client.composeItem(1004, [herb.slot, gold.slot])
            
            // 6. 验证合成结果
            assert(composeResp.success, "合成应该成功")
            assert(composeResp.new_item, "应该返回新物品")
            assert.strictEqual(composeResp.new_item.item_id, 1004, "新物品ID应该为1004")
            
            // 7. 验证背包状态
            const bagInfoAfter = await this.client.getBagInfo()
            const mainBagAfter = bagInfoAfter.bags.find(
                bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN
            )
            
            // 查找剩余的材料物品
            const herbAfter = mainBagAfter.items.find(item => item.item_id === 1001)
            assert(herbAfter, "草药应该还有剩余")
            assert.strictEqual(herbAfter.count, 3, "应该剩余3个草药")
            
            const goldAfter = mainBagAfter.items.find(item => item.item_id === 2012)
            assert(goldAfter, "金币物品应该还有剩余")
            assert.strictEqual(goldAfter.count, 2, "应该剩余2个金币物品")
            
            // 查找合成的新物品
            const newItem = mainBagAfter.items.find(item => item.item_id === 1004)
            assert(newItem, "应该存在合成的新物品")
            assert.strictEqual(newItem.count, 1, "应该有1个新物品")
            
            return true
        } catch (error) {
            console.error('Compose item test failed:', error)
            throw error
        }
    }
}

module.exports = ComposeItemTest 