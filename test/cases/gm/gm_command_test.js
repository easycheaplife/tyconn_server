/**
 * GM command test module
 * 
 * Purpose:
 * This module is used to test the GM command functionality in the game, including item addition/deletion, level setting, partner operation, etc.
 * 
 * Running method:
 * 1. Run a single test:
 *    node test/run_test.js -t gm_command_test <test name>
 *    For example: node test/run_test.js -t gm_command_test add_item
 * 
 * 2. Directly execute GM command:
 *    node test/run_test.js -t gm_command <command> <param1> <param2> ...
 *    For example: node test/run_test.js -t gm_command add_item 1001 100
 * 
 * 3. Run all tests:
 *    node test/run_test.js -t gm_command_test
 * 
 * GM command description:
 * 
 * Basic commands:
 * - set_level <level>: Set character level
 *   Parameter description:
 *   - level: Target level (1-99)
 *   Example: set_level 10
 * 
 * Item management commands:
 * - add_item <item_id> <count>: Add item
 *   Parameter description:
 *   - item_id: Item ID (1001-9999)
 *   - count: Add quantity (1-2000)
 *   Example: add_item 1001 100
 * 
 * - del_item <item_id> <count>: Delete item
 *   Parameter description:
 *   - item_id: Item ID (1001-9999)
 *   - count: Delete quantity (1-2000)
 *   Example: del_item 1001 50
 * 
 * - clear_bag <bag_type>: Clear bag
 *   Parameter description:
 *   - bag_type: Bag type (1=Main bag)
 *   Example: clear_bag 1
 * 
 * Partner system commands:
 * - add_partner <unit_id>: Add partner
 *   Parameter description:
 *   - unit_id: Partner unit ID (4301-4350)
 *   Example: add_partner 4301
 * 
 * - add_fragments <fragment_id> <count>: Add partner fragments
 *   Parameter description:
 *   - fragment_id: Fragment ID (5301-5350)
 *   - count: Add quantity (1-999)
 *   Example: add_fragments 5301 100
 * 
 * - set_partner_level <partner_id> <level>: Set partner level
 *   Parameter description:
 *   - partner_id: Partner instance ID (obtained after creation)
 *   - level: Target level (1-100)
 *   Example: set_partner_level 40113330800919552 50
 * 
 * - set_partner_star <partner_id> <star>: Set partner star
 *   Parameter description:
 *   - partner_id: Partner instance ID (obtained after creation)
 *   - star: Target star (1-5)
 *   Example: set_partner_star 40113330800919552 5
 * 
 * Game play commands:
 * 
 * - dice_num <dice_value>: Set dice num
 *   Parameter description:
 *   - dice_value: Dice value (1-6)
 *   Example: dice_num 6
 * 
 * Available test cases:
 * - add_item: Test item addition functionality
 * - delete_item: Test item deletion functionality
 * - set_level: Test character level setting functionality
 * - error_cases: Test error handling
 * - clear_bag: Test clear bag functionality
 * - add_partner: Test partner addition functionality
 * - add_fragments: Test partner fragment addition functionality
 * - set_partner_level: Test partner level setting functionality
 * - set_partner_star: Test partner star setting functionality
 * - dice_num: Test dice num setting functionality
 * 
 * Note:
 * 1. Partner ID refers to the unitId in the configuration table, while partner instance ID is the partnerId after creation
 * 2. Tests automatically handle the case where the partner does not exist, they will first try to add the partner before operating
 * 3. If the specified partner is not available, the test will try to use the first unlocked partner
 * 4. All numerical parameters must be valid positive integers
 * 5. Item and fragment quantities cannot exceed the maximum stack limit (2000)
 * 6. Dice values must be integers between 1-6
 */

const assert = require('assert');
const BaseTest = require('../../lib/base_test');

class GMCommandTest extends BaseTest {
    constructor() {
        super('GM Command Test');
        // Define available test cases
        this.testCases = {
            'add_item': this.testAddItem.bind(this),
            'delete_item': this.testDeleteItem.bind(this),
            'set_level': this.testSetLevel.bind(this),
            'error_cases': this.testErrorCases.bind(this),
            'clear_bag': this.testClearBag.bind(this),
            'add_partner': this.testAddPartner.bind(this),
            'add_fragments': this.testAddFragments.bind(this),
            'set_partner_level': this.testSetPartnerLevel.bind(this),
            'set_partner_star': this.testSetPartnerStar.bind(this),
            'dice_num': this.testDiceNum.bind(this)
        };
    }

