# 测试说明

## 1. 测试架构

### 1.1 基础组件

#### BaseClient
```javascript
class BaseClient {
    constructor() {
        this.ws = null;
        this.protoHelper = new ProtoHelper();
        this.token = null;
        this.serverInfo = null;
    }

    async connect() {
        if (!this.serverInfo) {
            throw new Error('Server info not set');
        }
        const wsUrl = `${this.serverInfo.protocol}://${this.serverInfo.host}:${this.serverInfo.port}`;
        return new Promise((resolve, reject) => {
            this.ws = new WebSocket(wsUrl, {
                rejectUnauthorized: false
            });
            // ... 连接事件处理
        });
    }

    async sendRequest(messageId, requestData) {
        if (!this.ws) {
            throw new Error('Not connected to server');
        }
        const request = this.protoHelper.buildBaseRequest(messageId, requestData);
        return new Promise((resolve, reject) => {
            // ... 发送请求并等待响应
        });
    }

    close() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
    }
}
```

#### LoginClient
```javascript
class LoginClient extends BaseClient {
    constructor() {
        super();
        this.serverInfo = {
            protocol: config.protocol,
            host: config.loginHost,
            port: config.loginPort
        };
    }

    async login(account, password) {
        try {
            await this.connect();
            const loginRequest = {
                account: account,
                password: password,
                platform: config.platform,
                version: config.version,
                deviceId: config.deviceId
            };
            const response = await this.sendRequest('C2L_LOGIN_REQUEST', loginRequest);
            // ... 处理登录响应
            return {
                token: loginResponse.token,
                gateInfo: {
                    protocol: config.protocol,
                    host: loginResponse.ws_addr,
                    port: loginResponse.ws_port
                }
            };
        } finally {
            await this.close();
        }
    }
}
```

#### ProtoHelper
```javascript
class ProtoHelper {
    constructor() {
        this.root = null;
        this.MessageID = {};
        this.initialized = false;
        this.sequence = 0;
        this.ErrorCode = {
            ERROR_CODE_SUCCESS: 0,
            ERROR_CODE_SYSTEM_ERROR: 1,
            ERROR_CODE_INVALID_PARAM: 2,
            ERROR_CODE_INVALID_ACCOUNT: 3,
            // ... 其他错误码
        };
    }

    async init() {
        // 加载 proto 文件
        const protoFiles = [
            'common/message.proto',
            'common/error.proto',
            'command/command.proto'
        ];
        // ... 初始化逻辑
    }

    buildBaseRequest(messageId, payload) {
        return {
            session: {
                messageId: messageId,
                sequence: ++this.sequence,
                timestamp: Date.now(),
                version: "1.0.0"
            },
            payload: payload
        };
    }
}
```

### 1.2 测试用例

#### LoginTest
```javascript
class LoginTest extends LoginClient {
    constructor() {
        super();
        this.name = 'Login Test';
    }

    async test() {
        try {
            // 测试1: 无效的登录请求
            console.log('\nTesting invalid login request...');
            try {
                await this.login('', '123456');
                assert.fail('Should not allow empty account');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    ProtoHelper.ErrorCode.ERROR_CODE_INVALID_ACCOUNT,
                    'Should have invalid account error code'
                );
            }

            // 测试2: 正确的登录
            console.log('\nTesting successful login...');
            const response = await this.login(config.testAccount, config.testPassword);
            assert(response.token, 'Should have token');
            assert(response.gateInfo, 'Should have gate server info');

            return true;
        } catch (error) {
            console.error('Login test failed:', error);
            console.error('Error stack:', error.stack);
            return false;
        }
    }
}
```

## 2. 运行测试

### 2.1 命令行
```bash
# 运行单个测试
node test/run_test.js -t login

