const path = require('path');
const WebSocket = require('ws');
const protobuf = require('protobufjs');

// 项目根目录
const ROOT_DIR = path.resolve(__dirname, '..');

// proto文件根目录
const PROTO_DIR = path.join(ROOT_DIR, 'proto');

// 配置
const config = {
    loginServer: 'ws://127.0.0.1:8021',
    account: 'test',
    password: '123456',
    deviceId: 'test_device',
    platform: 'test',
    version: '1.0.0'
};

// 序列号
let sequence = 0;

// 获取下一个序列号
function nextSequence() {
    return ++sequence;
}

// 加载proto文件
async function loadProtos() {
    const root = new protobuf.Root();

    // 添加proto文件搜索路径
    root.resolvePath = (origin, target) => {
        // 如果是相对路径，从PROTO_DIR开始查找
        if (target.startsWith('.')) {
            return path.resolve(path.dirname(origin), target);
        }
        // 如果是绝对路径（如 "common/user.proto"），从PROTO_DIR开始查找
        return path.resolve(PROTO_DIR, target);
    };

    await root.load([
        path.join(PROTO_DIR, "command/command.proto"),
        path.join(PROTO_DIR, "common/message.proto"),
        path.join(PROTO_DIR, "common/error.proto"),
        path.join(PROTO_DIR, "common/user.proto")
    ], { keepCase: true });
    return root;
}

// 创建基础请求
function createBaseRequest(root, msgId, payload) {
    const BaseRequest = root.lookupType("common.BaseRequest");
    return BaseRequest.create({
        session: {
            messageId: msgId,
            sequence: nextSequence(),
            timestamp: Math.floor(Date.now() / 1000),
            version: config.version
        },
        payload: payload
    });
}

// 创建登录请求
function createLoginRequest(root, account, password) {
    const BaseRequest = root.lookupType('common.BaseRequest');
    const LoginRequest = root.lookupType('command.C2LLoginRequest');

    // 创建登录请求内容
    const loginRequest = LoginRequest.create({
        account: account,
        password: password,
        platform: 'test',
        version: '1.0.0'
    });

    // 创建基础请求
    const baseRequest = BaseRequest.create({
        session: {
            messageId: 1,
            sequence: 1,
            timestamp: Math.floor(Date.now() / 1000),
            version: '1.0.0'
        },
        payload: LoginRequest.encode(loginRequest).finish()
    });

    return BaseRequest.encode(baseRequest).finish();
}

// 解析响应
function parseResponse(root, data) {
    console.log('Parsing response data:', Buffer.from(data).toString('hex'));
    const BaseResponse = root.lookupType('common.BaseResponse');
    const LoginResponse = root.lookupType('command.S2LLoginResponse');

    // 解析基础响应
    const baseResponse = BaseResponse.decode(data);
    console.log('Base response:', {
        errorCode: baseResponse.errorCode,
        errorMsg: baseResponse.errorMsg,
        payload: baseResponse.payload ? baseResponse.payload.length : 0
    });

    // 如果有payload，解析登录响应
    if (baseResponse.payload && baseResponse.payload.length > 0) {
        try {
            const S2LLoginResponse = root.lookupType("command.S2LLoginResponse");
            const loginResponse = S2LLoginResponse.decode(baseResponse.payload);
            console.log('Login response:', {
                code: loginResponse.code,
                message: loginResponse.message,
                token: loginResponse.token,
                gate_addr: loginResponse.gate_addr,
                gate_port: loginResponse.gate_port
            });
        } catch (err) {
            console.error('Failed to decode login response:', err);
            throw err;
        }
    }
}

