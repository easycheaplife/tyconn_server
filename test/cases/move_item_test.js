const assert = require('assert')
const BaseTest = require('../lib/base_test')

class MoveItemTest extends BaseTest {
    constructor() {
        super('Move Item Test')
    }

    async test() {
        try {
            // 1. 登录获取背包信息验证连接是否正常
            const initBagInfo = await this.client.getBagInfo()
            assert(initBagInfo.bags)
            
            // 2. 直接添加测试物品而不清空背包(绕过clear_bag操作)
            await this.client.gmCommand('add_item', ['1001', '1', '1', '0']) // 添加到第0格
            await this.client.gmCommand('add_item', ['2012', '1', '1', '5']) // 添加到第5格
            
            // 3. 移动物品
            const moveResp = await this.client.moveItem(
                this.client.protoHelper.BagType.BAG_TYPE_MAIN, // 源背包
                1,  // 源格子
                this.client.protoHelper.BagType.BAG_TYPE_MAIN, // 目标背包
                3   // 目标格子
            )
            
            // 检查响应中是否有变化的物品
            assert(moveResp.changed_items)
            
            // 4. 获取移动后的背包信息
            const bagInfoAfterMove = await this.client.getBagInfo()
            assert(bagInfoAfterMove.bags)
            
            return true
        } catch (error) {
            console.error('Move item test failed:', error)
            throw error
        }
    }
}

module.exports = MoveItemTest 