# 运行所有测试
node test/run_test.js
```

### 2.2 配置文件
```javascript
// test/config/config.js
module.exports = {
    // 服务器配置
    protocol: WS_PROTOCOL,
    loginHost: SERVER_HOST,
    loginPort: WS_PORT,

    // 客户端配置
    platform: 'test',
    version: '1.0.0',
    requestTimeout: 5000,

    // 测试配置
    testAccount: 'test',
    testPassword: '123456',

    // SSL配置
    ssl: WS_PROTOCOL === 'wss' ? SSL_CONFIG : undefined
};
```

## 3. 错误处理

### 3.1 错误码
```javascript
static ErrorCode = {
    ERROR_CODE_SUCCESS: 0,               // 成功
    ERROR_CODE_SYSTEM_ERROR: 1,         // 系统错误
    ERROR_CODE_INVALID_PARAM: 2,        // 无效参数
    ERROR_CODE_INVALID_ACCOUNT: 3,      // 无效账号
    ERROR_CODE_WRONG_PASSWORD: 4,       // 密码错误
    ERROR_CODE_ACCOUNT_EXISTS: 5,       // 账号已存在
    ERROR_CODE_ACCOUNT_NOT_EXIST: 6,    // 账号不存在
    ERROR_CODE_TOKEN_INVALID: 7,        // 无效的令牌
    ERROR_CODE_TOKEN_EXPIRED: 8,        // 令牌已过期
    ERROR_CODE_SERVER_BUSY: 9,          // 服务器繁忙
    ERROR_CODE_VERSION_MISMATCH: 10,    // 版本不匹配
    ERROR_CODE_GATE_NOT_AVAILABLE: 11,  // 网关不可用
    ERROR_CODE_DB_ERROR: 12,           // 数据库错误
    ERROR_CODE_ITEM_NOT_FOUND: 13,     // 物品不存在
    ERROR_CODE_ITEM_NOT_ENOUGH: 14,    // 物品数量不足
};
```

### 3.2 错误响应处理
```javascript
// 检查错误码
if (response.errorCode !== 0) {  // 直接使用 0 表示成功
    const error = new Error(response.errorMsg || 'Unknown error');
    error.response = response;  // 添加完整的响应对象到错误中
    throw error;
}
```

## 4. 调试技巧

### 4.1 响应日志
```javascript
console.log('\nResponse details:');
console.log('Session:', JSON.stringify(response.session, null, 2));
console.log('Error code:', response.errorCode);
console.log('Error message:', response.errorMsg);
console.log('Raw payload:', response.payload);
```

### 4.2 WebSocket日志
```javascript
this.ws.on('message', (data) => {
    console.log('WebSocket received message:');
    console.log('- Length:', data.length);
    console.log('- Type:', typeof data);
    console.log('- Buffer:', Buffer.isBuffer(data));
    console.log('- Hex:', data.toString('hex').toUpperCase());
});
```

## 测试环境

### 1. 环境要求
- Node.js 14+
- npm 6+
- WebSocket
- Protocol Buffers

### 2. SSL测试说明
当使用wss协议进行测试时，如果使用自签名证书，需要设置以下环境变量：
```bash
# 忽略SSL证书验证(仅用于测试环境)
export NODE_TLS_REJECT_UNAUTHORIZED=0
```
或在测试配置中设置:
```javascript
ssl: {
    rejectUnauthorized: false
}
```

### 2. 安装依赖
```bash
cd test
npm install
```

## 测试类型

### 1. 单元测试

#### 用户模块测试
```javascript
// test/tests/user_info_test.js
describe('User Model Test', () => {
    it('should create user successfully', async () => {
        const user = {
            name: 'test_user',
            password: '123456'
        };
        const result = await UserModel.create(user);
        expect(result.name).toBe(user.name);
        expect(result.level).toBe(1);
    });
});
```

### 2. 接口测试

#### 登录测试
```javascript
// test/tests/login_test.js
describe('Login API Test', () => {
    it('should login successfully', async () => {
        const request = loginRequestBuilder.build({
            account: 'test',
            password: '123456'
        });
        const response = await client.send(request);
        expect(response.code).toBe(0);
        expect(response.data.token).toBeDefined();
    });
});
```

### 3. 压力测试

#### 登录压测
```javascript
// test/tests/login_test.js
async function loginBenchmark() {
    const concurrent = 100;  // 并发数
    const total = 1000;     // 总请求数
    
    console.log('Starting login benchmark...');
    console.log(`Concurrent: ${concurrent}`);
    console.log(`Total: ${total}`);
    
    const results = await benchmark({
        concurrent,
        total,
        fn: async () => {
            const request = loginRequestBuilder.build({
                account: `test_${Math.random()}`,
                password: '123456'
            });
            return client.send(request);
        }
    });
    
    console.log('Benchmark Results:');
    console.log(`Success Rate: ${results.successRate}%`);
    console.log(`Average Time: ${results.avgTime}ms`);
    console.log(`QPS: ${results.qps}`);
}
```

#### 性能指标
- 并发用户数
- 登录成功率
- 响应时间
- CPU使用率
- 内存占用
- 网络流量

## 调试指南

### 1. 日志说明
- DEBUG: 调试信息
- INFO: 普通信息
- WARN: 警告信息
- ERROR: 错误信息
- FATAL: 致命错误

### 2. 关键节点日志
- 连接建立/断开
- 消息收发
- 错误异常
- 状态变更

## 测试工具

### 1. 测试客户端
```javascript
// test/client.js
class GameClient {
    constructor(config) {
        this.loginServer = config.loginServer;
        this.wsClient = new WSClient(config);
        this.responseHandler = new ResponseHandler();
    }

