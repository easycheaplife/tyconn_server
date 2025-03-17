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
            // 直接使用原始的partner_id，不做任何转换
            const partnerId = unlockedPartner.base_info.partner_id;
            console.log(`原始伙伴ID:`, JSON.stringify(partnerId));
            
            // 如果是对象格式 (high/low)，记录更多信息用于调试
            if (partnerId && typeof partnerId === 'object' && partnerId.high !== undefined) {
                console.log(`伙伴ID高32位: ${partnerId.high}, 低32位: ${partnerId.low}`);
            }
            
            // 调用API进行升级，不转换ID
            const levelUpResponse = await this.client.levelUpPartner(partnerId);
            
            // 验证响应
            assert(levelUpResponse, 'Level up response should not be null');
            assert(levelUpResponse.partner, 'Updated partner info should be included');
            
            // 记录升级后伙伴的ID，用于后续比较
            const updatedPartnerId = levelUpResponse.partner.base_info.partner_id;
            console.log(`升级后的伙伴ID:`, JSON.stringify(updatedPartnerId));
            
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
            
            // 记录原始的unit_id作为备用标识
            const unitId = unlockedPartner.base_info.unit_id;
            console.log(`查找伙伴，Unit ID: ${unitId}, 伙伴ID:`, JSON.stringify(updatedPartnerId));
            
            // 打印所有伙伴信息用于调试
            updatedResponse.partners.forEach((p, index) => {
                console.log(`伙伴 ${index}:`, {
                    id: JSON.stringify(p.base_info.partner_id),
                    unit_id: p.base_info.unit_id,
                    level: p.base_info.level
                });
            });
            
            // 先尝试通过ID精确匹配
            let updatedPartner = updatedResponse.partners.find(p => {
                const pId = p.base_info.partner_id;
                // 如果两者都是对象形式，比较high和low
                if (pId && updatedPartnerId && 
                    typeof pId === 'object' && typeof updatedPartnerId === 'object' &&
                    pId.high !== undefined && updatedPartnerId.high !== undefined) {
                    return pId.high === updatedPartnerId.high && pId.low === updatedPartnerId.low;
                }
                // 如果两者都是字符串，直接比较
                else if (typeof pId === 'string' && typeof updatedPartnerId === 'string') {
                    return pId === updatedPartnerId;
                }
                // 其他情况尝试转字符串比较
                return String(pId) === String(updatedPartnerId);
            });
            
            // 如果通过ID没找到，尝试通过unit_id查找
            if (!updatedPartner) {
                console.log(`通过ID未找到伙伴，尝试通过unit_id查找: ${unitId}`);
                updatedPartner = updatedResponse.partners.find(p => 
                    p.base_info.unit_id === unitId && p.state === 2
                );
            }
            
            if (!updatedPartner) {
                console.error("未找到伙伴。所有伙伴:", 
                    updatedResponse.partners.map(p => ({
                        id: JSON.stringify(p.base_info.partner_id),
                        unit_id: p.base_info.unit_id,
                        level: p.base_info.level
                    }))
                );
            }
            
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