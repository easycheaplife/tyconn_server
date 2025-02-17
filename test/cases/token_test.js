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
            // 设置服务器信息
            this.client.serverInfo = {
                protocol: config.protocol || 'ws:',  // 从配置获取协议
                host: gateInfo.host,
                port: gateInfo.port
            };
            await this.client.connect();
            
            // 测试1: 有效token
            console.log('Testing valid token...');
            let response = await this.client.sendRequest('C2G_HEARTBEAT_REQUEST', {
                token: token
            });
            console.log('Valid token response:', response);
            console.log('Valid token payload:', response.payload);
            if (response.payload) {
                console.log('Payload as buffer:', response.payload);
                console.log('Payload as hex:', response.payload.toString('hex'));
                try {
                    console.log('Payload as JSON:', JSON.parse(response.payload.toString()));
                } catch (e) {
                    console.log('Payload is not JSON');
                }
            }

            // 检查响应中的所有字段
            assert(response, 'Response should not be null');
            assert.strictEqual(response.errorCode || response.error_code, 0, 'Valid token should succeed');
            assert(response.session.timestamp, 'Response should contain timestamp');

            // 测试2: 过期token
            console.log('\nTesting expired token...');
            const expiredToken = jwt.sign({
                account: 'test_account',
                exp: Math.floor(Date.now() / 1000) - 3600 // 1小时前过期
            }, config.jwtSecret || 'your_secret_key');  // 使用配置中的密钥

            response = await this.client.sendRequest('C2G_HEARTBEAT_REQUEST', {
                token: expiredToken
            });
            console.log('Expired token response:', response);
            console.log('Expired token payload:', response.payload);
            assert.strictEqual(response.errorCode || response.error_code, 2, 'Expired token should fail');

            // 测试3: 无效token格式
            console.log('Testing invalid token format...');
            response = await this.client.sendRequest('C2G_HEARTBEAT_REQUEST', {
                token: 'invalid.token.format'
            });
            console.log('Invalid format response:', response);  // 添加日志
            assert.strictEqual(response.errorCode || response.error_code, 2, 'Invalid token format should fail');

            // 测试4: 缺少token
            console.log('Testing missing token...');
            response = await this.client.sendRequest('C2G_HEARTBEAT_REQUEST', {});
            console.log('Missing token response:', response);  // 添加日志
            assert.strictEqual(response.errorCode || response.error_code, 2, 'Missing token should fail');

            // 测试5: 错误密钥签名的token
            console.log('Testing wrong secret token...');
            const wrongToken = jwt.sign({
                account: 'test_account',
                exp: Math.floor(Date.now() / 1000) + 3600
            }, 'wrong_secret');

            response = await this.client.sendRequest('C2G_HEARTBEAT_REQUEST', {
                token: wrongToken
            });
            console.log('Wrong secret response:', response);  // 添加日志
            assert.strictEqual(response.errorCode || response.error_code, 2, 'Wrong secret token should fail');

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