    async connect() {
        return this.wsClient.connect();
    }

    async send(request) {
        const response = await this.wsClient.send(request);
        return this.responseHandler.handle(response);
    }
}
```

### 2. Proto工具
```javascript
// test/lib/proto_helper.js
class ProtoHelper {
    async loadProtos() {
        const root = new protobuf.Root();
        await root.load([
            'proto/command/command.proto',
            'proto/common/error.proto',
            'proto/common/message.proto',
            'proto/common/user.proto'
        ]);
        return root;
    }

    encode(type, data) {
        const message = this.root.lookupType(type);
        return message.encode(data).finish();
    }
}
```

### 3. 请求构建器
```javascript
// test/builders/login_request_builder.js
class LoginRequestBuilder {
    build(params) {
        return {
            session: {
                messageId: 1,
                sequence: 1,
                timestamp: Date.now(),
                version: "1.0.0"
            },
            payload: params
        };
    }
}
```

## 测试报告

### 1. 测试结果输出
```javascript
// test/run_test.js
async function runTests() {
    const args = parseArgs();
    console.log('\nStarting tests...');
    let passed = 0;
    let failed = 0;

    try {
        // 获取token和服务器信息
        let token, gateInfo;
        if (args.token) {
            // 使用命令行提供的token
            token = args.token;
            gateInfo = {
                protocol: config.protocol,
                host: args.server || config.loginHost,
                port: args.port || config.loginPort
            };
        } else {
            // 登录获取token
            console.log('Logging in...');
            const loginClient = new LoginClient();
            const loginResult = await loginClient.login(
                config.testAccount,
                config.testPassword
            );
            token = loginResult.token;
            gateInfo = loginResult.gateInfo;
            console.log('Login successful');
        }

        // 确定要运行的测试用例
        let testsToRun = [];
        if (args.test) {
            // 运行指定的测试
            const TestClass = ALL_TESTS[args.test];
            if (!TestClass) {
                throw new Error(`Unknown test case: ${args.test}`);
            }
            testsToRun = [new TestClass()];
        } else {
            // 运行所有测试
            testsToRun = Object.values(ALL_TESTS).map(TestClass => new TestClass());
        }

        // 运行测试用例
        for (const testCase of testsToRun) {
            const result = await testCase.run(token, gateInfo);
            if (result) {
                passed++;
            } else {
                failed++;
            }
        }

        // 打印测试结果
        console.log('\nTest Summary:');
        console.log(`Total: ${testsToRun.length}`);
        console.log(`Passed: ${passed}`);
        console.log(`Failed: ${failed}`);

        // 如果有失败的测试，退出码设为1
        if (failed > 0) {
            process.exit(1);
        }
    } catch (error) {
        console.error('\nTest runner failed:', error);
        process.exit(1);
    }
}
```

### 2. 测试用例结果
```bash
Starting tests...
Logging in...
Login successful

