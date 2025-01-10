const WebSocket = require('ws');
const protobuf = require('protobufjs');
const path = require('path');

async function main() {
    try {
        // 设置proto文件根目录
        const PROTO_ROOT = path.resolve(__dirname, '../proto');
        
        // 加载proto文件
        const root = new protobuf.Root();
        root.resolvePath = (origin, target) => {
            console.log('Resolving proto path:', target);
            return path.resolve(PROTO_ROOT, target);
        };
        
        console.log('Loading proto files...');
        await root.load([
            'common/message.proto',
            'common/error.proto',
            'common/user.proto',
            'command/command.proto',
            'game/game.proto'
        ]);
        console.log('Proto files loaded');
        
        // 打印所有已加载的类型
        console.log('\nAvailable Types:');
        const types = root.nested;
        for (const namespace in types) {
            console.log(`\nNamespace: ${namespace}`);
            const items = types[namespace].nested || {};
            for (const name in items) {
                const item = items[name];
                const type = item ? item.constructor.name : 'Unknown';
                console.log(`  - ${name} (${type})`);
            }
        }

        // 验证所有消息类型是否正确加载
        const RegisterRequest = root.lookupType("command.C2SRegisterRequest");
        const RegisterResponse = root.lookupType("command.S2CRegisterResponse");
        const BaseRequest = root.lookupType("common.BaseRequest");
        const BaseResponse = root.lookupType("common.BaseResponse");
        const ErrorCode = root.lookupEnum("common.ErrorCode");
        const MessageID = root.lookupEnum("common.MessageID");
        const UserInfo = root.lookupType("common.UserInfo");
        
        if (!RegisterRequest || !RegisterResponse || !BaseRequest || !BaseResponse || !ErrorCode || !MessageID || !UserInfo) {
            throw new Error("Failed to load required message types");
        }
        
        // 创建WebSocket连接
        const ws = new WebSocket('ws://localhost:8891', {
            perMessageDeflate: false
        });
        
        ws.on('open', () => {
            console.log('Connected to server');
            
            try {
                // 创建会话信息
                const session = {
                    messageId: MessageID.values.C2S_REGISTER_REQUEST,
                    sequence: 1,
                    timestamp: Date.now(),
                    version: "1.0.0"
                };
                console.log('Created session:', session);
                
                // 验证 Session
                const Session = root.lookupType("common.Session");
                const sessionError = Session.verify(session);
                if (sessionError) {
                    throw new Error(`Invalid session: ${sessionError}`);
                }
                
                // 创建注册请求
                const registerData = {
                    username: "testuser",
                    password: "123456",
                    nickname: "Test User",
                    avatar: "default.png"
                };
                
                // 验证请求数据
                const registerError = RegisterRequest.verify(registerData);
                if (registerError) {
                    throw new Error(`Invalid register data: ${registerError}`);
                }
                
                // 编码消息
                const payload = RegisterRequest.encode(registerData).finish();
                const baseRequest = {
                    session: session,
                    payload: payload
                };
                
                // 验证 BaseRequest
                const baseRequestError = BaseRequest.verify(baseRequest);
                if (baseRequestError) {
                    throw new Error(`Invalid base request: ${baseRequestError}`);
                }
                
                const message = BaseRequest.encode(baseRequest).finish();
                console.log('Sending register request...');
                ws.send(message, { binary: true });
                
            } catch (error) {
                console.error('Failed to send register request:', error);
                ws.close();
            }
        });
        
        ws.on('message', (data) => {
            try {
                // 解码基础响应
                const baseResponse = BaseResponse.decode(data);
                console.log('Received base response:', {
                    errorCode: baseResponse.errorCode,
                    errorMsg: baseResponse.errorMsg,
                    session: baseResponse.session
                });
                
                // 检查错误码
                if (baseResponse.errorCode !== 0) {
                    console.log('Error:', baseResponse.errorMsg);
                    return;
                }
                
                // 解码注册响应
                const response = RegisterResponse.decode(baseResponse.payload);
                console.log('Received register response:');
                console.log('- Code:', ErrorCode.valuesById[response.code]);
                console.log('- Message:', response.message);
                
                if (response.code === ErrorCode.values.ERROR_CODE_SUCCESS) {
                    if (response.user_info) {
                        console.log('User Info:');
                        console.log('- ID:', response.user_info.user_id?.toString());
                        console.log('- Nickname:', response.user_info.nickname);
                        console.log('- Level:', response.user_info.level);
                        console.log('- VIP:', response.user_info.vip_level);
                        console.log('- Gold:', response.user_info.gold?.toString());
                        console.log('- Diamond:', response.user_info.diamond?.toString());
                        console.log('- Register Time:', new Date(response.user_info.register_time * 1000).toLocaleString());
                    } else {
                        console.log('No user info in response');
                    }
                }
                
            } catch (error) {
                console.error('Failed to decode response:', error);
                console.error('Raw data:', data);
                console.error('Raw data (hex):', Buffer.from(data).toString('hex'));
            } finally {
                // 注册完成后关闭连接
                ws.close();
            }
        });
        
        ws.on('error', (error) => {
            console.error('WebSocket error:', error);
        });
        
        ws.on('close', () => {
            console.log('Connection closed');
        });
        
    } catch (error) {
        console.error('Initialization error:', error);
        if (error.stack) {
            console.error('Stack trace:', error.stack);
        }
    }
}

main().catch(console.error); 
