const BaseTest = require('../lib/base_test');
const assert = require('assert');

class EquipLevelInfoTest extends BaseTest {
    constructor() {
        super('Equipment Level Info Test');
    }

    async test() {
        try {
            console.log('\nTesting get equipment level info...');
            
            // 获取装备等级信息
            const response = await this.client.getEquipLevelInfo();
            
            // 检查响应
            assert(response, 'Response should not be null');
            console.log('Equipment level info:', response);
            
            // 验证必要字段
            assert(typeof response.current_level === 'number', 'Current level should be a number');
            assert(typeof response.max_level === 'number', 'Max level should be a number');
            
            console.log(`Current equipment level: ${response.current_level}`);
            console.log(`Max equipment level: ${response.max_level}`);
            
            if (response.is_upgrading) {
                console.log(`Upgrade in progress. Remaining time: ${response.remaining_time} seconds`);
            }
            
            console.log('Equipment level info test passed');
            return true;
        } catch (error) {
            console.log(`Equipment level info test failed: ${error}`);
            console.log(`Error stack: ${error.stack}`);
            return false;
        }
    }
}

module.exports = EquipLevelInfoTest; 