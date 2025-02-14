const BaseTest = require('../lib/base_test');

class UserInfoTest extends BaseTest {
    constructor() {
        super('User Info Test');
    }

    async test() {
        try {
            // 获取用户信息
            const response = await this.client.getUserInfo();

            // 验证响应
            if (!response || !response.user) {
                console.error('Invalid user info response: missing user data');
                return false;
            }

            // 验证必要字段
            const requiredFields = ['user_id', 'username', 'level', 'create_time', 'login_time'];
            for (const field of requiredFields) {
                if (!(field in response.user)) {
                    console.error(`Missing required field: ${field}`);
                    return false;
                }
            }

            return true;
        } catch (error) {
            console.error('User info test failed:', error);
            return false;
        }
    }
}

module.exports = UserInfoTest; 