    async test() {
        try {
            // Find -t parameter after the first parameter as test case name
            const args = process.argv;
            const tIndex = args.indexOf('-t');
            
            // Check if it's a direct execution of GM command format
            // For example: node test/run_test.js -t gm_command additem 1005 10000
            if (tIndex >= 0 && args[tIndex + 1] === 'gm_command' && args.length > tIndex + 2) {
                const gmCommand = args[tIndex + 2];
                const gmParams = args.slice(tIndex + 3);
                
                console.log(`Executing GM command: ${gmCommand} with params: ${gmParams.join(', ')}`);
                
                try {
                    const response = await this.client.gmCommand(gmCommand, gmParams);
                    console.log('GM Command Response:', response);
                    return true;
                } catch (error) {
                    console.error('GM Command Failed:', error);
                    throw error;
                }
            }
            
            const testCase = tIndex >= 0 ? args[tIndex + 2] : null; // -t gm_command test_name
            
            if (testCase && this.testCases[testCase]) {
                // Execute specified test
                console.log(`Running test case: ${testCase}`);
                await this.testCases[testCase]();
            } else if (testCase) {
                console.error(`Unknown test case: ${testCase}`);
                console.log('Available test cases:', Object.keys(this.testCases).join(', '));
                throw new Error('Invalid test case');
            } else {
                // Execute all tests
                console.log('Running all test cases...');
                for (const [name, testFn] of Object.entries(this.testCases)) {
                    console.log(`\nRunning test case: ${name}`);
                    await testFn();
                }
            }
            
            return true;
        } catch (error) {
            console.error('GM command test failed:', error);
            throw error;
        }
    }

    async testAddItem() {
        console.log('\nTesting add item command...');
        
        // Get initial bag state
        const bagResponse = await this.client.getBagInfo();
        const mainBag = bagResponse.bags.find(bag => bag.bag_type === 1);
        const initialItems = mainBag.items;
        
        // Execute GM command to add item
        const response = await this.client.gmCommand('add_item', ['1001', '100']);
        assert(response.result === 'success', 'Add item should succeed');
        
        // Get updated bag
        const updatedBagResponse = await this.client.getBagInfo();
        const updatedMainBag = updatedBagResponse.bags.find(bag => bag.bag_type === 1);
        
        // Check item quantity
        const totalCount = updatedMainBag.items
            .filter(item => item.item_id === 1001)
            .reduce((sum, item) => sum + item.count, 0);
            
        // Verify total quantity is correct
        assert.strictEqual(
            totalCount - (initialItems.filter(i => i.item_id === 1001)
                .reduce((sum, i) => sum + i.count, 0)), 
            100, 
            'Should add correct amount of items'
        );
    }

    async testDeleteItem() {
        console.log('\nTesting delete item command...');
        
        // 1. First add item
        let response = await this.client.gmCommand('add_item', ['1001', '100']);
        assert.strictEqual(response.result, 'success');

        // Verify addition success
        let bagInfo = await this.client.getBagInfo();
        let initialCount = bagInfo.bags[0].items
            .filter(i => i.item_id === 1001)
            .reduce((sum, i) => sum + i.count, 0);
        
        // 2. Delete item
        response = await this.client.gmCommand('del_item', ['1001', '50']);
        assert.strictEqual(response.result, 'success');

        // 3. Verify bag
        bagInfo = await this.client.getBagInfo();
        const finalCount = bagInfo.bags[0].items
            .filter(i => i.item_id === 1001)
            .reduce((sum, i) => sum + i.count, 0);

        // Verify deleted quantity is correct
        assert.strictEqual(
            initialCount - finalCount,
            50,
            'Should delete correct amount of items'
        );
    }

    async testSetLevel() {
        console.log('\nTesting set level command...');
        
        // Set level
        const response = await this.client.gmCommand('set_level', ['10']);
        assert.strictEqual(response.result, 'success');
    }

