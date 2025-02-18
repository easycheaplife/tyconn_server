const BaseTest = require('../lib/base_test');
const assert = require('assert');

class LoginTest extends BaseTest {
    constructor() {
        super('Login Test');
    }

    async test() {
        try {
            let loginResponse;
            // 测试1: 验证登录响应
            console.log('\nTesting login response...');
            loginResponse = await this.loginClient.login('test', '123456');
            assert(loginResponse, 'Should receive login response');
            assert(loginResponse.token, 'Should receive token');
            assert(loginResponse.gateInfo, 'Should receive gate server info');

            // 测试2: 验证 token 有效性
            console.log('\nTesting token validity...');
            const decodedToken = this.loginClient.decodeToken(loginResponse.token);
            assert(decodedToken, 'Should be able to decode token');
            assert(decodedToken.account === 'test', 'Token should contain correct account');
            assert(decodedToken.exp > Date.now()/1000, 'Token should not be expired');
            assert(decodedToken.iss === 'tyconn_login', 'Token should have correct issuer');

            // 测试3: 验证错误登录
            console.log('\nTesting invalid login...');
            try {
                await this.loginClient.login('test', 'wrong_password');
                assert.fail('Should not login with wrong password');
            } catch (error) {
                assert(error, 'Should throw error for wrong password');
            }

            // 测试4: 验证非法账号
            console.log('\nTesting invalid account...');
            try {
                await this.loginClient.login('', '123456');
                assert.fail('Should not login with empty account');
            } catch (error) {
                assert(error, 'Should throw error for empty account');
            }

            // 测试5: 验证错误的版本号
            console.log('\nTesting invalid version...');
            try {
                await this.loginClient.login('test', '123456', 'invalid_version');
                assert.fail('Should not login with invalid version');
            } catch (error) {
                assert(error, 'Should throw error for invalid version');
            }

            return true;
        } catch (error) {
            console.error('Login test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        } finally {
            await this.loginClient.close();
        }
    }
}

module.exports = LoginTest; 