const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class EquipRandomTest extends BaseTest {
    constructor() {
        super('Equipment Random Test');
    }

    async test() {
        try {
            console.log('\nTesting get random equipment...');
            
            // 随机获取装备（部位1，不替换）
            const part = 1; // 部位1（头盔等）
            const isReplace = false; // 不替换现有装备
            
            const response = await this.client.getRandomEquip(part, isReplace);
            
            // 检查响应
            assert(response, 'Response should not be null');
            console.log('Random equipment response:', response);
            
            // 验证必要字段
            assert(response.new_equip, 'New equipment should be returned');
            
            // 打印新装备信息
            console.log(`Received random equipment: ID=${response.new_equip.item_id}`);
            if (response.power_diff !== undefined) {
                console.log(`Power difference: ${response.power_diff}`);
            }
            
            console.log('Equipment random test passed');
            return true;
        } catch (error) {
            console.log(`Equipment random test failed: ${error}`);
            console.log(`Error stack: ${error.stack}`);
            return false;
        }
    }
}

module.exports = EquipRandomTest; 