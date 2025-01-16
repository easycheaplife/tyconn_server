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
        const C2SHeartbeat = root.lookupType("command.C2SHeartbeat");
        const S2CHeartbeat = root.lookupType("command.S2CHeartbeat");
        const BaseRequest = root.lookupType("common.BaseRequest");
        const BaseResponse = root.lookupType("common.BaseResponse");
        const ErrorCode = root.lookupEnum("common.ErrorCode");
        const MessageID = root.lookupEnum("common.MessageID");
        
        if (!C2SHeartbeat || !S2CHeartbeat || !BaseRequest || !BaseResponse || !ErrorCode || !MessageID) {
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
            
            ws.on('open', () => {
                console.log('Connected to server');
                reconnectAttempts = 0;  // 重置重连次数
                
                // 定时发送心跳
                const heartbeatInterval = setInterval(() => {
                    try {
                        // 创建会话信息
                        const session = {
                            messageId: MessageID.values.C2S_HEARTBEAT,
                            sequence: Date.now(),
                            timestamp: Date.now(),
                            version: "1.0.0"
                        };
                        
                        // 创建心跳数据
                        const heartbeatData = {
                            timestamp: Date.now(),
                            clientId: 1
                        };
                        
                        // 验证心跳数据
                        const heartbeatError = C2SHeartbeat.verify(heartbeatData);
                        if (heartbeatError) {
                            throw new Error(`Invalid heartbeat data: ${heartbeatError}`);
                        }
                        
                        // 编码心跳消息
                        const payload = C2SHeartbeat.encode(C2SHeartbeat.create(heartbeatData)).finish();
                        
                        const baseRequest = {
                            session: session,
                            payload: payload
                        };
                        
                        // 验证基础请求
                        const baseError = BaseRequest.verify(baseRequest);
                        if (baseError) {
                            throw new Error(`Invalid base request: ${baseError}`);
                        }
                        
                        // 编码并发送
                        const message = BaseRequest.encode(BaseRequest.create(baseRequest)).finish();
                        console.log('Sending heartbeat...');
                        ws.send(message, { binary: true });
                        
                    } catch (error) {
                        console.error('Failed to send heartbeat:', error);
                        clearInterval(heartbeatInterval);
                        ws.close();
                    }
                }, 1000);  // 每秒发送一次心跳
                
                // 清理定时器
                ws.on('close', () => {
                    clearInterval(heartbeatInterval);
                });
            });
            
            ws.on('message', (data) => {
                try {
                    // 解码基础响应
                    const baseResponse = BaseResponse.decode(data);
                    console.log('Received response:', {
                        errorCode: baseResponse.errorCode,
                        errorMsg: baseResponse.errorMsg
                    });
                    
                    if (baseResponse.errorCode === ErrorCode.values.ERROR_CODE_SUCCESS) {
                        // 解码心跳响应
                        const response = S2CHeartbeat.decode(baseResponse.payload);
                        console.log('Heartbeat response:', {
                            timestamp: new Date(response.timestamp * 1000).toLocaleString(),
                            code: response.code
                        });
                        
                        // 计算延迟
                        const latency = Date.now() - (baseResponse.session?.timestamp || 0);
                        console.log('Latency:', latency, 'ms');
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