Running test: Login Test
Testing invalid login request...
Testing successful login...
✓ Login test passed

Running test: User Info Test
Testing get user info...
✓ User info test passed

Running test: Heartbeat Test
Testing heartbeat...
✓ Heartbeat test passed

Test Summary:
Total: 3
Passed: 3
Failed: 0
```

### 3. 错误输出示例
```bash
Testing invalid login request...
Error details:
- Error code: 3
- Error message: "账号不能为空"
- Stack: Error: 账号不能为空
    at LoginTest.test (/test/cases/login_test.js:25:19)
    at runTest (/test/run_test.js:45:33)
    ...

Test Summary:
Total: 1
Passed: 0
Failed: 1
```

### 4. 可用的测试用例
```javascript
// test/run_test.js
const ALL_TESTS = {
    user_info: UserInfoTest,
    heartbeat: HeartbeatTest,
    user_cards: UserCardsTest,
    bag_info: BagInfoTest,
    use_item: UseItemTest,
    token: TokenTest,
    login: LoginTest
};
```

### 5. 命令行参数
```bash
# 运行指定测试
node test/run_test.js -t login

# 使用已有token运行测试
node test/run_test.js --token <jwt_token>

# 指定服务器运行测试
node test/run_test.js --server localhost --port 8021
```

## 5. 协议测试

### 5.1 基础消息结构

#### BaseRequest
```protobuf
message BaseRequest {
    Session session = 1;    // 会话信息
    bytes payload = 2;      // 具体请求数据
}

message Session {
    int32 messageId = 1;    // 消息ID
    int32 sequence = 2;     // 序列号
    int64 timestamp = 3;    // 时间戳
    string version = 4;     // 版本号
}
```

#### BaseResponse
```protobuf
message BaseResponse {
    Session session = 1;    // 会话信息
    int32 errorCode = 2;    // 错误码
    string errorMsg = 3;    // 错误信息
    bytes payload = 4;      // 具体响应数据
}
```

### 5.2 业务消息测试

#### 登录消息
```javascript
// 登录请求
const loginRequest = {
    account: 'test',
    password: '123456',
    platform: 'test',
    version: '1.0.0',
    deviceId: 'test_device'
};

// 登录响应
const loginResponse = {
    token: 'jwt_token',
    ws_addr: '127.0.0.1',
    ws_port: 8022
};
```

#### 背包消息
```javascript
// 背包请求
const bagRequest = {
    token: 'jwt_token'
};

