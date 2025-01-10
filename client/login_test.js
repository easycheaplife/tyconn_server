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
            'game/game.proto',
            'command/command.proto'
        ]);
        console.log('Proto files loaded');
        
        // 验证所有消息类型是否正确加载
        const C2SLoginRequest = root.lookupType("command.C2SLoginRequest");
        const S2CLoginResponse = root.lookupType("command.S2CLoginResponse");
        const BaseRequest = root.lookupType("common.BaseRequest");
        const BaseResponse = root.lookupType("common.BaseResponse");
        const ErrorCode = root.lookupEnum("common.ErrorCode");
        const MessageID = root.lookupEnum("common.MessageID");
        
        if (!C2SLoginRequest || !S2CLoginResponse || !BaseRequest || !BaseResponse || !ErrorCode || !MessageID) {
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
                    messageId: MessageID.values.C2S_LOGIN_REQUEST,
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
                
                // 创建登录请求
                const loginData = {
                    account: "test",
                    password: "123456",
                    device_id: "test_device",
                    platform: "web",
                    version: "1.0.0"
                };
                
                // 验证请求数据
                const loginError = C2SLoginRequest.verify(loginData);
                if (loginError) {
                    throw new Error(`Invalid login data: ${loginError}`);
                }
                
                // 编码消息
                const payload = C2SLoginRequest.encode(loginData).finish();
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
                console.log('Sending login request...');
                ws.send(message, { binary: true });
                
            } catch (error) {
                console.error('Failed to send login request:', error);
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
                    session: {
                        messageId: baseResponse.session.messageId,
                        sequence: baseResponse.session.sequence,
                        timestamp: baseResponse.session.timestamp,
                        version: baseResponse.session.version
                    }
                });
                
                // 检查错误码
                if (baseResponse.errorCode !== 0) {
                    console.log('Error:', baseResponse.errorMsg);
                    return;
                }
                
                // 解码具体响应
                const response = S2CLoginResponse.decode(baseResponse.payload);
                console.log('Received login response:');
                console.log('- Code:', ErrorCode.valuesById[response.code]);
                console.log('- Message:', response.message);
                console.log('- Raw response:', JSON.stringify(response.toJSON(), null, 2));
                
                if (response.code === ErrorCode.values.ERROR_CODE_SUCCESS) {
                    console.log('- Token:', response.token);
                    if (response.userInfo) {
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
                
            } catch (error) {
                console.error('Failed to decode response:', error);
                console.error('Raw data:', data);
                console.error('Raw data (hex):', Buffer.from(data).toString('hex'));
            } finally {
                // 登录完成后关闭连接
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
    }
}

main().catch(console.error);
