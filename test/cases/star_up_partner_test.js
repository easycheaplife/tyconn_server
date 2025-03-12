const BaseTest = require('../lib/base_test');
const assert = require('assert');

class StarUpPartnerTest extends BaseTest {
    constructor() {
        super('Star Up Partner Test');
    }

    async test() {
        try {
            // 先获取伙伴列表
            console.log('\nGetting partner list for star up test...');
            const response = await this.client.getPartnerList();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(Array.isArray(response.partners), 'Partners should be an array');
            
            // 如果没有伙伴，此测试无法进行
            if (response.partners.length === 0) {
                console.log('No partners found, skipping star up test');
                return true;
            }
            
            // 找出一个已解锁且可升星的伙伴
            const unlockedPartner = response.partners.find(p => p.state === 2 && p.can_star_up);
            
            if (!unlockedPartner) {
                console.log('No star-upgradable partners found, skipping star up test');
                return true;
            }
            
            // 记录升星前的星级
            const oldStar = unlockedPartner.base_info.star;
            console.log(`Partner ${unlockedPartner.base_info.unit_id} current star: ${oldStar}`);
            
            // 测试: 伙伴升星
            console.log('\nTesting partner star up...');
            const partnerId = unlockedPartner.base_info.partner_id.high !== undefined ? 
                (BigInt(unlockedPartner.base_info.partner_id.high) << BigInt(32)) + BigInt(unlockedPartner.base_info.partner_id.low) :
                unlockedPartner.base_info.partner_id;
            console.log(partnerId);
            const starUpResponse = await this.client.starUpPartner(partnerId.toString());
            
            // 验证响应
            assert(starUpResponse, 'Star up response should not be null');
            assert(starUpResponse.partner, 'Updated partner info should be included');
            
            // 验证星级已提升
            const newStar = starUpResponse.partner.base_info.star;
            assert(newStar > oldStar, `Partner star should increase after star up (old: ${oldStar}, new: ${newStar})`);
            console.log(`Partner ${unlockedPartner.base_info.unit_id} new star: ${newStar}`);
            
            // 验证属性变化
            if (starUpResponse.property_changes) {
                console.log('\nProperty changes:');
                for (const change of starUpResponse.property_changes) {
                    assert(change.prop_id !== undefined, 'Property ID should be defined in changes');
                    assert(typeof change.value === 'number', 'Change value should be a number');
                    console.log(`  Property ${change.prop_id}: +${change.value}`);
                }
            }
            
            // 验证消耗物品
            if (starUpResponse.consumed_items) {
                console.log('\nConsumed items:');
                for (const item of starUpResponse.consumed_items) {
                    assert(item.item_id > 0, 'Consumed item ID should be positive');
                    assert(item.count > 0, 'Consumed item count should be positive');
                    console.log(`  Item ${item.item_id}: ${item.count}`);
                }
            }
            
            // 确认升星后的伙伴数据已更新
            const updatedResponse = await this.client.getPartnerList();
            const updatedPartner = updatedResponse.partners.find(p => 
                (typeof p.base_info.partner_id.low === 'number' ? 
                    p.base_info.partner_id.low : p.base_info.partner_id) === partnerId
            );
            
            assert(updatedPartner, 'Should be able to find updated partner in list');
            assert(updatedPartner.base_info.star === newStar, 
                `Updated partner star in list should match (expected: ${newStar}, actual: ${updatedPartner.base_info.star})`);
            
            return true;
        } catch (error) {
            console.error('Star up partner test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = StarUpPartnerTest; 