// 背包响应
const bagResponse = {
    items: [
        {
            id: 1001,
            count: 10,
            type: 1
        }
    ]
};
```

### 5.3 协议测试用例

#### 协议编解码测试
```javascript
class ProtocolTest extends BaseTest {
    async test() {
        try {
            // 测试1: 登录请求编码
            const loginRequest = {
                account: 'test',
                password: '123456',
                platform: 'test',
                version: '1.0.0',
                deviceId: 'test_device'
            };
            const encoded = this.protoHelper.encode(
                'command.C2L_LOGIN_REQUEST',
                loginRequest
            );
            assert(Buffer.isBuffer(encoded), 'Should encode to buffer');

            // 测试2: 登录响应解码
            const decoded = this.protoHelper.decode(
                'command.L2C_LOGIN_RESPONSE',
                encoded
            );
            assert(decoded.token, 'Should have token');
            assert(decoded.ws_addr, 'Should have ws_addr');
            assert(decoded.ws_port, 'Should have ws_port');

            return true;
        } catch (error) {
            console.error('Protocol test failed:', error);
            return false;
        }
    }
}
```

## 6. 集成测试

### 6.1 登录流程测试
```javascript
class LoginFlowTest extends BaseTest {
    async test() {
        try {
            // 1. 登录获取token
            const loginResult = await this.loginClient.login('test', '123456');
            assert(loginResult.token, 'Should have token');

            // 2. 连接游戏服务器
            const gameClient = new GameClient(loginResult.gateInfo);
            await gameClient.connect();
            await gameClient.auth(loginResult.token);

            // 3. 获取用户信息
            const userInfo = await gameClient.getUserInfo();
            assert(userInfo.account === 'test', 'Should get correct user info');

            // 4. 心跳测试
            await gameClient.heartbeat();

            return true;
        } catch (error) {
            console.error('Login flow test failed:', error);
            return false;
        }
    }
}
```

### 6.2 背包流程测试
```javascript
class BagFlowTest extends BaseTest {
    async test() {
        try {
            // 1. 获取背包信息
            const bagInfo = await this.gameClient.getBagInfo();
            assert(Array.isArray(bagInfo.items), 'Should have items array');

            // 2. 使用物品
            if (bagInfo.items.length > 0) {
                const item = bagInfo.items[0];
                const useResult = await this.gameClient.useItem(item.id, 1);
                assert(useResult.items, 'Should have updated items');
            }

            return true;
        } catch (error) {
            console.error('Bag flow test failed:', error);
            return false;
        }
    }
}
```

## 7. 测试工具函数

### 7.1 断言工具
```javascript
const assert = {
    // 验证错误码
    errorCode: (error, expectedCode, message) => {
        assert.strictEqual(
            error.response.errorCode,
            expectedCode,
            message || `Should have error code ${expectedCode}`
        );
    },

    // 验证响应数据
    response: (response, checks) => {
        Object.entries(checks).forEach(([key, value]) => {
            assert.strictEqual(response[key], value);
        });
    }
};
```

### 7.2 测试辅助函数
```javascript
// 随机测试数据生成器
const testData = {
    randomAccount: () => `test_${Math.random().toString(36).slice(2)}`,
    randomPassword: () => Math.random().toString(36).slice(2),
    randomDeviceId: () => `device_${Math.random().toString(36).slice(2)}`
};

// 测试结果收集器
class TestResults {
    constructor() {
        this.passed = 0;
        this.failed = 0;
        this.results = [];
    }

    add(testName, success, error) {
        this.results.push({ testName, success, error });
        if (success) this.passed++;
        else this.failed++;
    }

    summary() {
        return {
            total: this.passed + this.failed,
            passed: this.passed,
            failed: this.failed,
            results: this.results
        };
    }
}
```

## 8. 压力测试

### 8.1 压测工具
```javascript
// test/lib/benchmark.js
class Benchmark {
    constructor(options) {
        this.concurrent = options.concurrent || 100;  // 并发数
        this.total = options.total || 1000;          // 总请求数
        this.timeout = options.timeout || 5000;      // 超时时间
        this.results = {
            success: 0,
            failed: 0,
            times: [],
            errors: []
        };
    }

    async run(fn) {
        console.log('Starting benchmark...');
        console.log(`Concurrent: ${this.concurrent}`);
        console.log(`Total: ${this.total}`);

        const batches = Math.ceil(this.total / this.concurrent);
        for (let i = 0; i < batches; i++) {
            const count = Math.min(this.concurrent, this.total - i * this.concurrent);
            const promises = Array(count).fill().map(() => this.execute(fn));
            await Promise.all(promises);
        }

        return this.getReport();
    }

    async execute(fn) {
        const start = Date.now();
        try {
            await fn();
            this.results.success++;
            this.results.times.push(Date.now() - start);
        } catch (error) {
            this.results.failed++;
            this.results.errors.push(error);
        }
    }

