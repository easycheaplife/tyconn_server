const BaseTest = require('../lib/base_test');
const jwt = require('jsonwebtoken');
const GameClient = require('../lib/game_client');
const config = require('../config/config');  // 添加配置引用
const assert = require('assert');  // 添加 assert 模块

class TokenTest extends BaseTest {
    constructor() {
        super('Token Test');
    }

    async run(token, gateInfo) {
        try {
            // 创建并连接游戏客户端
            this.client = new GameClient();
            this.client.serverInfo = {
                protocol: config.protocol || 'ws:',
                host: gateInfo.host,
                port: gateInfo.port
            };
            await this.client.connect();
            
            // 测试1: 有效token
            console.log('Testing valid token...');
            let response = await this.client.sendHeartbeat(token);
            assert(response, 'Response should not be null');
            assert.strictEqual(response.timestamp > 0, true, 'Response should contain timestamp');

            // 测试2: 无效token格式
            console.log('\nTesting invalid token format...');
            try {
                await this.client.sendHeartbeat('invalid.token.format');
                assert.fail('Invalid token format should fail');
            } catch (error) {
                assert.strictEqual(error.response.errorCode, this.client.protoHelper.ErrorCode.ERROR_CODE_TOKEN_INVALID, 'Should have invalid token error code');
            }

            // 测试3: 缺少token
            console.log('\nTesting missing token...');
            try {
                await this.client.sendHeartbeat('');
                assert.fail('Missing token should fail');
            } catch (error) {
                assert.strictEqual(error.response.errorCode, this.client.protoHelper.ErrorCode.ERROR_CODE_TOKEN_INVALID, 'Should have invalid token error code');
            }

            // 测试4: 错误密钥签名的token
            console.log('\nTesting wrong secret token...');
            const wrongToken = jwt.sign({
                account: 'test_account',
                exp: Math.floor(Date.now() / 1000) + 3600
            }, 'wrong_secret');

            try {
                await this.client.sendHeartbeat(wrongToken);
                assert.fail('Wrong secret token should fail');
            } catch (error) {
                assert.strictEqual(error.response.errorCode, this.client.protoHelper.ErrorCode.ERROR_CODE_TOKEN_INVALID, 'Should have invalid token error code');
            }

            return true;
        } catch (error) {
            console.log('Test failed: ' + error.message);
            console.log('Error stack:', error.stack);  // 添加堆栈信息
            return false;
        } finally {
            if (this.client) {
                await this.client.close();
            }
        }
    }
}

module.exports = TokenTest; 