    async testErrorCases() {
        console.log('\nTesting error cases...');
        
        // Test invalid command
        try {
            await this.client.gmCommand('invalid_command', []);
            assert.fail('Should throw error for invalid command');
        } catch (err) {
            assert(err.errorCode === this.client.protoHelper.ErrorCode.ERROR_CODE_GM_COMMAND_FAILED);
        }

        // Test invalid parameter
        try {
            await this.client.gmCommand('add_item', ['invalid']);
            assert.fail('Should throw error for invalid params');
        } catch (err) {
            assert(err.errorCode === this.client.protoHelper.ErrorCode.ERROR_CODE_GM_COMMAND_FAILED);
        }
    }

    async testClearBag() {
        console.log('\nTesting clear bag command...');
        
        // Execute clear bag command
        const response = await this.client.gmCommand('clear_bag', ['1']);
        assert(response.result === 'success', "Clear bag failed");
        
        // Get bag information to verify success
        const bagInfo = await this.client.getBagInfo();
        const mainBag = bagInfo.bags.find(bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN);
        assert(mainBag.items.length === 0, "Bag not cleared");
        
        return true;
    }

    async testAddPartner() {
        console.log('\nTesting add partner command...');
        
        // Use valid partner ID (select a valid partner unit ID from configuration)
        const unitId = 4301; // Use system-known existing partner ID
        
        // Get initial partner list
        const initialPartners = await this.client.getPartnerList();
        console.log(`Initial partners count: ${initialPartners.partners.length}`);
        
        // Check if partner already exists
        const existingPartner = initialPartners.partners.find(p => p.base_info.unit_id === unitId && p.state === 2);
        if (existingPartner) { // State 2 indicates unlocked
            console.log(`Partner ${unitId} already exists, will be treated as success`);
        }
        
        // Execute GM command to add partner
        const response = await this.client.gmCommand('add_partner', [unitId.toString()]);
        assert(response.result === 'success', 'Add partner should succeed');
        console.log(`Add partner response: ${JSON.stringify(response)}`);
        
        // Get updated partner list
        const updatedPartners = await this.client.getPartnerList();
        console.log(`Updated partners count: ${updatedPartners.partners.length}`);
        
        // Regardless, verify partner exists and attributes are correct
        const newPartner = updatedPartners.partners.find(p => p.base_info.unit_id === unitId && p.state === 2);
        assert(newPartner, 'Partner should exist and be unlocked');
        assert(newPartner.base_info.level >= 1, 'Partner should have level >= 1');
        
        return true; // Test success
    }

    async testAddFragments() {
        console.log('\nTesting add partner fragments command...');
        
        // Use valid partner fragment ID
        const fragmentId = 5301; // Ensure this is a valid partner fragment ID
        
        // Get initial bag state
        const bagResponse = await this.client.getBagInfo();
        const mainBag = bagResponse.bags.find(bag => bag.bag_type === 1);
        const initialFragments = mainBag.items.filter(item => item.item_id === fragmentId);
        const initialCount = initialFragments.reduce((sum, item) => sum + item.count, 0);
        
        // Execute GM command to add fragments
        const response = await this.client.gmCommand('add_fragments', [fragmentId.toString(), '100']);
        assert(response.result === 'success', 'Add fragments should succeed');
        
        // Get updated bag
        const updatedBagResponse = await this.client.getBagInfo();
        const updatedMainBag = updatedBagResponse.bags.find(bag => bag.bag_type === 1);
        const updatedFragments = updatedMainBag.items.filter(item => item.item_id === fragmentId);
        const updatedCount = updatedFragments.reduce((sum, item) => sum + item.count, 0);
        
        // Verify fragment quantity increased
        assert.strictEqual(updatedCount - initialCount, 100, 'Should add correct amount of fragments');
    }

