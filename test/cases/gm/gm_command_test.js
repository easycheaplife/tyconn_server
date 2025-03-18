/**
 * GM命令测试模块
 * 
 * 用途：
 * 此模块用于测试游戏中的GM命令功能，包括物品添加删除、等级设置、伙伴操作等功能。
 * 
 * 运行方式：
 * 1. 运行单个测试：
 *    node test/run_test.js -t gm_command_test <测试名称>
 *    例如：node test/run_test.js -t gm_command_test add_item
 * 
 * 2. 直接执行GM命令：
 *    node test/run_test.js -t gm_command <命令> <参数1> <参数2> ...
 *    例如：node test/run_test.js -t gm_command add_item 1001 100
 * 
 * 3. 运行所有测试：
 *    node test/run_test.js -t gm_command_test
 * 
 * 可用测试用例：
 * - add_item：测试添加物品功能
 * - delete_item：测试删除物品功能
 * - set_level：测试设置角色等级功能
 * - error_cases：测试错误处理
 * - clear_bag：测试清空背包功能
 * - add_partner：测试添加伙伴功能
 * - add_fragments：测试添加伙伴碎片功能
 * - set_partner_level：测试设置伙伴等级功能
 * - set_partner_star：测试设置伙伴星级功能
 * 
 * 伙伴命令说明：
 * - add_partner <伙伴ID>：添加指定ID的伙伴，如果已存在则返回现有伙伴
 * - add_fragments <碎片ID> <数量>：添加指定数量的伙伴碎片
 * - set_partner_level <伙伴实例ID> <等级>：设置指定伙伴的等级
 * - set_partner_star <伙伴实例ID> <星级>：设置指定伙伴的星级
 * 
 * 注意：
 * 1. 伙伴ID指的是配置表中的unitId，而伙伴实例ID是创建后的partnerId
 * 2. 测试会自动处理伙伴不存在的情况，会先尝试添加伙伴再进行操作
 * 3. 如果指定伙伴不可用，测试会尝试使用第一个已解锁的伙伴
 */

const assert = require('assert');
const BaseTest = require('../../lib/base_test');

class GMCommandTest extends BaseTest {
    constructor() {
        super('GM Command Test');
        // 定义可用的测试用例
        this.testCases = {
            'add_item': this.testAddItem.bind(this),
            'delete_item': this.testDeleteItem.bind(this),
            'set_level': this.testSetLevel.bind(this),
            'error_cases': this.testErrorCases.bind(this),
            'clear_bag': this.testClearBag.bind(this),
            'add_partner': this.testAddPartner.bind(this),
            'add_fragments': this.testAddFragments.bind(this),
            'set_partner_level': this.testSetPartnerLevel.bind(this),
            'set_partner_star': this.testSetPartnerStar.bind(this)
        };
    }