    getReport() {
        const total = this.results.times.length;
        const avgTime = total > 0 
            ? this.results.times.reduce((a, b) => a + b) / total 
            : 0;
        const sorted = [...this.results.times].sort((a, b) => a - b);
        
        return {
            total: this.total,
            success: this.results.success,
            failed: this.results.failed,
            avgTime: Math.round(avgTime),
            p95: sorted[Math.floor(total * 0.95)] || 0,
            p99: sorted[Math.floor(total * 0.99)] || 0,
            qps: Math.round(this.results.success * 1000 / (Date.now() - this.startTime))
        };
    }
}
```

### 8.2 压测用例

#### 登录压测
```javascript
// test/benchmark/login_benchmark.js
async function loginBenchmark() {
    const benchmark = new Benchmark({
        concurrent: 100,
        total: 1000
    });

    const report = await benchmark.run(async () => {
        const client = new LoginClient();
        await client.login('test', '123456');
    });

    console.log('\nLogin Benchmark Results:');
    console.log(`Total Requests: ${report.total}`);
    console.log(`Success: ${report.success}`);
    console.log(`Failed: ${report.failed}`);
    console.log(`Average Time: ${report.avgTime}ms`);
    console.log(`QPS: ${report.qps}`);
}
```

#### 背包压测
```javascript
// test/benchmark/bag_benchmark.js
async function bagBenchmark() {
    const benchmark = new Benchmark({
        concurrent: 50,
        total: 500
    });

    const report = await benchmark.run(async () => {
        const client = new GameClient(gateInfo);
        await client.connect();
        await client.auth(token);
        await client.getBagInfo();
    });

    console.log('\nBag Info Benchmark Results:');
    console.log(`Total Requests: ${report.total}`);
    console.log(`Success: ${report.success}`);
    console.log(`Failed: ${report.failed}`);
    console.log(`Average Time: ${report.avgTime}ms`);
    console.log(`QPS: ${report.qps}`);
}
```

### 8.3 压测报告示例
```bash
Login Benchmark Results:
- Total Requests: 1000
- Success: 998
- Failed: 2
- Success Rate: 99.8%
- Average Time: 15ms
- QPS: 658
- P95: 25ms
- P99: 35ms

Error Distribution:
- ERROR_CODE_SYSTEM_ERROR: 1
- ERROR_CODE_SERVER_BUSY: 1

System Metrics:
- CPU Usage: 75%
- Memory: 512MB
- Network I/O: 15MB/s
```

## 9. 持续集成

### 9.1 GitHub Actions
```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      redis:
        image: redis
        ports:
          - 6379:6379
      
      mongodb:
        image: mongo
        ports:
          - 27017:27017

    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '14'
        
    - name: Install Dependencies
      run: |
        cd test
        npm install
        
    - name: Run Tests
      run: |
        npm test
        
    - name: Run Benchmark
      run: |
        npm run benchmark
        
    - name: Upload Test Results
      if: always()
      uses: actions/upload-artifact@v2
      with:
        name: test-results
        path: test/results
```

### 9.2 测试覆盖率
```bash
# 运行覆盖率测试
npm run test:coverage

# 输出结果
-------------------|---------|----------|---------|---------|-------------------
File              | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s 
-------------------|---------|----------|---------|---------|-------------------
All files         |   85.71 |    76.92 |   88.89 |   85.71 |                   
 base_client.js   |   90.91 |    83.33 |   85.71 |   90.91 | 45               
 login_client.js  |   84.62 |    75.00 |   83.33 |   84.62 | 28,42            
 proto_helper.js  |   81.82 |    72.73 |   80.00 |   81.82 | 62,98,142        
-------------------|---------|----------|---------|---------|-------------------
```

## 10. 压力测试工具

### 10.1 命令行工具

压测工具提供了命令行界面，支持以下命令：

```bash
# 查看帮助
npm run benchmark -- --help

# 列出所有可用的压测
npm run benchmark list

