const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class LevelUpPartnerTest extends BaseTest {
    constructor() {
        super('Level Up Partner Test');
    }

    async test() {
        try {
            // 先获取伙伴列表
            console.log('\nGetting partner list for level up test...');
            const response = await this.client.getPartnerList();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(Array.isArray(response.partners), 'Partners should be an array');
            
            // 如果没有伙伴，此测试无法进行
            if (response.partners.length === 0) {
                console.log('No partners found, skipping level up test');
                return true;
            }
            
            // 找出一个已解锁且可升级的伙伴
            const unlockedPartner = response.partners.find(p => p.state === 2 && p.can_level_up);
            
            if (!unlockedPartner) {
                console.log('No upgradable partners found, skipping level up test');
                return true;
            }
            
            // 记录升级前的等级
            const oldLevel = unlockedPartner.base_info.level;
            console.log(`Partner ${unlockedPartner.base_info.unit_id} current level: ${oldLevel}`);
            
            // 测试: 伙伴升级
            console.log('\nTesting partner level up...');
            const partnerId = unlockedPartner.base_info.partner_id.high !== undefined ? 
            (BigInt(unlockedPartner.base_info.partner_id.high) << BigInt(32)) + BigInt(unlockedPartner.base_info.partner_id.low) :
            unlockedPartner.base_info.partner_id;
                
            const levelUpResponse = await this.client.levelUpPartner(partnerId.toString());
            
            // 验证响应
            assert(levelUpResponse, 'Level up response should not be null');
            assert(levelUpResponse.partner, 'Updated partner info should be included');
            
            // 验证等级已提升
            const newLevel = levelUpResponse.partner.base_info.level;
            assert(newLevel > oldLevel, `Partner level should increase after level up (old: ${oldLevel}, new: ${newLevel})`);
            console.log(`Partner ${unlockedPartner.base_info.unit_id} new level: ${newLevel}`);
            
            // 验证属性变化
            if (levelUpResponse.property_changes) {
                console.log('\nProperty changes:');
                for (const change of levelUpResponse.property_changes) {
                    assert(change.prop_id !== undefined, 'Property ID should be defined in changes');
                    assert(typeof change.value === 'number', 'Change value should be a number');
                    console.log(`  Property ${change.prop_id}: +${change.value}`);
                }
            }
            
            // 验证消耗物品
            if (levelUpResponse.consumed_items) {
                console.log('\nConsumed items:');
                for (const item of levelUpResponse.consumed_items) {
                    assert(item.item_id > 0, 'Consumed item ID should be positive');
                    assert(item.count > 0, 'Consumed item count should be positive');
                    console.log(`  Item ${item.item_id}: ${item.count}`);
                }
            }
            
            // 确认升级后的伙伴数据已更新
            const updatedResponse = await this.client.getPartnerList();
            const updatedPartner = updatedResponse.partners.find(p => 
                (typeof p.base_info.partner_id.low === 'number' ? 
                    p.base_info.partner_id.low : p.base_info.partner_id) === partnerId
            );
            
            assert(updatedPartner, 'Should be able to find updated partner in list');
            assert(updatedPartner.base_info.level === newLevel, 
                `Updated partner level in list should match (expected: ${newLevel}, actual: ${updatedPartner.base_info.level})`);
            
            return true;
        } catch (error) {
            console.error('Level up partner test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = LevelUpPartnerTest; 