// 测试登录
async function testLogin(ws, root) {
    console.log('开始登录测试...');
    
    // 发送登录请求
    const loginRequest = createLoginRequest(root, config.account, config.password);
    console.log('发送登录请求, 长度:', loginRequest.length);
    console.log('请求内容:', loginRequest.toString('hex'));
    ws.send(loginRequest);
    
    // 等待登录响应
    return new Promise((resolve, reject) => {
        ws.once('message', (data) => {
            console.log('Received message, length:', data.length);
            console.log('Buffer length:', data.byteLength);
            console.log('Response content:', data.toString('hex'));
            
            try {
                const BaseResponse = root.lookupType('common.BaseResponse');
                const LoginResponse = root.lookupType('command.S2LLoginResponse');
                
                // 解码基础响应
                const baseResponse = BaseResponse.decode(data);
                console.log('Base response:', baseResponse);
                
                // 解码登录响应
                let loginResponse = {};
                if (baseResponse.payload && baseResponse.payload.length > 0) {
                    loginResponse = LoginResponse.decode(baseResponse.payload);
                }
                console.log('Login response:', loginResponse);
                
                // 检查登录是否成功
                if (baseResponse.errorCode !== 0) {
                    console.log('\n登录失败:', baseResponse.errorMsg);
                    process.exit(1);
                    return;
                }
                
                resolve(loginResponse);
            } catch (err) {
                console.error('\n解析响应失败:', err);
                process.exit(1);
            }
        });
    });
}

// 测试获取角色
async function testGetRole(root, loginResponse) {
    console.log("开始获取用户信息测试...");
    
    // 连接网关服务器
    const gateUrl = `ws://${loginResponse.ws_addr}:${loginResponse.ws_port}`;
    console.log("Connecting to gate server:", gateUrl);
    const ws = new WebSocket(gateUrl);
    
    // 发送心跳
    function startHeartbeat() {
        const heartbeatInterval = 30000; // 30秒
        let heartbeatCount = 0;
        
        const heartbeatTimer = setInterval(() => {
            if (ws.readyState === WebSocket.OPEN) {
                heartbeatCount++;
                console.log(`发送第 ${heartbeatCount} 次心跳包...`);
                
                // 构造心跳请求
                const C2GHeartbeat = root.lookupType("command.C2GHeartbeat");
                const heartbeatRequest = C2GHeartbeat.create({
                    timestamp: Math.floor(Date.now() / 1000),
                    clientId: 0  // 可选的客户端ID
                });
                
                // 编码心跳请求
                const MessageID = root.lookupEnum("common.MessageID");
                const baseRequest = createBaseRequest(
                    root,
                    MessageID.values.C2G_HEARTBEAT,
                    C2GHeartbeat.encode(heartbeatRequest).finish()
                );
                
                // 发送心跳请求
                const BaseRequest = root.lookupType("common.BaseRequest");
                ws.send(BaseRequest.encode(baseRequest).finish());
                
                // 如果已经发送了3次心跳，关闭连接
                if (heartbeatCount >= 3) {
                    console.log("已发送3次心跳包，准备关闭连接...");
                    clearInterval(heartbeatTimer);
                    ws.close();
                }
            }
        }, heartbeatInterval);
        
        // 当WebSocket关闭时清理定时器
        ws.on('close', () => {
            clearInterval(heartbeatTimer);
            console.log("连接已关闭");
        });
    }
    
    return new Promise((resolve, reject) => {
        ws.on('error', (error) => {
            console.error("WebSocket error:", error);
            reject(error);
        });

        ws.on('close', (code, reason) => {
            console.log("WebSocket closed:", code, reason);
            resolve();  // 正常关闭不应该reject
        });

        ws.on('open', () => {
            console.log("连接网关服务器成功");
            // 启动心跳
            startHeartbeat();
            
            // 构造获取用户信息请求
            const C2GUserInfoRequest = root.lookupType("command.C2GUserInfoRequest");
            const userInfoRequest = C2GUserInfoRequest.create({
                token: loginResponse.token,
                name: "test_role_" + Date.now(),
                gender: 1,
                job: 1
            });
            
            // 编码获取用户信息请求
            const MessageID = root.lookupEnum("common.MessageID");
            const baseRequest = createBaseRequest(
                root,
                MessageID.values.C2G_USER_INFO_REQUEST,
                C2GUserInfoRequest.encode(userInfoRequest).finish()
            );
            
            // 发送获取用户信息请求
            console.log("发送获取用户信息请求...");
            const BaseRequest = root.lookupType("common.BaseRequest");
            ws.send(BaseRequest.encode(baseRequest).finish());
        });
        
        ws.on('message', async (data) => {
            try {
                // 先解码基础响应
                const BaseResponse = root.lookupType("common.BaseResponse");
                const buffer = data instanceof Buffer ? data : Buffer.from(data);
                const baseResponse = BaseResponse.decode(buffer);
                
                // 打印基础响应信息
                console.log("Base response:", {
                    errorCode: baseResponse.errorCode,
                    errorMsg: baseResponse.errorMsg,
                    payloadLength: baseResponse.payload ? baseResponse.payload.length : 0
                });
                
                if (baseResponse.payload) {
                    // 检查是否是心跳响应
                    const MessageID = root.lookupEnum("common.MessageID");
                    if (baseResponse.session.messageId === MessageID.values.G2C_HEARTBEAT) {
                        const G2CHeartbeat = root.lookupType("command.G2CHeartbeat");
                        const heartbeatResponse = G2CHeartbeat.decode(baseResponse.payload);
                        console.log("收到心跳响应:", heartbeatResponse);
                        return;
                    }
                    
                    const G2CUserInfoResponse = root.lookupType("command.G2CUserInfoResponse");
                    const userInfoResponse = G2CUserInfoResponse.decode(baseResponse.payload);
                    console.log("获取用户信息响应:", userInfoResponse);
                    
                    if (userInfoResponse.code === 0) {
                        console.log("用户信息:", userInfoResponse.user);
                        if (userInfoResponse.is_new) {
                            console.log("新创建的用户");
                        }
                    }
                }
            } catch (err) {
                console.error("解码响应失败:", err);
                console.error("Raw data:", Buffer.from(data).toString('hex'));
                // 不要因为解码错误就中断测试
            }
        });
    });
}