# 运行指定的压测
npm run benchmark run <name> [options]
```

### 10.2 可用选项

```bash
Options:
  -c, --concurrent <number>  并发用户数
  -n, --total <number>      总请求数
  -t, --timeout <number>    请求超时时间(ms)
  -s, --server <host>       服务器地址
  -p, --port <number>       服务器端口
  --account <string>        测试账号
  --password <string>       测试密码
  -h, --help               显示帮助信息
```

### 10.3 压测用例

#### 登录压测
```bash
# 默认配置
npm run benchmark run login

# 自定义配置
npm run benchmark run login -c 100 -n 1000 -t 5000
```

默认参数：
- 并发数: 100
- 总请求数: 1000
- 超时时间: 5000ms

#### 背包压测
```bash
# 默认配置
npm run benchmark run bag

# 自定义配置
npm run benchmark run bag -c 50 -n 500
```

默认参数：
- 并发数: 50
- 总请求数: 500
- 超时时间: 3000ms

#### 心跳压测
```bash
# 默认配置
npm run benchmark run heartbeat

# 自定义配置
npm run benchmark run heartbeat -c 200 -n 2000
```

默认参数：
- 并发数: 200
- 总请求数: 2000
- 超时时间: 1000ms

#### 物品使用压测
```bash
# 默认配置
npm run benchmark run useItem

# 自定义配置
npm run benchmark run useItem -c 20 -n 100
```

默认参数：
- 并发数: 20
- 总请求数: 100
- 超时时间: 3000ms

### 10.4 压测报告

每次压测完成后会生成详细的报告：

```bash
Benchmark Results:
--------------------------------------------------
Total Requests: 1000
Success: 998
Failed: 2
Success Rate: 99.8%
Average Time: 15ms
QPS: 658
P95: 25ms
P99: 35ms
Duration: 1.5s

Error Distribution:
- ERROR_CODE_SYSTEM_ERROR: 1
- ERROR_CODE_SERVER_BUSY: 1
```

报告包含以下指标：
- 总请求数
- 成功/失败数
- 成功率
- 平均响应时间
- QPS (每秒查询数)
- P95/P99 响应时间
- 总耗时
- 错误分布

### 10.5 注意事项

1. 登录压测
   - 使用随机账号避免冲突
   - 建议使用较低并发

2. 背包压测
   - 需要先登录获取token
   - 每个请求都会创建新的连接

3. 心跳压测
   - 使用单个长连接
   - 可以使用较高的并发

4. 物品使用压测
   - 需要确保有可用的物品
   - 使用较低的并发避免数据竞争
   - 每个请求使用相同的物品ID

### 10.6 配置文件

可以通过环境变量或配置文件修改默认配置：

```javascript
// test/config/config.js
module.exports = {
    // 服务器配置
    protocol: process.env.WS_PROTOCOL || 'ws',
    loginHost: process.env.SERVER_HOST || '127.0.0.1',
    loginPort: process.env.WS_PORT || 8021,

    // 测试配置
    testAccount: process.env.TEST_ACCOUNT || 'test',
    testPassword: process.env.TEST_PASSWORD || '123456',
    requestTimeout: 5000
};
```

也可以通过命令行参数临时修改配置：
```bash
npm run benchmark run login \
    -s test-server.com \
    -p 8022 \
    --account test_user \
    --password test_pass
```

## 11. 协议测试

### 11.1 消息定义

```protobuf
// proto/command/command.proto
message C2L_LOGIN_REQUEST {
    string account = 1;
    string password = 2;
    string platform = 3;
    string version = 4;
    string device_id = 5;
}

