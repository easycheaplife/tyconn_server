const assert = require('assert')
const BaseTest = require('../lib/base_test')

class SortBagTest extends BaseTest {
    constructor() {
        super('Sort Bag Test')
    }

    async test() {
        try {
            // 1. 获取初始背包信息
            const initBagInfo = await this.client.getBagInfo()
            assert(initBagInfo.bags)

            // 2. 添加测试物品
            await this.client.gm_command('add_item', ['1001', '1']) // 武器
            await this.client.gm_command('add_item', ['2012', '1']) // 消耗品

            // 3. 执行背包排序
            const sortResp = await this.client.sortBag(
                this.client.protoHelper.BagType.BAG_TYPE_MAIN,
                1
            )

            // 4. 获取排序后的背包信息
            const bagInfo = await this.client.getBagInfo()
            assert(bagInfo.bags)

            // 5. 验证排序结果
            const mainBag = bagInfo.bags.find(bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN)
            assert(mainBag)
            assert(mainBag.items.length === 2)

            return true
        } catch (error) {
            console.error('Sort bag test failed:', error)
            throw error
        }
    }
}

module.exports = SortBagTest 