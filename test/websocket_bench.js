const WebSocket = require('ws');
const protobuf = require('protobufjs');
const path = require('path');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');
const fs = require('fs').promises;

// 命令行参数配置
const argv = yargs(hideBin(process.argv))
    .option('connections', {
        alias: 'c',
        type: 'number',
        description: '总连接数'
    })
    .option('concurrent', {
        alias: 'n',
        type: 'number',
        description: '并发连接数'
    })
    .option('duration', {
        alias: 'd',
        type: 'number',
        description: '压测持续时间(秒)'
    })
    .option('host', {
        alias: 'h',
        type: 'string',
        description: '服务器地址'
    })
    .option('port', {
        alias: 'p',
        type: 'number',
        description: '服务器端口'
    })
    .option('ssl', {
        alias: 's',
        type: 'boolean',
        description: '是否使用SSL'
    })
    .option('interval', {
        alias: 'i',
        type: 'number',
        description: '消息发送间隔(ms)'
    })
    .help()
    .argv;

// 合并命令行参数到配置
const CONFIG = {
    connections: argv.connections || 1000,
    concurrent: argv.concurrent || 100,
    interval: argv.interval || 100,
    messageInterval: 1000,
    duration: argv.duration || 300,
    host: argv.host || 'localhost',
    port: argv.port || 8008,
    ssl: argv.ssl || false,
    keepAlive: true,
    responseTimeout: 5000,  // 响应超时时间(ms)
};

// 统计信息
const STATS = {
    connected: 0,          // 当前连接数
    failed: 0,            // 失败连接数
    messages: {
        sent: 0,          // 发送消息数
        received: 0,       // 接收消息数
        failed: 0         // 失败消息数
    },
    latency: {
        min: Number.MAX_VALUE,
        max: 0,
        total: 0,
        count: 0
    },
    startTime: 0,
    clients: [],
    messageTimestamps: new Map(),  // 用于计算延迟
    cpu: {
        user: 0,
        system: 0
    },
    memory: {
        rss: 0,
        heapTotal: 0,
        heapUsed: 0,
        external: 0
    },
    responses: {
        success: 0,
        error: 0,
        timeout: 0
    },
    messageTypes: new Map()  // 统计不同消息类型的数量
};

// 加载Proto文件
async function loadProto() {
    const PROTO_ROOT = path.resolve(__dirname, '../proto');
    const root = new protobuf.Root();
    root.resolvePath = (origin, target) => {
        return path.resolve(PROTO_ROOT, target);
    };
    
    await root.load([
        'common/message.proto',
        'common/error.proto',
        'common/user.proto',
        'command/command.proto'
    ]);
    
    return {
        C2SLoginRequest: root.lookupType("command.C2SLoginRequest"),
        C2SHeartbeat: root.lookupType("command.C2SHeartbeat"),
        BaseRequest: root.lookupType("common.BaseRequest"),
        BaseResponse: root.lookupType("common.BaseResponse"),
        MessageID: root.lookupEnum("common.MessageID")
    };
}

// 创建客户端连接
async function createClient(index, proto) {
    const protocol = CONFIG.ssl ? 'wss' : 'ws';
    const ws = new WebSocket(`${protocol}://${CONFIG.host}:${CONFIG.port}`, {
        perMessageDeflate: false,
        rejectUnauthorized: false
    });
    
    return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
            reject(new Error('Connection timeout'));
        }, 5000);
        
        ws.on('open', () => {
            clearTimeout(timeout);
            STATS.connected++;
            STATS.clients.push(ws);
            
            // 发送登录消息
            sendLoginMessage(ws, index, proto);
            
            // 启动消息循环
            if (CONFIG.messageInterval > 0) {
                ws.messageInterval = startMessageLoop(ws, index, proto);
            }
            
            // 定时发送心跳
            if (CONFIG.keepAlive) {
                ws.pingInterval = setInterval(() => {
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.ping();
                    }
                }, 30000);
            }
            
            resolve(ws);
        });
        
        ws.on('message', (data) => {
            STATS.messages.received++;
            
            try {
                const baseResponse = proto.BaseResponse.decode(data);
                const msgId = baseResponse.session?.sequence;
                
                // 统计响应类型
                if (baseResponse.errorCode === 0) {
                    STATS.responses.success++;
                } else {
                    STATS.responses.error++;
                    // 记录错误类型
                    const errorType = baseResponse.errorCode;
                    STATS.messageTypes.set(errorType, (STATS.messageTypes.get(errorType) || 0) + 1);
                }
                
                // 计算延迟
                if (msgId && STATS.messageTimestamps.has(msgId)) {
                    const latency = Date.now() - STATS.messageTimestamps.get(msgId);
                    STATS.latency.min = Math.min(STATS.latency.min, latency);
                    STATS.latency.max = Math.max(STATS.latency.max, latency);
                    STATS.latency.total += latency;
                    STATS.latency.count++;
                    STATS.messageTimestamps.delete(msgId);
                }
            } catch (error) {
                console.error('Failed to decode response:', error);
                console.error('Raw response data:', data);
            }
        });
        
        ws.on('error', (error) => {
            STATS.failed++;
            reject(error);
        });
        
        ws.on('close', () => {
            STATS.connected--;
            if (ws.pingInterval) {
                clearInterval(ws.pingInterval);
            }
            if (ws.messageInterval) {
                clearInterval(ws.messageInterval);
            }
        });
    });
}

