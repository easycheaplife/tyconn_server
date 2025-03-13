const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class UserInfoTest extends BaseTest {
    constructor() {
        super('User Info Test');
    }

    async test() {
        try {
            // 测试1: 获取用户信息 (已存在用户)
            console.log('\nTesting existing user info...');
            let response = await this.client.getUserInfo();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(response.user, 'User info should be present');
            
            // 验证必要字段
            const requiredFields = ['user_id', 'username', 'level', 'exp', 'vip_level', 'create_time', 'login_time'];
            for (const field of requiredFields) {
                assert(field in response.user, `Missing required field: ${field}`);
            }

            // 验证字段类型和默认值
            assert(response.user.user_id && typeof response.user.user_id.low === 'number', 'User ID should be a Long');
            assert.strictEqual(typeof response.user.username, 'string', 'Username should be a string');
            assert.strictEqual(typeof response.user.level, 'number', 'Level should be a number');
            assert(response.user.exp && typeof response.user.exp.low === 'number', 'Exp should be a Long');
            assert.strictEqual(typeof response.user.vip_level, 'number', 'VIP level should be a number');
            assert(response.user.create_time && response.user.create_time.low > 0, 'Create time should be valid');
            assert(response.user.login_time && response.user.login_time.low > 0, 'Login time should be valid');

            // 保存第一次响应的用户信息
            const firstUser = response.user;
            
            // 测试2: 缓存验证 (连续请求)
            console.log('\nTesting user info cache (consecutive requests)...');
            const secondResponse = await this.client.getUserInfo();
            assert.deepStrictEqual(firstUser, secondResponse.user, 'Cached user info should match');
            assert(!secondResponse.is_new, 'Second request should not be marked as new user');

            // 测试3: 缓存验证 (断开重连)
            console.log('\nTesting user info cache (reconnect)...');
            await this.client.close();
            await this.client.connect();
            const thirdResponse = await this.client.getUserInfo();
            assert.deepStrictEqual(firstUser, thirdResponse.user, 'User info should persist after reconnect');
            assert(!thirdResponse.is_new, 'Reconnect request should not be marked as new user');

            // 测试4: 新用户标志和初始化
            if (response.is_new) {
                console.log('\nTesting new user initialization...');
                // 验证新用户默认值
                assert.strictEqual(response.user.level, 1, 'New user should start at level 1');
                assert.strictEqual(response.user.exp.low, 0, 'New user should start with 0 exp');
                assert.strictEqual(response.user.vip_level, 0, 'New user should start at VIP level 0');

                // 验证新用户的卡牌初始化
                const cardsResponse = await this.client.getUserCards();
                assert(cardsResponse.cards && cardsResponse.cards.length > 0, 'New user should have initial cards');

                // 验证新用户的物品初始化
                const bagResponse = await this.client.getBagInfo();
                assert(bagResponse.bags && bagResponse.bags.length > 0, 'New user should have bags');

                // 检查主背包中的物品
                console.log(bagResponse.bags);
                const mainBag = bagResponse.bags.find(bag => bag.bag_type === 1); // 1 = MAIN
                assert(mainBag, 'Should have main bag');
                assert(mainBag.items && mainBag.items.length > 0, 'New user should have initial items in main bag');

                // 验证初始物品
                const hasExpPotion = mainBag.items.some(item => 
                    item.item_id === 1001 && item.count === 1000); // 经验药水

                assert(hasExpPotion, 'New user should have initial exp potions');
            }

            // 测试5: 用户名格式
            console.log('\nTesting username format...');
            assert(response.user.username.length > 0, 'Username should not be empty');
            assert(response.user.username.length <= 32, 'Username should not exceed 32 characters');
            // 可以添加更多用户名格式的验证

            return true;
        } catch (error) {
            console.error('User info test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = UserInfoTest; 