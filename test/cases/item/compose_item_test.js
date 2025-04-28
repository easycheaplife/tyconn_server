const assert = require('assert')
const BaseTest = require('../../lib/base_test')

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
            await this.client.gmCommand('add_item', ['5301', '25'])  // 添加25个碎片

            // 4. 执行物品合成，使用找到的物品格子
            const composeResp = await this.client.composeItem(4301)
            console.log(composeResp)
            // 5. 验证合成结果
            assert(composeResp.new_item, "应该返回新物品")
            assert.strictEqual(composeResp.new_item.item_id, 4301, "新物品ID应该为4301")
            
            // 6. 验证背包状态
            const bagInfoAfter = await this.client.getBagInfo()
            const mainBagAfter = bagInfoAfter.bags.find(
                bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN
            )
            
            // 查找合成的新物品
            const newItem = mainBagAfter.items.find(item => item.item_id === 4301)
            assert(newItem, "应该存在合成的新物品")
            assert.strictEqual(newItem.count, 1, "应该有1个新物品")

            // 验证合成后的碎片数量
            const shardsAfter = mainBagAfter.items.filter(item => item.item_id === 5301)
            assert.strictEqual(shardsAfter[0].count, 5, "合成后碎片剩余数量应该为5")
            
            return true
        } catch (error) {
            console.error('Compose item test failed:', error)
            throw error
        }
    }
}

module.exports = ComposeItemTest 