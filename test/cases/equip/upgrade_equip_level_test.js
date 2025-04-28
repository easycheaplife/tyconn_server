const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class UpgradeEquipLevelTest extends BaseTest {
    constructor() {
        super('Upgrade Equipment Level Test');
    }

    async test() {
        try {
            // 首先获取装备等级信息
            console.log('\nGetting current equipment level info...');
            const levelInfo = await this.client.getEquipLevelInfo();
            
            // 检查响应
            assert(levelInfo, 'Level info response should not be null');
            console.log('Equipment level info:', levelInfo);
            
            // 确保有足够的升级材料
            if (levelInfo.item_id && levelInfo.item_count) {
                console.log(`Adding required items for upgrade: item_id=${levelInfo.item_id}, count=${levelInfo.item_count}`);
                // 添加比需求多一些的物品数量
                await this.client.gmCommand('add_item', [
                    levelInfo.item_id.toString(), 
                    (levelInfo.item_count + 100).toString()
                ]);
            }
            
            // 测试升级装备等级
            console.log('\nTesting equipment system upgrade...');
            const upgradeResponse = await this.client.upgradeEquipLevel();
            
            // 验证升级请求处理
            assert(upgradeResponse, 'Upgrade response should not be null');
            
            // 验证升级结果
            assert(upgradeResponse.current_level > levelInfo.current_level || upgradeResponse.is_upgrading, 
                'Equipment level should increase or be upgrading');
            
            if (upgradeResponse.is_upgrading) {
                console.log('Equipment upgrade in progress');
                console.log(`Remaining time: ${upgradeResponse.remaining_time} seconds`);
                assert(upgradeResponse.remaining_time > 0, 'Remaining time should be positive');
            } else {
                console.log('Equipment level upgrade successful!');
                console.log(`New level: ${upgradeResponse.current_level}`);
            }
            
            return true;
        } catch (error) {
            console.error('Upgrade equipment level test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = UpgradeEquipLevelTest;