// 发送登录消息
function sendLoginMessage(ws, index, proto) {
    try {
        const msgId = Date.now();
        const session = {
            messageId: proto.MessageID.values.C2S_LOGIN_REQUEST,
            sequence: msgId,
            timestamp: Date.now(),
            version: "1.0.0"
        };
        
        // 登录数据
        const loginData = {
            account: `test_user_${index}`,
            password: "123456",
            device_id: `device_${index}`,
            platform: "web",
            version: "1.0.0"
        };
        
        // 验证登录数据格式
        const loginError = proto.C2SLoginRequest.verify(loginData);
        if (loginError) {
            throw new Error(`Invalid login data: ${loginError}`);
        }
        
        // 编码登录请求
        const payload = proto.C2SLoginRequest.encode(proto.C2SLoginRequest.create(loginData)).finish();
        
        // 创建基础请求
        const baseRequest = {
            session: session,
            payload: payload
        };
        
        // 验证基础请求格式
        const baseError = proto.BaseRequest.verify(baseRequest);
        if (baseError) {
            throw new Error(`Invalid base request: ${baseError}`);
        }
        
        // 编码并发送
        const message = proto.BaseRequest.encode(proto.BaseRequest.create(baseRequest)).finish();
        ws.send(message, { binary: true });
        
        // 更新统计
        STATS.messages.sent++;
        STATS.messageTimestamps.set(msgId, Date.now());
        
        // 调试日志
        console.debug('Sent login request:', {
            session,
            loginData,
            payloadLength: payload.length,
            messageLength: message.length
        });
        
    } catch (error) {
        console.error('Failed to send login message:', error);
        STATS.messages.failed++;
    }
}

// 更新性能统计
function updatePerformanceStats() {
    const cpu = process.cpuUsage();
    STATS.cpu.user = cpu.user / 1000000;  // 转换为秒
    STATS.cpu.system = cpu.system / 1000000;
    
    const mem = process.memoryUsage();
    STATS.memory = {
        rss: mem.rss / 1024 / 1024,
        heapTotal: mem.heapTotal / 1024 / 1024,
        heapUsed: mem.heapUsed / 1024 / 1024,
        external: mem.external / 1024 / 1024
    };
}

// 增强统计信息打印
function printStats() {
    updatePerformanceStats();
    const duration = (Date.now() - STATS.startTime) / 1000;
    const avgLatency = STATS.latency.count > 0 
        ? STATS.latency.total / STATS.latency.count 
        : 0;
    
    console.log(`
Stats after ${duration.toFixed(1)}s:
Connections:
- Active: ${STATS.connected}
- Failed: ${STATS.failed}
- Success Rate: ${((STATS.connected / CONFIG.connections) * 100).toFixed(1)}%

Messages:
- Sent: ${STATS.messages.sent}
- Received: ${STATS.messages.received}
- Failed: ${STATS.messages.failed}
- Msg/sec: ${(STATS.messages.sent / duration).toFixed(1)}
- Success Rate: ${((STATS.messages.received / STATS.messages.sent) * 100).toFixed(1)}%

Latency (ms):
- Min: ${STATS.latency.min === Number.MAX_VALUE ? 0 : STATS.latency.min}
- Max: ${STATS.latency.max}
- Avg: ${avgLatency.toFixed(1)}

System:
- CPU User: ${STATS.cpu.user.toFixed(1)}s
- CPU System: ${STATS.cpu.system.toFixed(1)}s
- Memory RSS: ${STATS.memory.rss.toFixed(1)} MB
- Heap Total: ${STATS.memory.heapTotal.toFixed(1)} MB
- Heap Used: ${STATS.memory.heapUsed.toFixed(1)} MB
- External: ${STATS.memory.external.toFixed(1)} MB

Response Types:
- Success: ${STATS.responses.success}
- Error: ${STATS.responses.error}
- Timeout: ${STATS.responses.timeout}
`);
}

