const ProtoHelper = require('./lib/proto_helper');
const LoginTest = require('./tests/login_test');
const UserInfoTest = require('./tests/user_info_test');
const HeartbeatTest = require('./tests/heartbeat_test');

async function main() {
    try {
        console.log("加载Proto文件...");
        const root = await ProtoHelper.loadProtos();
        console.log("Proto文件加载成功");

        const loginTest = new LoginTest(root);
        const loginResponse = await loginTest.run();

        const userInfoTest = new UserInfoTest(root, loginResponse);
        const userInfo = await userInfoTest.run();

        const heartbeatTest = new HeartbeatTest(root, loginResponse);
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