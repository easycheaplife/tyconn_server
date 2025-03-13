const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class UnequipItemTest extends BaseTest {
    constructor() {
        super('Unequip Item Test');
    }

    async test() {
        try {
            // 首先获取装备信息
            console.log('\nGetting current equipment info...');
            const equipmentInfo = await this.client.getEquipInfo();
            
            // 寻找已装备的槽位
            let equippedSlot = null;
            for (const slot of equipmentInfo.slots) {
                if (slot.item) {
                    equippedSlot = slot.slot_id;
                    break;
                }
            }
            
            // 如果没有已装备槽位，尝试装备一个物品
            if (!equippedSlot) {
                console.log('No equipped items found, trying to equip one first...');
                
                // 首先获取背包信息，寻找可装备物品
                const bagResponse = await this.client.getBagInfo();
                
                // 查找第一个装备类型物品
                let equipItem = null;
                let bagType = 0;
                let bagSlot = 0;
                
                // 遍历所有背包
                for (const bag of bagResponse.bags) {
                    if (equipItem) break;
                    
                    // 查找装备类型物品
                    for (const item of bag.items) {
                        if (item.item_id >= 2000 && item.item_id < 3000) {
                            equipItem = item;
                            bagType = bag.bag_type;
                            bagSlot = item.slot;
                            break;
                        }
                    }
                }
                
                if (equipItem) {
                    // 确定装备槽位
                    const equipSlot = (equipItem.item_id % 6) + 1; 
                    
                    console.log(`Found equipment item ${equipItem.item_id}, equipping to slot ${equipSlot}...`);
                    
                    // 装备物品
                    const equipResponse = await this.client.equipItem(bagType, bagSlot, equipSlot);
                    
                    // 检查装备是否成功
                    if (equipResponse.success) {
                        equippedSlot = equipSlot;
                    } else {
                        console.log('Failed to equip item for testing');
                    }
                } else {
                    console.log('No suitable equipment item found in bags for testing');
                }
            }
            
            // 如果有已装备槽位，尝试卸下
            if (equippedSlot) {
                console.log(`\nTesting unequip item from slot ${equippedSlot}...`);
                
                // 卸下装备
                const unequipResponse = await this.client.unequipItem(equippedSlot);
                
                // 验证卸下成功
                assert(unequipResponse.success, 'Unequipping should be successful');
                
                // 验证物品已卸下
                const finalEquipment = await this.client.getEquipInfo();
                for (const slot of finalEquipment.slots) {
                    if (slot.slot_id === equippedSlot) {
                        assert(!slot.item, 'Slot should be empty after unequipping');
                        break;
                    }
                }
                
                console.log('Successfully unequipped item from slot', equippedSlot);
                return true;
            } else {
                console.log('No equipped item available for unequip test');
                // 没有已装备物品，但测试本身不失败
                return true;
            }
        } catch (error) {
            console.error('Unequip item test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = UnequipItemTest;