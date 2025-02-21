const GameClient = require('./game_client');
const LoginClient = require('./login_client');
const config = require('../config/config');

class BaseTest {
    constructor(name) {
        this.name = name;
        this.loginClient = new LoginClient();
        this.client = new GameClient();
    }

    // 初始化测试客户端
    async setup() {
        try {
            // 登录获取token和服务器信息
            const loginClient = new LoginClient();
            const { token, gateInfo } = await loginClient.login('test', '123456');

            // 创建游戏客户端并设置认证信息
            this.client = new GameClient(token, gateInfo);
            await this.client.connect();

        } catch (error) {
            console.error('Setup failed:', error);
            throw error;
        }
    }

    // 清理测试资源
    async teardown() {
        if (this.client) {
            this.client.close();
            this.client = null;
        }
    }

    // 运行测试
    async run(token, serverInfo) {
        console.log(`\nRunning test: ${this.name}`);
        try {
            await this.setup(token, serverInfo);
            const result = await this.test();
            console.log(`Test ${this.name} ${result ? 'passed' : 'failed'}`);
            return result;
        } catch (error) {
            console.error(`Test ${this.name} failed with error:`, error);
            return false;
        } finally {
            await this.teardown();
        }
    }

    // 具体测试实现（由子类重写）
    async test() {
        throw new Error('test() method must be implemented by subclass');
    }
}

module.exports = BaseTest; 