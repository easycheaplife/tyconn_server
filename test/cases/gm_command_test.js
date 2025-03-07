const assert = require('assert');
const BaseTest = require('../lib/base_test');

class GMCommandTest extends BaseTest {
    constructor() {
        super('GM Command Test');
        // 定义可用的测试用例
        this.testCases = {
            'add_item': this.testAddItem.bind(this),
            'delete_item': this.testDeleteItem.bind(this),
            'set_level': this.testSetLevel.bind(this),
            'error_cases': this.testErrorCases.bind(this),
            'clear_bag': this.testClearBag.bind(this)
        };
    }

    async test() {
        try {
            // 查找 -t 参数后的第一个参数作为测试用例名
            const args = process.argv;
            const tIndex = args.indexOf('-t');
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
}

module.exports = GMCommandTest;