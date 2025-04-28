const BaseTest = require('../../lib/base_test');
const assert = require('assert');

class LoginGameTest extends BaseTest {
    constructor() {
        super('Login Game Test');
    }

    async test() {
        try {
            // 测试1: 游戏登录
            console.log('\nTesting game login...');
            let response = await this.client.loginGame();
            
            // 验证响应
            assert(response, 'Response should not be null');
            assert(response.user, 'User info should be present');
            
            // 验证必要字段
            const requiredFields = ['user_id', 'username', 'level', 'exp', 'gold', 'vip_level', 'create_time', 'login_time'];
            for (const field of requiredFields) {
                assert(field in response.user, `Missing required field: ${field}`);
            }

            // 验证字段类型和默认值
            assert(response.user.user_id && typeof response.user.user_id.low === 'number', 'User ID should be a Long');
            assert.strictEqual(typeof response.user.username, 'string', 'Username should be a string');
            assert.strictEqual(typeof response.user.level, 'number', 'Level should be a number');
            assert(response.user.exp && typeof response.user.exp.low === 'number', 'Exp should be a Long');
            assert(response.user.gold && typeof response.user.gold.low === 'number', 'Gold should be a Long');
            assert.strictEqual(typeof response.user.vip_level, 'number', 'VIP level should be a number');
            assert(response.user.create_time && response.user.create_time.low > 0, 'Create time should be valid');
            assert(response.user.login_time && response.user.login_time.low > 0, 'Login time should be valid');

            // 保存第一次响应的用户信息
            const firstUser = response.user;
            
            // 验证背包信息
            assert(Array.isArray(response.bags), 'Bags should be an array');
            if (response.bags.length > 0) {
                const bag = response.bags[0];
                assert('bag_type' in bag, 'Bag should have bag_type');
                assert('size' in bag, 'Bag should have size');
                assert(Array.isArray(bag.items), 'Bag items should be an array');
            }
            
            // 验证资源信息
            assert(Array.isArray(response.resources), 'Resources should be an array');
            if (response.resources.length > 0) {
                const resource = response.resources[0];
                assert('type' in resource, 'Resource should have type');
                assert('amount' in resource, 'Resource should have amount');
            }

            // 验证属性信息
            assert(Array.isArray(response.property_info), 'Property info should be an array');
            if (response.property_info.length > 0) {
                // 检查至少有一个属性值
                assert(response.property_info.length >= 1, 'Should have at least one property');
                
                // 验证每个属性都有必要的字段
                for (const prop of response.property_info) {
                    assert('value' in prop, 'Property should have value field');
                    assert(typeof prop.value === 'number', 'Property value should be a number');
                }
                
                // 打印值以便查看
                const propValues = response.property_info.map(p => p.value);
                console.log('Property values:', propValues);
            }
            
            // 验证服务器时间
            assert(response.server_time && response.server_time.low > 0, 'Server time should be valid');

            // 测试2: 缓存验证 (连续请求)
            console.log('\nTesting login game cache (consecutive requests)...');
            const secondResponse = await this.client.loginGame();

            // 创建用户副本进行比较，忽略 login_time 字段
            const firstUserCompare = {...firstUser};
            const secondUserCompare = {...secondResponse.user};

            // 忽略 login_time 字段，因为每次登录时都会更新
            delete firstUserCompare.login_time;
            delete secondUserCompare.login_time;

            assert.deepStrictEqual(firstUserCompare, secondUserCompare, 'Cached user info (except login_time) should match');
            assert.strictEqual(secondResponse.is_new_user, false, 'Second request should not be marked as new user');

            // 测试3: 缓存验证 (断开重连)
            console.log('\nTesting login game cache (reconnect)...');
            await this.client.close();
            await this.client.connect();
            const thirdResponse = await this.client.loginGame();

            // 创建用户副本进行比较，忽略 login_time 字段
            const thirdUserCompare = {...thirdResponse.user};
            delete thirdUserCompare.login_time;

            assert.deepStrictEqual(firstUserCompare, thirdUserCompare, 'User info (except login_time) should persist after reconnect');
            assert.strictEqual(thirdResponse.is_new_user, false, 'Reconnect request should not be marked as new user');

            // 测试4: 新用户标志和初始化
            if (response.is_new_user) {
                console.log('\nTesting new user initialization...');
                // 验证新用户默认值
                assert.strictEqual(response.user.level, 1, 'New user should start at level 1');
                assert.strictEqual(response.user.exp.low, 0, 'New user should start with 0 exp');
                assert.strictEqual(response.user.vip_level, 0, 'New user should start at VIP level 0');

                // 验证新用户的背包初始化
                assert(response.bags && response.bags.length > 0, 'New user should have bags');
                
                // 检查主背包
                const mainBag = response.bags.find(bag => bag.bag_type === 1); // 1 = MAIN
                assert(mainBag, 'Should have main bag');
                
                // 验证初始资源
                const goldResource = response.resources.find(r => r.type === 1); // RESOURCE_TYPE_GOLD
                if (goldResource) {
                    assert(goldResource.amount > 0, 'New user should have initial gold');
                }
            }

            return true;
        } catch (error) {
            console.error('Login game test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}

module.exports = LoginGameTest; 