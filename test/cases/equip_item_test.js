const BaseTest = require('../lib/base_test');
const assert = require('assert');

class EquipItemTest extends BaseTest {
    constructor() {
        super('Equip Item Test');
    }

    async test() {
        try {
            // 测试: 装备物品
            console.log('\nTesting equip item...');
            
            // 首先获取背包信息，寻找可装备物品
            const bagResponse = await this.client.getBagInfo();
            
            // 查找第一个装备类型物品
            let equipItem = null;
            let bagType = 0;
            let bagSlot = 0;
            
            // 遍历所有背包
            for (const bag of bagResponse.bags) {
                if (equipItem) break;
                
                // 查找装备类型物品（假设item_id范围2000-3000为装备）
                for (const item of bag.items) {
                    if (item.item_id >= 2000 && item.item_id < 3000) {
                        equipItem = item;
                        bagType = bag.bag_type;
                        bagSlot = item.slot;
                        break;
                    }
                }
            }
            
            // 如果找到装备物品，尝试装备
            if (equipItem) {
                console.log(`Found equipment item in bag type ${bagType}, slot ${bagSlot}`);
                
                try {
                    // 尝试装备到槽位3（假设这是一个有效的装备槽位）
                    const equipSlot = 3;
                    
                    // 装备物品，参数名改为正确的名称
                    const equipResponse = await this.client.equipItem(
                        bagType, 
                        bagSlot,  // 这里的参数会被传递给handler中的slotIndex
                        equipSlot
                    );
                    
                    // 验证装备成功
                    assert(equipResponse.equipped_item, 'Equipped item should be returned');
                    
                    // 验证物品已装备
                    const equipmentInfo = await this.client.getEquipInfo();
                    let found = false;
                    for (const slot of equipmentInfo.slots) {
                        if (slot.slot_id === equipSlot) {
                            assert(slot.item, 'Slot should have an item equipped');
                            found = true;
                            break;
                        }
                    }
                    assert(found, 'Equipped item should be in slot');
                    
                    return true;
                } catch (e) {
                    console.error('Equip item test failed:', e);
                    console.error('Error stack:', e.stack);
                    return false;
                }
            } else {
                console.log('No suitable equipment item found in bags for testing');
                // 没有找到装备物品，但测试本身不失败
                return true;
            }
        } catch (error) {
            console.error('Equip item test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = EquipItemTest;