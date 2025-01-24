# 测试说明

## 测试环境

### 1. 环境要求
- Node.js 14+
- npm 6+
- WebSocket
- Protocol Buffers

### 2. 安装依赖
```bash
cd test
npm install
```

## 测试类型

### 1. 单元测试

#### 用户模块测试
```javascript
// test/unit/user_test.js
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
// test/api/login_test.js
describe('Login API Test', () => {
    it('should login successfully', async () => {
        const response = await client.login({
            account: 'test',
            password: '123456'
        });
        expect(response.code).toBe(0);
        expect(response.data.token).toBeDefined();
    });
});
```

### 3. 压力测试

#### 登录压测
```javascript
// test/benchmark/login_bench.js
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
            return client.login({
                account: `test_${Math.random()}`,
                password: '123456'
            });
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
// test/lib/client.js
class GameClient {
    constructor(config) {
        this.loginServer = config.loginServer;
        this.proto = new ProtoHelper();
    }

    async connect() {
        this.ws = new WebSocket(this.loginServer);
        return new Promise((resolve, reject) => {
            this.ws.on('open', resolve);
            this.ws.on('error', reject);
        });
    }

    async login(params) {
        const request = this.proto.encode('C2LLoginRequest', params);
        this.ws.send(request);
        return this.waitResponse('L2CLoginResponse');
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
            'proto/common/message.proto',
            'proto/command/command.proto'
        ]);
        return root;
    }

    encode(type, data) {
        const message = this.root.lookupType(type);
        return message.encode(data).finish();
    }
}
```

## 测试报告

### 1. 单元测试报告
```bash
# 运行单元测试
npm run test:unit

# 输出结果
PASS test/unit/user_test.js
User Model Test
  ✓ should create user successfully (5ms)
  ✓ should get user info (3ms)
```

### 2. 压测报告
```bash
# 运行压测
npm run benchmark

# 输出结果
Login Benchmark Results:
- Total Requests: 1000
- Concurrent Users: 100
- Success Rate: 99.8%
- Average Response Time: 15ms
- QPS: 658
- P95: 25ms
- P99: 35ms
```

## 持续集成

### 1. GitHub Actions配置
```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
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
        npm run test:unit
        npm run test:api
``` 