    async testSetPartnerLevel() {
        console.log('\nTesting set partner level command...');
        
        // 使用有效的伙伴ID
        const unitId = 4301; // 使用系统中已知存在的伙伴ID
        
        // 获取初始伙伴列表，检查伙伴是否存在
        let partners = await this.client.getPartnerList();
        console.log(`Got ${partners.partners.length} partners`);
        
        // 打印所有伙伴的ID以便调试
        console.log("All partners:");
        partners.partners.forEach((p, index) => {
            console.log(`Partner ${index}: unit_id=${p.base_info ? p.base_info.unit_id : 'undefined'}, state=${p.state}, partner_id=${p.base_info ? p.base_info.partner_id : 'undefined'}`);
            console.log(`Type of unit_id: ${p.base_info ? typeof p.base_info.unit_id : 'undefined'}`);
        });
        
        console.log(`Looking for partner with unit_id=${unitId} and state=2`);
        
        // 查找已解锁的伙伴 - 使用number类型进行比较
        let partner = partners.partners.find(p => {
            if (!p.base_info) return false;
            return Number(p.base_info.unit_id) === Number(unitId) && p.state === 2;
        });
        
        // 如果伙伴不存在，先添加一个
        if (!partner) {
            console.log(`Partner ${unitId} doesn't exist, adding it first`);
            const addResponse = await this.client.gmCommand('add_partner', [unitId.toString()]);
            assert(addResponse.result === 'success', 'Add partner should succeed');
            
            // 重新获取伙伴列表
            partners = await this.client.getPartnerList();
            
            // 获取更新后的伙伴数据，使用number类型进行比较
            partner = partners.partners.find(p => {
                if (!p.base_info) return false;
                return Number(p.base_info.unit_id) === Number(unitId) && p.state === 2;
            });
            
            if (!partner) {
                console.log("Failed to find partner after adding. Detailed partner list:");
                partners.partners.forEach((p, index) => {
                    console.log(`Partner ${index}: ${JSON.stringify(p.base_info)}, state=${p.state}`);
                });
            }
        } else {
            console.log(`Partner ${unitId} already exists, will continue with level setting`);
        }
        
        // 检查我们是否找到了伙伴
        if (!partner) {
            // 如果没找到伙伴，尝试使用第一个已解锁的伙伴
            partner = partners.partners.find(p => p.state === 2);
            
            if (partner) {
                console.log(`Couldn't find specific partner ${unitId}, using first unlocked partner with unit_id: ${partner.base_info.unit_id}`);
            } else {
                assert.fail(`No unlocked partner found in the system. Cannot proceed with test.`);
                return false;
            }
        }
        
        // 解包partner_id (确保它是一个有效的数值)
        const partnerId = partner.base_info.partner_id;
        console.log(`Using partner: unit_id=${partner.base_info.unit_id}, partner_id=${partnerId}, current level=${partner.base_info.level}`);
        
        // 执行GM命令设置等级
        const targetLevel = 50;
        const response = await this.client.gmCommand('set_partner_level', [partnerId.toString(), targetLevel.toString()]);
        assert(response.result === 'success', 'Set partner level should succeed');
        
        // 获取更新后的伙伴列表
        const updatedPartners = await this.client.getPartnerList();
        const updatedPartner = updatedPartners.partners.find(p => {
            if (!p.base_info) return false;
            return String(p.base_info.partner_id) === String(partnerId);
        });
        
        // 验证找到了更新后的伙伴
        assert(updatedPartner, `Updated partner with partner_id=${partnerId} not found`);
        
        // 验证等级设置成功
        assert.strictEqual(updatedPartner.base_info.level, targetLevel, `Partner level should be set to ${targetLevel}`);
        console.log(`Successfully set partner level to ${targetLevel}`);
        
        return true; // 测试成功
    }