// 清理资源
async function cleanup() {
    console.log('\nStopping benchmark...');
    
    // 保存测试结果
    await saveResults();
    
    // 关闭所有连接
    STATS.clients.forEach(client => {
        if (client.pingInterval) {
            clearInterval(client.pingInterval);
        }
        client.close();
    });
    
    console.log('All connections closed');
    process.exit(0);
}

// 启动压测
async function startBenchmark() {
    console.log('Starting benchmark with config:', CONFIG);
    const proto = await loadProto();
    
    STATS.startTime = Date.now();
    
    // 设置压测时间
    if (CONFIG.duration > 0) {
        setTimeout(cleanup, CONFIG.duration * 1000);
    }
    
    // 处理进程退出
    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);
    
    // 创建连接
    for (let i = 0; i < CONFIG.connections; i += CONFIG.concurrent) {
        const batch = Math.min(CONFIG.concurrent, CONFIG.connections - i);
        const promises = [];
        
        for (let j = 0; j < batch; j++) {
            promises.push(createClient(i + j, proto).catch(err => {
                STATS.failed++;
                console.error(`Client ${i + j} failed:`, err.message);
            }));
        }
        
        await Promise.all(promises);
        await new Promise(resolve => setTimeout(resolve, CONFIG.interval));
        
        console.log(`Progress: ${i + batch}/${CONFIG.connections}, Connected: ${STATS.connected}, Failed: ${STATS.failed}`);
    }
    
    // 定时打印统计信息
    setInterval(printStats, 5000);
}

// 保存测试结果
async function saveResults() {
    const results = {
        config: CONFIG,
        stats: {
            duration: (Date.now() - STATS.startTime) / 1000,
            connections: {
                total: CONFIG.connections,
                active: STATS.connected,
                failed: STATS.failed
            },
            messages: STATS.messages,
            latency: STATS.latency,
            cpu: STATS.cpu,
            memory: STATS.memory,
            responses: STATS.responses
        },
        timestamp: new Date().toISOString()
    };
    
    const filename = `benchmark_${results.timestamp.replace(/[:.]/g, '-')}.json`;
    await fs.writeFile(filename, JSON.stringify(results, null, 2));
    console.log(`Results saved to ${filename}`);
}

// 定时发送消息
function startMessageLoop(ws, index, proto) {
    return setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
            try {
                const msgId = Date.now();
                const session = {
                    messageId: proto.MessageID.values.C2S_HEARTBEAT,
                    sequence: msgId,
                    timestamp: Date.now(),
                    version: "1.0.0"
                };
                
                // 心跳消息内容
                const heartbeatData = {
                    timestamp: Date.now(),
                    clientId: index
                };
                
                // 编码心跳消息
                const payload = proto.C2SHeartbeat.encode(proto.C2SHeartbeat.create(heartbeatData)).finish();
                
                // 创建基础请求
                const baseRequest = {
                    session: session,
                    payload: payload
                };
                
                // 编码并发送
                const message = proto.BaseRequest.encode(proto.BaseRequest.create(baseRequest)).finish();
                sendWithTimeout(ws, message, msgId);
                
            } catch (error) {
                console.error('Failed to send heartbeat:', error);
                STATS.messages.failed++;
            }
        }
    }, CONFIG.messageInterval);
}

// 在发送消息时添加超时检测
function sendWithTimeout(ws, message, msgId) {
    ws.send(message, { binary: true });
    STATS.messages.sent++;
    STATS.messageTimestamps.set(msgId, Date.now());
    
    // 设置超时检测
    setTimeout(() => {
        if (STATS.messageTimestamps.has(msgId)) {
            STATS.responses.timeout++;
            STATS.messageTimestamps.delete(msgId);
        }
    }, CONFIG.responseTimeout);
}

// 启动测试
startBenchmark().catch(console.error); 