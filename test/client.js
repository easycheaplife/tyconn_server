const ProtoHelper = require('./lib/proto_helper');
const LoginClient = require('./lib/login_client');
const config = require('./config/config');

// 全局保存token
global.token = null;

async function main() {
    try {
        // 加载Proto文件
        console.log('加载Proto文件...');
        const root = await ProtoHelper.loadProtos();
        console.log('Proto文件加载成功');

        // 登录获取token
        console.log('开始登录...');
        const loginClient = new LoginClient();
        const loginResult = await loginClient.login(
            config.testAccount,
            config.testPassword
        );

        // 保存token到全局
        global.token = loginResult.token;
        console.log('登录成功');

        // 测试完成
        console.log('测试完成');
    } catch (error) {
        console.error('测试失败:', error.message);
        if (error.stack) {
            console.error(error.stack);
        }
        process.exit(1);
    }
}

main();