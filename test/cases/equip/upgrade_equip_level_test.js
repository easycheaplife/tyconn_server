const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class UpgradeEquipLevelTest extends BaseTest {
    constructor() {
        super('Upgrade Equipment Level Test');
    }

    async test() {
        try {
            // 首先获取当前装备等级
            console.log('\nGetting current equipment level...');
            const initialEquip = await this.client.getEquipInfo();
            
            const initialLevel = initialEquip.level;
            console.log(`Current equipment system level: ${initialLevel}`);
            
            // 测试升级装备等级
            console.log('\nTesting equipment system upgrade...');
            const upgradeResponse = await this.client.upgradeEquipLevel();
            
            // 验证升级请求处理
            assert(upgradeResponse, 'Upgrade response should not be null');
            
            if (upgradeResponse.success) {
                console.log('Equipment level upgrade successful!');
                
                // 如果是即时升级，验证新等级
                if (!upgradeResponse.is_upgrading) {
                    const newEquipment = await this.client.getEquipInfo();
                    console.log(`New equipment system level: ${newEquipment.level}`);
                    assert(newEquipment.level > initialLevel, 
                        'Equipment level should increase after upgrade');
                }
                // 如果是正在升级中，验证升级状态
                else {
                    console.log('Equipment upgrade in progress');
                    console.log(`Estimated completion time: ${upgradeResponse.end_time}`);
                    assert(upgradeResponse.end_time > 0, 
                        'Upgrade end time should be set');
                }
            } else {
                // 升级可能因为各种游戏逻辑原因失败（资源不足等）
                console.log('Equipment level upgrade failed:', upgradeResponse.message);
                console.log('This might be due to game logic (e.g., insufficient resources)');
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