message L2C_LOGIN_RESPONSE {
    string token = 1;
    string ws_addr = 2;
    int32 ws_port = 3;
}
```

### 11.2 协议测试用例

```javascript
class ProtocolTest extends BaseTest {
    async test() {
        try {
            // 测试1: 登录请求编码
            const loginRequest = {
                account: 'test',
                password: '123456',
                platform: 'test',
                version: '1.0.0',
                deviceId: 'test_device'
            };
            const encoded = this.protoHelper.encode(
                'command.C2L_LOGIN_REQUEST',
                loginRequest
            );
            assert(Buffer.isBuffer(encoded), 'Should encode to buffer');

            // 测试2: 登录响应解码
            const decoded = this.protoHelper.decode(
                'command.L2C_LOGIN_RESPONSE',
                encoded
            );
            assert(decoded.token, 'Should have token');
            assert(decoded.ws_addr, 'Should have ws_addr');
            assert(decoded.ws_port, 'Should have ws_port');

            return true;
        } catch (error) {
            console.error('Protocol test failed:', error);
            return false;
        }
    }
}
```

### 11.3 协议版本测试

```javascript
class VersionTest extends BaseTest {
    async test() {
        try {
            // 测试1: 旧版本
            try {
                await this.login('test', '123456', '0.9.0');
                assert.fail('Should not allow old version');
            } catch (error) {
                assert.strictEqual(
                    error.response.errorCode,
                    ProtoHelper.ErrorCode.ERROR_CODE_VERSION_MISMATCH
                );
            }

            // 测试2: 当前版本
            const response = await this.login('test', '123456', '1.0.0');
            assert(response.token, 'Should login successfully');

            return true;
        } catch (error) {
            console.error('Version test failed:', error);
            return false;
        }
    }
}
```

## 12. 性能监控

### 12.1 服务器监控

```lua
-- service/login/network/ws_server.lua
local function monitor_performance()
    local stats = {
        connections = ws_server:get_connection_count(),
        requests = request_count,
        errors = error_count,
        memory = collectgarbage("count") * 1024,
        cpu_time = os.clock()
    }
    
    -- 记录到 Redis
    local json = require("cjson")
    redis:set("server:stats", json.encode(stats))
end
```

### 12.2 客户端监控

```javascript
class PerformanceMonitor {
    constructor() {
        this.stats = {
            requestCount: 0,
            errorCount: 0,
            totalTime: 0,
            maxTime: 0,
            minTime: Number.MAX_VALUE
        };
    }

    recordRequest(time) {
        this.stats.requestCount++;
        this.stats.totalTime += time;
        this.stats.maxTime = Math.max(this.stats.maxTime, time);
        this.stats.minTime = Math.min(this.stats.minTime, time);
    }

    recordError(error) {
        this.stats.errorCount++;
    }

    getReport() {
        return {
            requests: this.stats.requestCount,
            errors: this.stats.errorCount,
            avgTime: this.stats.totalTime / this.stats.requestCount,
            maxTime: this.stats.maxTime,
            minTime: this.stats.minTime,
            errorRate: (this.stats.errorCount / this.stats.requestCount * 100).toFixed(2)
        };
    }
}
```

### 12.3 监控报告

```bash
Server Metrics:
--------------------------------------------------
Active Connections: 156
Request Count: 15689
Error Count: 23
Memory Usage: 512MB
CPU Time: 45.6s

Client Metrics:
--------------------------------------------------
Total Requests: 1000
Error Count: 5
Average Time: 15ms
Max Time: 89ms
Min Time: 8ms
Error Rate: 0.5%

Network Metrics:
--------------------------------------------------
Bytes Sent: 1.5MB
Bytes Received: 2.8MB
Packets Lost: 0
Average Latency: 12ms
```

### 12.4 性能分析

```javascript
const profiler = require('v8-profiler-next');

async function runProfiler(duration) {
    // 开始 CPU 分析
    profiler.startProfiling('CPU Profile');
    
    // 运行测试
    await runTest();
    
    // 停止分析并保存结果
    const profile = profiler.stopProfiling();
    profile.export()
        .pipe(fs.createWriteStream(`profile-${Date.now()}.cpuprofile`));
    
    // 内存分析
    const snapshot = profiler.takeHeapSnapshot();
    snapshot.export()
        .pipe(fs.createWriteStream(`heap-${Date.now()}.heapsnapshot`));
}
``` 