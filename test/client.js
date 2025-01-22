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

// 测试登录流程
async function testLogin(root) {
    console.log("开始登录测试...");
    
    // 连接登录服务器
    console.log("正在连接登录服务器:", config.loginServer);
    const ws = new WebSocket(config.loginServer, {
        perMessageDeflate: false,
        binaryType: "arraybuffer"
    });
    
    return new Promise((resolve, reject) => {
        ws.on('open', () => {
            console.log("连接登录服务器成功");
            
            // 发送登录请求
            const request = createLoginRequest(root, config.account, config.password);
            console.log("发送登录请求, 长度:", request.length);
            console.log("请求内容:", Buffer.from(request).toString('hex'));
            ws.send(request, { binary: true });
        });
        
        ws.on('error', (error) => {
            console.error("WebSocket错误:", error);
            reject(error);
        });
        
        ws.on('close', (code, reason) => {
            console.log("WebSocket连接关闭:", code, reason);
        });
        
        ws.on('message', (data) => {
            console.log('Received message, length:', data.byteLength);
            
            // 解析消息内容
            const buffer = data instanceof Buffer ? data : Buffer.from(data);
            console.log('Buffer length:', buffer.length);
            console.log('Response content:', buffer.toString('hex'));
            
            try {
                // 解码基础响应
                const BaseResponse = root.lookupType("common.BaseResponse");
                const baseResponse = BaseResponse.decode(buffer);
                
                console.log('Base response:', {
                    errorCode: baseResponse.errorCode,
                    errorMsg: baseResponse.errorMsg,
                    payloadLength: baseResponse.payload ? baseResponse.payload.length : 0
                });
                
                // 如果有负载，解码登录响应
                if (baseResponse.payload) {
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
                
                resolve();  // 成功接收到响应后解决Promise
            } catch (err) {
                console.error('解析响应失败:', err);
                reject(err);
            }
        });
    });
}

// 测试网关认证
async function testGateAuth(root, loginResponse) {
    console.log("开始网关认证测试...");
    
    // 连接网关服务器
    const gateUrl = `ws://${loginResponse.gateAddr}:${loginResponse.gatePort}`;
    const ws = new WebSocket(gateUrl);
    
    return new Promise((resolve, reject) => {
        ws.on('open', () => {
            console.log("连接网关服务器成功");
            
            // 构造认证请求
            const C2GAuthRequest = root.lookupType("command.C2GAuthRequest");
            const authRequest = C2GAuthRequest.create({
                token: loginResponse.token,
                deviceId: config.deviceId,
                platform: config.platform,
                version: config.version
            });
            
            // 编码认证请求
            const MessageID = root.lookupEnum("common.MessageID");
            const baseRequest = createBaseRequest(
                root,
                MessageID.values.C2G_AUTH_REQUEST,
                C2GAuthRequest.encode(authRequest).finish()
            );
            
            // 发送认证请求
            console.log("发送认证请求...");
            const BaseRequest = root.lookupType("common.BaseRequest");
            ws.send(BaseRequest.encode(baseRequest).finish());
        });
        
        ws.on('message', async (data) => {
            // 解码认证响应
            const BaseResponse = root.lookupType("common.BaseResponse");
            const G2CAuthResponse = root.lookupType("command.G2CAuthResponse");
            
            try {
                const buffer = data instanceof Buffer ? data : Buffer.from(data);
                const baseResponse = BaseResponse.decode(buffer);
                const authResponse = G2CAuthResponse.decode(baseresponse.payload);
                console.log("认证响应:", authResponse);
                
                // 如果认证成功，继续测试获取角色
                const ErrorCode = root.lookupEnum("common.ErrorCode");
                if (authResponse.code === ErrorCode.values.ERROR_CODE_SUCCESS) {
                    await testGetRole(root, ws, loginResponse.token);
                }
                resolve();
            } catch (err) {
                console.error("解码响应失败:", err);
                reject(err);
            }
        });
        
        ws.on('error', (error) => {
            console.error("WebSocket错误:", error);
            reject(error);
        });
    });
}

// 测试获取角色
async function testGetRole(root, ws, token) {
    console.log("开始获取角色测试...");
    
    // 构造获取角色请求
    const C2GGetRoleRequest = root.lookupType("command.C2GGetRoleRequest");
    const getRoleRequest = C2GGetRoleRequest.create({
        token: token
    });
    
    // 编码获取角色请求
    const MessageID = root.lookupEnum("common.MessageID");
    const baseRequest = createBaseRequest(
        root,
        MessageID.values.C2G_GET_ROLE_REQUEST,
        C2GGetRoleRequest.encode(getRoleRequest).finish()
    );
    
    // 发送获取角色请求
    console.log("发送获取角色请求...");
    const BaseRequest = root.lookupType("common.BaseRequest");
    ws.send(BaseRequest.encode(baseRequest).finish());
    
    return new Promise((resolve, reject) => {
        ws.once('message', async (data) => {
            // 解码获取角色响应
            const BaseResponse = root.lookupType("common.BaseResponse");
            const G2CGetRoleResponse = root.lookupType("command.G2CGetRoleResponse");
            
            try {
                const buffer = data instanceof Buffer ? data : Buffer.from(data);
                const baseResponse = BaseResponse.decode(buffer);
                const roleResponse = G2CGetRoleResponse.decode(baseresponse.payload);
                console.log("获取角色响应:", roleResponse);
                
                // 如果没有角色，创建角色
                if (!roleResponse.hasRole) {
                    await testCreateRole(root, ws, token);
                }
                resolve();
            } catch (err) {
                console.error("解码响应失败:", err);
                reject(err);
            }
        });
    });
}

// 测试创建角色
async function testCreateRole(root, ws, token) {
    console.log("开始创建角色测试...");
    
    // 构造创建角色请求
    const C2GCreateRoleRequest = root.lookupType("command.C2GCreateRoleRequest");
    const createRoleRequest = C2GCreateRoleRequest.create({
        token: token,
        name: "test_role",
        gender: 1,
        job: 1
    });
    
    // 编码创建角色请求
    const MessageID = root.lookupEnum("common.MessageID");
    const baseRequest = createBaseRequest(
        root,
        MessageID.values.C2G_CREATE_ROLE_REQUEST,
        C2GCreateRoleRequest.encode(createRoleRequest).finish()
    );
    
    // 发送创建角色请求
    console.log("发送创建角色请求...");
    const BaseRequest = root.lookupType("common.BaseRequest");
    ws.send(BaseRequest.encode(baseRequest).finish());
    
    return new Promise((resolve, reject) => {
        ws.once('message', (data) => {
            // 解码创建角色响应
            const BaseResponse = root.lookupType("common.BaseResponse");
            const G2CCreateRoleResponse = root.lookupType("command.G2CCreateRoleResponse");
            
            try {
                const buffer = data instanceof Buffer ? data : Buffer.from(data);
                const baseresponse = BaseResponse.decode(buffer);
                const createResponse = G2CCreateRoleResponse.decode(baseresponse.payload);
                console.log("创建角色响应:", createResponse);
                resolve();
            } catch (err) {
                console.error("解码响应失败:", err);
                reject(err);
            }
        });
    });
}

// 主函数
async function main() {
    try {
        console.log("加载Proto文件...");
        const root = await loadProtos();
        console.log("Proto文件加载成功");
        
        await testLogin(root);
        console.log("测试完成");
        process.exit(0);
    } catch (error) {
        console.error("测试失败:", error);
        process.exit(1);
    }
}

main(); 