    async test() {
        try {
            // 查找 -t 参数后的第一个参数作为测试用例名
            const args = process.argv;
            const tIndex = args.indexOf('-t');
            
            // 检查是否为直接执行GM命令的格式
            // 例如: node test/run_test.js -t gm_command additem 1005 10000
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
                // 执行指定测试
                console.log(`Running test case: ${testCase}`);
                await this.testCases[testCase]();
            } else if (testCase) {
                console.error(`Unknown test case: ${testCase}`);
                console.log('Available test cases:', Object.keys(this.testCases).join(', '));
                throw new Error('Invalid test case');
            } else {
                // 执行所有测试
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
        
        // 先获取背包初始状态
        const bagResponse = await this.client.getBagInfo();
        const mainBag = bagResponse.bags.find(bag => bag.bag_type === 1);
        const initialItems = mainBag.items;
        
        // 执行GM命令添加物品
        const response = await this.client.gmCommand('add_item', ['1001', '100']);
        assert(response.result === 'success', 'Add item should succeed');
        
        // 获取更新后的背包
        const updatedBagResponse = await this.client.getBagInfo();
        const updatedMainBag = updatedBagResponse.bags.find(bag => bag.bag_type === 1);
        
        // 检查物品数量
        const totalCount = updatedMainBag.items
            .filter(item => item.item_id === 1001)
            .reduce((sum, item) => sum + item.count, 0);
            
        // 验证总数量正确
        assert.strictEqual(
            totalCount - (initialItems.filter(i => i.item_id === 1001)
                .reduce((sum, i) => sum + i.count, 0)), 
            100, 
            'Should add correct amount of items'
        );
    }

    async testDeleteItem() {
        console.log('\nTesting delete item command...');
        
        // 1. 先添加物品
        let response = await this.client.gmCommand('add_item', ['1001', '100']);
        assert.strictEqual(response.result, 'success');

        // 验证添加成功
        let bagInfo = await this.client.getBagInfo();
        let initialCount = bagInfo.bags[0].items
            .filter(i => i.item_id === 1001)
            .reduce((sum, i) => sum + i.count, 0);
        
        // 2. 删除物品
        response = await this.client.gmCommand('del_item', ['1001', '50']);
        assert.strictEqual(response.result, 'success');

        // 3. 验证背包
        bagInfo = await this.client.getBagInfo();
        const finalCount = bagInfo.bags[0].items
            .filter(i => i.item_id === 1001)
            .reduce((sum, i) => sum + i.count, 0);

        // 验证删除的数量正确
        assert.strictEqual(
            initialCount - finalCount,
            50,
            'Should delete correct amount of items'
        );
    }

    async testSetLevel() {
        console.log('\nTesting set level command...');
        
        // 设置等级
        const response = await this.client.gmCommand('set_level', ['99']);
        assert.strictEqual(response.result, 'success');
    }

    async testErrorCases() {
        console.log('\nTesting error cases...');
        
        // 测试无效命令
        try {
            await this.client.gmCommand('invalid_command', []);
            assert.fail('Should throw error for invalid command');
        } catch (err) {
            assert(err.errorCode === this.client.protoHelper.ErrorCode.ERROR_CODE_GM_COMMAND_FAILED);
        }

        // 测试无效参数
        try {
            await this.client.gmCommand('add_item', ['invalid']);
            assert.fail('Should throw error for invalid params');
        } catch (err) {
            assert(err.errorCode === this.client.protoHelper.ErrorCode.ERROR_CODE_GM_COMMAND_FAILED);
        }
    }

    async testClearBag() {
        console.log('\nTesting clear bag command...');
        
        // 执行清空背包命令
        const response = await this.client.gmCommand('clear_bag', ['1']);
        assert(response.result === 'success', "清空背包失败");
        
        // 获取背包信息验证是否成功
        const bagInfo = await this.client.getBagInfo();
        const mainBag = bagInfo.bags.find(bag => bag.bag_type === this.client.protoHelper.BagType.BAG_TYPE_MAIN);
        assert(mainBag.items.length === 0, "背包未清空");
        
        return true;
    }

    async testAddPartner() {
        console.log('\nTesting add partner command...');
        
        // 使用有效的伙伴ID（从配置中选择一个有效的伙伴单位ID）
        const unitId = 4301; // 使用系统中已知存在的伙伴ID
        
        // 获取初始伙伴列表
        const initialPartners = await this.client.getPartnerList();
        console.log(`Initial partners count: ${initialPartners.partners.length}`);
        
        // 检查伙伴是否已存在
        const existingPartner = initialPartners.partners.find(p => p.base_info.unit_id === unitId && p.state === 2);
        if (existingPartner) { // 状态2表示已解锁
            console.log(`Partner ${unitId} already exists, will be treated as success`);
        }
        
        // 执行GM命令添加伙伴
        const response = await this.client.gmCommand('add_partner', [unitId.toString()]);
        assert(response.result === 'success', 'Add partner should succeed');
        console.log(`Add partner response: ${JSON.stringify(response)}`);
        
        // 获取更新后的伙伴列表
        const updatedPartners = await this.client.getPartnerList();
        console.log(`Updated partners count: ${updatedPartners.partners.length}`);
        
        // 无论如何，验证伙伴存在且属性正确
        const newPartner = updatedPartners.partners.find(p => p.base_info.unit_id === unitId && p.state === 2);
        assert(newPartner, 'Partner should exist and be unlocked');
        assert(newPartner.base_info.level >= 1, 'Partner should have level >= 1');
        
        return true; // 测试成功
    }

    async testAddFragments() {
        console.log('\nTesting add partner fragments command...');
        
        // 使用有效的伙伴碎片ID
        const fragmentId = 5301; // 确保这是一个有效的伙伴碎片ID
        
        // 获取初始背包状态
        const bagResponse = await this.client.getBagInfo();
        const mainBag = bagResponse.bags.find(bag => bag.bag_type === 1);
        const initialFragments = mainBag.items.filter(item => item.item_id === fragmentId);
        const initialCount = initialFragments.reduce((sum, item) => sum + item.count, 0);
        
        // 执行GM命令添加碎片
        const response = await this.client.gmCommand('add_fragments', [fragmentId.toString(), '100']);
        assert(response.result === 'success', 'Add fragments should succeed');
        
        // 获取更新后的背包
        const updatedBagResponse = await this.client.getBagInfo();
        const updatedMainBag = updatedBagResponse.bags.find(bag => bag.bag_type === 1);
        const updatedFragments = updatedMainBag.items.filter(item => item.item_id === fragmentId);
        const updatedCount = updatedFragments.reduce((sum, item) => sum + item.count, 0);
        
        // 验证碎片数量增加
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
}

module.exports = GMCommandTest;