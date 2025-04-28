const BaseBenchmark = require('./base_benchmark');
const LoginClient = require('../lib/login_client');
const config = require('../config/config');

class LoginBenchmark extends BaseBenchmark {
    async setup() {
        // 不需要调用 super.setup()，因为登录测试不需要预先登录
        this.loginClient = new LoginClient();
    }

    async runTest() {
        await this.loginClient.login(
            config.testAccount,
            config.testPassword
        );
    }

    async teardown() {
        // 不需要关闭连接，因为每次登录都是新的连接
    }

    getTitle() {
        return 'Login Benchmark Results';
    }
}

module.exports = (options) => new LoginBenchmark(options).run(); 