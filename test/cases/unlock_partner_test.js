const BaseTest = require('../lib/base_test');
const assert = require('assert');

class UnlockPartnerTest extends BaseTest {
    constructor() {
        super('Unlock Partner Test');
    }

    async test() {
        try {
            // 状态定义常量
            const PARTNER_STATE_AVAILABLE = 1; // 可解锁
            const PARTNER_STATE_UNLOCKED = 2;  // 已解锁
            const PARTNER_STATE_LOCKED = 3;    // 未解锁
            
            // 指定测试用的伙伴ID和碎片ID
            const PARTNER_ID = 4301;  // 要解锁的伙伴ID
            const FRAGMENT_ID = 5301; // 伙伴碎片ID
            
            console.log(`\nTesting unlock partner: Partner=${PARTNER_ID}, Fragment=${FRAGMENT_ID}`);
            
            // 获取伙伴列表
            console.log('Getting partner list...');
            const response = await this.client.getPartnerList();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(Array.isArray(response.partners), 'Partners should be an array');
            
            // 查找指定的伙伴
            const testPartner = response.partners.find(p => 
                p.base_info.unit_id === PARTNER_ID
            );
            
            if (!testPartner) {
                console.log(`Partner with ID ${PARTNER_ID} not found in the list, test cannot proceed`);
                return false;
            }
            
            if (testPartner.state === PARTNER_STATE_UNLOCKED) {
                console.log(`Partner ${PARTNER_ID} is already unlocked, test cannot proceed`);
                return false;
            }
            
            // 获取用户背包信息，检查碎片数量
            console.log('Getting bag info to check fragment count...');
            const bagResponse = await this.client.getBagInfo();
            assert(bagResponse, 'Bag response should not be null');
            assert(Array.isArray(bagResponse.bags), 'Bags should be an array');

            // 查找主背包
            const mainBag = bagResponse.bags.find(bag => 
                bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN
            );
            assert(mainBag, 'Main bag should exist');
            assert(Array.isArray(mainBag.items), 'Bag items should be an array');

            // 查找碎片
            const fragment = mainBag.items.find(item => item.item_id === FRAGMENT_ID);
            const fragmentCount = fragment ? fragment.count : 0;

            console.log(`Found partner: Unit ID ${testPartner.base_info.unit_id}, ` +
                `State: ${testPartner.state}, Fragment count: ${fragmentCount}/${testPartner.fragment_need}`);
            
            // 检查是否有足够的碎片
            if (fragmentCount < testPartner.fragment_need) {
                console.log(`Not enough fragments to unlock partner. Have: ${fragmentCount}, Need: ${testPartner.fragment_need}`);
                return false;
            }
            
            // 有足够碎片，尝试解锁
            console.log('\nAttempting to unlock partner...');
            const unlockResponse = await this.client.unlockPartner(PARTNER_ID);
            
            // 验证响应
            assert(unlockResponse, 'Unlock response should not be null');
            assert(unlockResponse.partner, 'Unlocked partner info should be included');
            assert(unlockResponse.consumed_fragments, 'Consumed fragments info should be included');
            
            // 验证状态已更改为已解锁
            assert(unlockResponse.partner.state === PARTNER_STATE_UNLOCKED, 
                `Partner state should be "unlocked" after unlock (actual: ${unlockResponse.partner.state})`);
                
            // 验证消耗的碎片数量
            assert(unlockResponse.consumed_fragments > 0, 
                'Consumed fragments should be positive');
            
            console.log(`Partner ${PARTNER_ID} unlocked successfully, consumed ${unlockResponse.consumed_fragments} fragments`);
            
            // 确认解锁后的伙伴数据已更新
            const updatedResponse = await this.client.getPartnerList();
            const updatedPartner = updatedResponse.partners.find(p => 
                p.base_info.unit_id === PARTNER_ID
            );
            
            assert(updatedPartner, 'Should be able to find unlocked partner in list');
            assert(updatedPartner.state === PARTNER_STATE_UNLOCKED, 
                `Updated partner state in list should be "unlocked" (actual: ${updatedPartner.state})`);
            
            // 验证碎片数量已减少
            const updatedBagResponse = await this.client.getBagInfo();
            const updatedMainBag = updatedBagResponse.bags.find(bag => 
                bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN
            );
            const updatedFragment = updatedMainBag.items.find(item => item.item_id === FRAGMENT_ID);
            const updatedFragmentCount = updatedFragment ? updatedFragment.count : 0;
            
            assert(updatedFragmentCount === fragmentCount - unlockResponse.consumed_fragments,
                `Fragment count should decrease by ${unlockResponse.consumed_fragments}`);
            
            return true;
        } catch (error) {
            console.error('Unlock partner test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = UnlockPartnerTest; 