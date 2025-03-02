const BaseTest = require('../lib/base_test');
const assert = require('assert');

class EquipInfoTest extends BaseTest {
    constructor() {
        super('Equipment Info Test');
    }

    async test() {
        console.log("\nTesting get equipment info...");
        console.log("Client token:", this.client.token);  // 验证token是否存在
        
        try {
            // 获取装备信息
            const response = await this.client.getEquipInfo();
            
            // 检查响应是否为对象
            assert(response, 'Response should not be null');
            console.log('Full response:', response);
            
            // 验证装备物品数组存在
            assert(Array.isArray(response.equipped_items), 'Equipped items should be an array');
            
            // 验证战斗力存在
            assert(typeof response.combat_power === 'number', 'Combat power should be a number');
            
            console.log(`Found ${response.equipped_items.length} equipped items`);
            console.log(`Current combat power: ${response.combat_power}`);
            
            // 如果有装备，显示更多信息
            if (response.equipped_items.length > 0) {
                console.log('Equipped items:');
                response.equipped_items.forEach((item, index) => {
                    console.log(`  Item ${index+1}: ID=${item.id}, Type=${item.item_id}, Slot=${item.equip_slot}`);
                });
            }
            
            console.log('Equipment info test passed');
            return true;
        } catch (error) {
            console.log(`Equipment info test failed: ${error}`);
            console.log(`Error stack: ${error.stack}`);
            return false;
        }
    }
}

module.exports = EquipInfoTest;