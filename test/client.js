const ProtoHelper = require('./lib/proto_helper');
const LoginTest = require('./tests/login_test');
const UserInfoTest = require('./tests/user_info_test');
const HeartbeatTest = require('./tests/heartbeat_test');

// 全局保存token
global.token = null;

async function main() {
    try {
        // 加载Proto文件
        console.log('加载Proto文件...');
        const root = await ProtoHelper.loadProtos();
        console.log('Proto文件加载成功');

        // 登录测试
        console.log('开始登录测试...');
        const loginTest = new LoginTest(root);
        const loginResponse = await loginTest.run();
        if (!loginResponse) {
            console.log('登录失败，终止测试');
            return;
        }

        // 保存token到全局
        global.token = loginResponse.token;
        console.log('登录成功');

        // 用户信息测试
        console.log('开始获取用户信息...');
        const userInfoTest = new UserInfoTest(root, loginResponse);
        const userInfo = await userInfoTest.run();

        // 心跳测试
        console.log('开始心跳测试...');
        const heartbeatTest = new HeartbeatTest(root, loginResponse.ws_addr, loginResponse.ws_port);
        await heartbeatTest.start();

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