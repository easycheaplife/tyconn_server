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
        
        // 添加重连功能
        let reconnectAttempts = 0;
        const maxReconnectAttempts = 3;
        const reconnectDelay = 3000; // 3秒

        function connect() {

            const ws = new WebSocket('ws://localhost:8008', {
                perMessageDeflate: false
            });
			/*
            const ws = new WebSocket('wss://localhost:8011', {
                perMessageDeflate: false,
				rejectUnauthorized: false
            });
			*/
            
            ws.on('open', () => {
                console.log('Connected to server');
                reconnectAttempts = 0;  // 重置重连次数
                
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
                        account: "testuser",
                        password: "123456",
                        device_id: "test_device",
                        platform: "web",
                        version: "1.0.0"
                    };
                    
                    // 打印登录数据
                    console.log('Login data:', loginData);
                    
                    // 验证请求数据
                    const loginError = C2SLoginRequest.verify(loginData);
                    if (loginError) {
                        throw new Error(`Invalid login data: ${loginError}`);
                    }
                    
                    // 编码消息
                    const payload = C2SLoginRequest.encode(loginData).finish();
                    console.log('Encoded payload (hex):', Buffer.from(payload).toString('hex'));
                    
                    const baseRequest = {
                        session: session,
                        payload: payload
                    };
                    
                    // 打印基础请求
                    console.log('Base request:', {
                        session: baseRequest.session,
                        payload: Buffer.from(baseRequest.payload).toString('hex')
                    });
                    
                    // 验证 BaseRequest
                    const baseRequestError = BaseRequest.verify(baseRequest);
                    if (baseRequestError) {
                        throw new Error(`Invalid base request: ${baseRequestError}`);
                    }
                    
                    const message = BaseRequest.encode(baseRequest).finish();
                    console.log('Final message (hex):', Buffer.from(message).toString('hex'));
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
                    console.log('Received response:');
                    console.log('- Error code:', ErrorCode.valuesById[baseResponse.errorCode]);
                    console.log('- Error message:', baseResponse.errorMsg);
                    
                    if (baseResponse.errorCode === ErrorCode.values.ERROR_CODE_SUCCESS) {
                        // 解码登录响应
                        const response = S2CLoginResponse.decode(baseResponse.payload);
                        console.log('Login response (raw):', response.toJSON());
                        console.log('Login response:', {
                            code: response.code,
                            message: response.message,
                            token: response.token,
                            userInfo: response.userInfo,
                            isNewUser: response.isNewUser
                        });
                        
                        if (response.userInfo) {
                            console.log('User info:');
                            console.log('- ID:', response.userInfo.userId?.toString());
                            console.log('- Username:', response.userInfo.username);
                            console.log('- Nickname:', response.userInfo.nickname);
                            console.log('- Level:', response.userInfo.level);
                            console.log('- VIP:', response.userInfo.vipLevel);
                            console.log('- Gold:', response.userInfo.gold?.toString());
                            console.log('- Diamond:', response.userInfo.diamond?.toString());
                            console.log('- Register time:', new Date(response.userInfo.registerTime * 1000).toLocaleString());
                            console.log('- Last login:', new Date(response.userInfo.lastLogin * 1000).toLocaleString());
                        }
                    }
                } catch (error) {
                    console.error('Failed to decode response:', error);
                }
            });
            
            ws.on('error', (error) => {
                console.error('WebSocket error:', error);
            });
            
            ws.on('close', () => {
                console.log('Connection closed');
                
                // 尝试重连
                if (reconnectAttempts < maxReconnectAttempts) {
                    reconnectAttempts++;
                    console.log(`Reconnecting... (attempt ${reconnectAttempts}/${maxReconnectAttempts})`);
                    setTimeout(connect, reconnectDelay);
                } else {
                    console.log('Max reconnection attempts reached');
                    process.exit(1);
                }
            });
        }

        // 启动连接
        connect();
        
    } catch (error) {
        console.error('Initialization error:', error);
    }
}

main().catch(console.error);
