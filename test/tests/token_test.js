const jwt = require('jsonwebtoken');
const config = require('../config/config');
const WSClient = require('../lib/ws_client');
const HeartbeatBuilder = require('../builders/heartbeat_builder');
const ResponseHandler = require('../lib/response_handler');
const readline = require('readline');

class TokenTest {
    constructor(root, ws_addr, ws_port) {
        this.root = root;
        this.ws_addr = ws_addr;
        this.ws_port = ws_port;
        this.wsClient = null;
        this.responseHandler = new ResponseHandler(root);
    }

    async run() {
        console.log('\n开始Token测试...');
        
        // 创建用户输入接口
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout,
            terminal: true  // 确保在终端模式下运行
        });

        // 确保输出立即显示
        process.stdout.write('\n请选择测试类型 (3秒后默认正常测试):\n');
        process.stdout.write('1. 正常测试\n');
        process.stdout.write('2. 无效token测试\n');
        process.stdout.write('3. 过期token测试\n');
        process.stdout.write('4. 其他账号token测试\n');

        try {
            // 提示用户选择测试类型
            const choice = await this.waitForInput(rl, 3000);
            const testType = choice || '1';  // 默认选择正常测试

            // 连接服务器
            const wsUrl = `ws://${this.ws_addr}:${this.ws_port}`;
            this.wsClient = new WSClient(wsUrl);
            await this.wsClient.connect();

            // 根据选择执行不同的测试
            switch (testType) {
                case '1':
                    await this.testNormalToken();
                    break;
                case '2':
                    await this.testInvalidToken();
                    break;
                case '3':
                    await this.testExpiredToken();
                    break;
                case '4':
                    await this.testOtherAccountToken();
                    break;
                default:
                    console.log('未知的测试类型，执行正常测试');
                    await this.testNormalToken();
            }

        } catch (error) {
            console.error('Token测试失败:', error);
        } finally {
            rl.close();
            if (this.wsClient) {
                this.wsClient.close();
            }
        }
    }

    async waitForInput(rl, timeout) {
        return new Promise((resolve) => {
            const timer = setTimeout(() => {
                console.log('\n等待超时，使用默认选项');
                resolve(null);
            }, timeout);

            rl.question('请输入选项 (1-4): ', (answer) => {
                clearTimeout(timer);
                resolve(answer);
            });
        });
    }

    async testNormalToken() {
        console.log('\n执行正常token测试...');
        const request = HeartbeatBuilder.build(this.root, global.token);
        this.wsClient.send(request);
        const response = await this.wsClient.waitForMessage();
        this.responseHandler.handleHeartbeatResponse(response);
    }

    async testInvalidToken() {
        try {
            console.log('\n执行无效token测试...');
            const request = HeartbeatBuilder.build(this.root, 'invalid_token');
            this.wsClient.send(request);
            const response = await this.wsClient.waitForMessage();
            const result = this.responseHandler.handleHeartbeatResponse(response);
            
            // 验证测试结果
            if (result === null) {
                console.log('无效token测试通过: 服务器正确拒绝了无效token');
            } else {
                console.log('无效token测试失败: 服务器接受了无效token');
            }
        } catch (error) {
            console.error('无效token测试出错:', error);
        }
    }

    async testExpiredToken() {
        try {
            console.log('\n执行过期token测试...');
            if (!config.jwtSecret) {
                throw new Error('JWT密钥未配置，请在config.js中设置jwtSecret');
            }

            const expiredToken = jwt.sign(
                { 
                    account: 'test',
                    exp: Math.floor(Date.now() / 1000) - 3600, // 1小时前过期
                    iat: Math.floor(Date.now() / 1000) - 7200, // 签发时间设为2小时前
                    iss: 'tyconn_login'  // 添加签发者信息，需要和服务器端一致
                },
                config.jwtSecret
            );

            const request = HeartbeatBuilder.build(this.root, expiredToken);
            this.wsClient.send(request);
            const response = await this.wsClient.waitForMessage();
            const result = this.responseHandler.handleHeartbeatResponse(response);
            
            // 验证测试结果
            if (result === null) {
                console.log('过期token测试通过: 服务器正确拒绝了过期token');
            } else {
                console.log('过期token测试失败: 服务器接受了过期token');
            }
        } catch (error) {
            console.error('过期token测试出错:', error);
        }
    }

    async testOtherAccountToken() {
        try {
            console.log('\n执行其他账号token测试...');
            if (!config.jwtSecret) {
                throw new Error('JWT密钥未配置，请在config.js中设置jwtSecret');
            }

            const otherToken = jwt.sign(
                { 
                    account: 'other_account',
                    exp: Math.floor(Date.now() / 1000) + 3600,
                    iat: Math.floor(Date.now() / 1000),
                    iss: 'tyconn_login'
                },
                config.jwtSecret
            );

            const request = HeartbeatBuilder.build(this.root, otherToken);
            this.wsClient.send(request);
            const response = await this.wsClient.waitForMessage();
            const result = this.responseHandler.handleHeartbeatResponse(response);
            
            // 验证测试结果
            if (result === null) {
                console.log('其他账号token测试通过: 服务器正确拒绝了其他账号的token');
            } else {
                console.log('其他账号token测试失败: 服务器接受了其他账号的token');
            }
        } catch (error) {
            console.error('其他账号token测试出错:', error);
        }
    }
}

module.exports = TokenTest; 