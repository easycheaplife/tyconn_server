const assert = require('assert');
const BaseTest = require('../lib/base_test');

class GMCommandTest extends BaseTest {
    constructor() {
        super('GM Command Test');
    }

    async test() {
        try {
            // 1. 测试获取背包信息
            await this.testGMCommand();

            return true;
        } catch (err) {
            console.error('GM command test failed:', err);
            return false;
        }
    }

    async testGMCommand() {
        // 1. 添加物品
        let response = await this.client.gm_command('add_item', ['1001', '100']);
        assert.strictEqual(response.result, 'success');

        // 验证背包
        let bagInfo = await this.client.getBagInfo();
        let item = bagInfo.bags[0].items.find(i => i.item_id === 1001);
        assert.strictEqual(item.count, 1000);

        // 2. 删除物品
        response = await this.client.gm_command('del_item', ['1001', '50']);
        assert.strictEqual(response.result, 'success');

        // 验证背包
        bagInfo = await this.client.getBagInfo();
        item = bagInfo.bags[0].items.find(i => i.item_id === 1001);
        assert.strictEqual(item.count, 50);

        // 3. 清空背包
        response = await this.client.gm_command('clear_bag', []);
        assert.strictEqual(response.result, 'success');    

        // 验证背包
        bagInfo = await this.client.getBagInfo();
        assert.strictEqual(bagInfo.bags[0].items.length, 0);

        // 4. 设置等级
        response = await this.client.gm_command('set_level', ['99']);
        assert.strictEqual(response.result, 'success');

        // 5. 测试错误情况
        try {
            await this.client.gm_command('invalid_command', []);
            assert.fail('Should throw error for invalid command');
        } catch (err) {
            assert(err.message.includes('GM指令执行失败'));
        }

        try {
            await this.client.gm_command('add_item', ['invalid']);
            assert.fail('Should throw error for invalid params');
        } catch (err) {
            assert(err.message.includes('参数不足'));
        }
    }
}

module.exports = GMCommandTest;