const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class GetPartnerListTest extends BaseTest {
    constructor() {
        super('Get Partner List Test');
    }

    async test() {
        try {
            // 测试: 获取伙伴列表
            console.log('\nTesting get partner list...');
            const response = await this.client.getPartnerList();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(Array.isArray(response.partners), 'Partners should be an array');
            
            // 验证伙伴字段
            for (const partner of response.partners) {
                // 检查基本信息
                assert(partner.base_info, 'Partner should have base_info');
                assert(partner.base_info.partner_id && 
                      (typeof partner.base_info.partner_id.low === 'number' || 
                       typeof partner.base_info.partner_id === 'number'), 
                      'Partner ID should be valid');
                assert(partner.base_info.unit_id > 0, 'Unit ID should be positive');
                assert(partner.base_info.level >= 1, 'Level should be at least 1');
                assert(partner.base_info.star >= 0, 'Star should be non-negative');
                
                // 检查状态信息
                assert([1, 2, 3].includes(partner.state), 'State should be 1, 2, or 3');
            }

            // 测试: 缓存验证
            console.log('\nTesting partner list cache...');
            const secondResponse = await this.client.getPartnerList();
            assert.deepStrictEqual(response.partners, secondResponse.partners, 
                'Cached partners should match');

            // 测试: 伙伴唯一性验证
            console.log('\nTesting partner uniqueness...');
            const activatedPartners = response.partners.filter(p => p.state === 1); // 只考虑已激活的伙伴
            const partnerIds = new Set(activatedPartners
                .filter(p => p.base_info && p.base_info.partner_id)
                .map(p => typeof p.base_info.partner_id.low === 'number' ? 
                    p.base_info.partner_id.low : p.base_info.partner_id));
            assert.strictEqual(partnerIds.size, activatedPartners.length, 
                'Each activated partner should have a unique ID');

            // 测试: 断开重连验证
            console.log('\nTesting partners persistence after reconnect...');
            await this.client.close();
            await this.client.connect();
            const finalResponse = await this.client.getPartnerList();
            assert(finalResponse.partners.length === response.partners.length, 
                'Should have same number of partners after reconnect');

            return true;
        } catch (error) {
            console.error('Get partner list test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = GetPartnerListTest; 