// 处理登录响应
function handleLoginResponse(response) {
    // 打印原始响应数据
    console.log('Raw login response:', JSON.stringify(response, null, 2));

    console.log('Login response:', response);
    if (response.code === 0) {
        // 保存token和网关信息
        token = response.token;
        gateAddr = response.wsAddr;  // 修改字段名以匹配proto定义
        gatePort = response.wsPort;  // 修改字段名以匹配proto定义
        
        console.log('Gateway info:', {
            addr: gateAddr,
            port: gatePort
        });
        
        console.log('登录成功，开始获取角色...');
        testGetRole();
    } else {
        console.error('登录失败:', response.message);
    }
}

// 加载proto文件
function loadProtoFiles() {
    console.log('加载Proto文件...');
    try {
        // 加载proto文件
        protobuf.load("../proto/common/message.proto", function(err, root) {
            if (err) throw err;
            
            // 加载其他proto文件
            protobuf.load("../proto/command/command.proto", function(err, commandRoot) {
                if (err) throw err;
                
                // 保存消息类型
                BaseRequest = root.lookupType("common.BaseRequest");
                BaseResponse = root.lookupType("common.BaseResponse");
                LoginRequest = commandRoot.lookupType("command.C2LLoginRequest");
                LoginResponse = commandRoot.lookupType("command.S2LLoginResponse");
                GetRoleRequest = commandRoot.lookupType("command.C2GGetRoleRequest");
                
                // 验证消息定义
                console.log('LoginResponse fields:', LoginResponse.fields);
                
                console.log('Proto文件加载成功');
                startTest();
            });
        });
    } catch (err) {
        console.error('加载Proto文件失败:', err);
    }
}

// 主函数
async function main() {
    try {
        console.log("加载Proto文件...");
        const root = await loadProtos();
        console.log("Proto文件加载成功");
        
        // 连接登录服务器
        console.log('正在连接登录服务器:', config.loginServer);
        const ws = new WebSocket(config.loginServer);
        
        await new Promise((resolve, reject) => {
            ws.on('open', resolve);
            ws.on('error', reject);
        });
        console.log('连接登录服务器成功');
        
        // 测试登录
        const loginResponse = await testLogin(ws, root);
        if (loginResponse.token) {
            console.log('登录成功，开始获取角色...');

            // 继续后续测试
            await testGetRole(root, loginResponse);
        } else {
            console.log('登录失败，终止测试');
            process.exit(1);
        }
    } catch (err) {
        console.error('测试失败:', err);
        process.exit(1);
    }
}

main(); 