    async testSetPartnerStar() {
        console.log('\nTesting set partner star command...');
        
        // 使用有效的伙伴ID
        const unitId = 4301; // 使用系统中已知存在的伙伴ID
        
        // 获取初始伙伴列表，检查伙伴是否存在
        let partners = await this.client.getPartnerList();
        console.log(`Got ${partners.partners.length} partners`);
        
        // 打印所有伙伴的ID以便调试
        console.log("All partners:");
        partners.partners.forEach((p, index) => {
            console.log(`Partner ${index}: unit_id=${p.base_info ? p.base_info.unit_id : 'undefined'}, state=${p.state}, partner_id=${p.base_info ? p.base_info.partner_id : 'undefined'}`);
        });
        
        console.log(`Looking for partner with unit_id=${unitId} and state=2`);
        
        // 查找已解锁的伙伴 - 使用number类型进行比较
        let partner = partners.partners.find(p => {
            if (!p.base_info) return false;
            return Number(p.base_info.unit_id) === Number(unitId) && p.state === 2;
        });
        
        // 如果伙伴不存在，先添加一个
        if (!partner) {
            console.log(`Partner ${unitId} doesn't exist, adding it first`);
            const addResponse = await this.client.gmCommand('add_partner', [unitId.toString()]);
            assert(addResponse.result === 'success', 'Add partner should succeed');
            
            // 重新获取伙伴列表
            partners = await this.client.getPartnerList();
            
            // 获取更新后的伙伴数据，使用number类型进行比较
            partner = partners.partners.find(p => {
                if (!p.base_info) return false;
                return Number(p.base_info.unit_id) === Number(unitId) && p.state === 2;
            });
            
            if (!partner) {
                console.log("Failed to find partner after adding. Detailed partner list:");
                partners.partners.forEach((p, index) => {
                    console.log(`Partner ${index}: ${JSON.stringify(p.base_info)}, state=${p.state}`);
                });
            }
        } else {
            console.log(`Partner ${unitId} already exists, will continue with star setting`);
        }
        
        // 检查我们是否找到了伙伴
        if (!partner) {
            // 如果没找到伙伴，尝试使用第一个已解锁的伙伴
            partner = partners.partners.find(p => p.state === 2);
            
            if (partner) {
                console.log(`Couldn't find specific partner ${unitId}, using first unlocked partner with unit_id: ${partner.base_info.unit_id}`);
            } else {
                assert.fail(`No unlocked partner found in the system. Cannot proceed with test.`);
                return false;
            }
        }
        
        // 解包partner_id (确保它是一个有效的数值)
        const partnerId = partner.base_info.partner_id;
        console.log(`Using partner: unit_id=${partner.base_info.unit_id}, partner_id=${partnerId}, current star=${partner.base_info.star || 0}`);
        
        // 执行GM命令设置星级
        const targetStar = 5;
        const response = await this.client.gmCommand('set_partner_star', [partnerId.toString(), targetStar.toString()]);
        assert(response.result === 'success', 'Set partner star should succeed');
        
        // 获取更新后的伙伴列表
        const updatedPartners = await this.client.getPartnerList();
        const updatedPartner = updatedPartners.partners.find(p => {
            if (!p.base_info) return false;
            return String(p.base_info.partner_id) === String(partnerId);
        });
        
        // 验证找到了更新后的伙伴
        assert(updatedPartner, `Updated partner with partner_id=${partnerId} not found`);
        
        // 验证星级设置成功
        assert.strictEqual(updatedPartner.base_info.star, targetStar, `Partner star should be set to ${targetStar}`);
        console.log(`Successfully set partner star to ${targetStar}`);
        
        return true; // 测试成功
    }

    async testDiceNum() {
        console.log('\nTesting dice_num command...');
        
        // 测试1：设置固定骰子点数
        let response = await this.client.gmCommand('dice_num', ['3']);
        assert(response.result === 'success', 'Setting dice number should succeed');
        console.log('Set dice number result:', response);
        
        // 测试2：设置另一个固定骰子点数
        response = await this.client.gmCommand('dice_num', ['6']);
        assert(response.result === 'success', 'Setting another dice number should succeed');
        console.log('Set another dice number result:', response);
        
        // 测试3：取消固定骰子点数
        response = await this.client.gmCommand('dice_num', ['7']); // 超出1-6范围会取消设置
        assert(response.result === 'success', 'Canceling dice number should succeed');
        console.log('Cancel dice number result:', response);
        
        // 测试4：设置边界值（最小值）
        response = await this.client.gmCommand('dice_num', ['1']);
        assert(response.result === 'success', 'Setting minimum dice number should succeed');
        console.log('Set minimum dice number result:', response);
        
        // 测试5：再次取消固定骰子点数
        response = await this.client.gmCommand('dice_num', ['0']); // 低于1也会取消设置
        assert(response.result === 'success', 'Canceling dice number again should succeed');
        console.log('Cancel dice number again result:', response);
        
        return true;
    }
}

module.exports = GMCommandTest;