const WebSocket = require('ws');
const protobuf = require('protobufjs');
const fs = require('fs');

async function main() {
    // 加载proto文件
    const root = await protobuf.load("../proto/login.proto");
    const C2SLoginRequest = root.lookupType("login.C2SLoginRequest");
    const S2CLoginResponse = root.lookupType("login.S2CLoginResponse");
    const ErrorCode = root.lookupEnum("login.ErrorCode");
    
    // 创建WebSocket连接
    const ws = new WebSocket('ws://localhost:8891', {
        perMessageDeflate: false
    });
    
    ws.on('open', () => {
        console.log('Connected to server');
        
        // 创建登录请求
        const loginData = {
            account: "test",
            password: "123456",
            device_id: "test_device",
            platform: "web",
            version: "1.0.0"
        };
        
        // 编码消息
        const message = C2SLoginRequest.encode(loginData).finish();
        
        // 发送消息 - 使用二进制模式
        console.log('Sending login request...');
        const cmdBuffer = Buffer.from("login|");
        const msgBuffer = Buffer.from(message);
        const finalBuffer = Buffer.concat([cmdBuffer, msgBuffer]);
        ws.send(finalBuffer, { binary: true });
    });
    
    ws.on('message', (data) => {
        try {
            // 解码响应 - 直接使用二进制数据
            const response = S2CLoginResponse.decode(data);
            console.log('Received login response:');
            console.log('- Code:', ErrorCode.valuesById[response.code]);
            console.log('- Message:', response.message);
            console.log('- Raw response:', JSON.stringify(response.toJSON(), null, 2));
            
            if (response.code === ErrorCode.values.ERROR_CODE_SUCCESS) {
                console.log('- Token:', response.token);
                if (response.userInfo) {  // 注意：protobuf.js 会使用驼峰命名
                    console.log('User Info:');
                    console.log('- ID:', response.userInfo.userId?.toString());
                    console.log('- Nickname:', response.userInfo.nickname);
                    console.log('- Level:', response.userInfo.level);
                    console.log('- VIP:', response.userInfo.vipLevel);
                    console.log('- Gold:', response.userInfo.gold?.toString());
                    console.log('- Diamond:', response.userInfo.diamond?.toString());
                } else {
                    console.log('No user info in response');
                }
            }
            
            // 登录完成后关闭连接
            ws.close();
            
        } catch (error) {
            console.error('Failed to decode response:', error);
            console.error('Raw data:', data);
        }
    });
    
    ws.on('error', console.error);
    ws.on('close', () => console.log('Connection closed'));
}

main().catch(console.error);
