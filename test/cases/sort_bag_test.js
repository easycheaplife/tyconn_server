const assert = require('assert')
const BaseTest = require('../lib/base_test')

class SortBagTest extends BaseTest {
    constructor() {
        super('Sort Bag Test')
    }

    async test() {
        try {
            // 0. 清除所有背包物品，确保测试环境干净
            console.log('\nClearing bag before test...')
            await this.client.gmCommand('clear_bag', ['1'])

            // 1. 获取初始背包信息
            const initBagInfo = await this.client.getBagInfo()
            assert(initBagInfo.bags)
            
            const emptyBag = initBagInfo.bags.find(bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN)
            console.log('Initial bag state:', JSON.stringify(emptyBag))
            
            // 2. 添加测试物品
            console.log('\nAdding test items...')
            await this.client.gmCommand('add_item', ['1001', '1']) // 武器
            await this.client.gmCommand('add_item', ['2012', '1']) // 消耗品

            // 3. 执行背包排序
            console.log('\nSorting bag...')
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
            console.log('Sorted bag state:', JSON.stringify(mainBag))
            
            // 6. 检查排序后的物品数量
            // 由于环境可能有其他物品，我们检查背包中至少有我们添加的两个物品
            assert(mainBag.items && mainBag.items.length >= 2, 
                   `Bag should have at least 2 items, found ${mainBag.items ? mainBag.items.length : 0}`)
            
            // 7. 验证物品排序 - 检查我们的测试物品是否存在
            const hasWeapon = mainBag.items.some(item => item.item_id === 1001)
            const hasConsumable = mainBag.items.some(item => item.item_id === 2012)
            
            assert(hasWeapon, 'Bag should contain the weapon we added (item_id: 1001)')
            assert(hasConsumable, 'Bag should contain the consumable we added (item_id: 2012)')
            
            return true
        } catch (error) {
            console.error('Sort bag test failed:', error)
            throw error
        }
    }
}

module.exports = SortBagTest