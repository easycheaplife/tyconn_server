# 测试说明

## 1. 快速开始

```bash
# 安装依赖
cd test
npm install

# 运行所有测试
node test/run_test.js

# 运行登录测试
node test/run_test.js -t login

# 运行压力测试
node test/benchmark/cli.js run login -c 100 -n 1000
```

## 2. 基础组件

### 2.1 ProtoHelper
```javascript
// test/lib/proto_helper.js
class ProtoHelper {
    constructor() {
        this.root = null;
        this.MessageID = {};
        this.ErrorCode = {
            ERROR_CODE_SUCCESS: 0,
            ERROR_CODE_SYSTEM_ERROR: 1,
            ERROR_CODE_INVALID_PARAM: 2
        };
    }

    async init() {
        // 加载proto文件
        this.root = await protobuf.load([
            'common/message.proto',
            'command/command.proto'
        ]);
    }
}
```

### 2.2 BaseClient
```javascript
// test/lib/base_client.js
class BaseClient {
    constructor() {
        this.ws = null;
        this.protoHelper = new ProtoHelper();
    }

    async connect() {
        const wsUrl = `${this.serverInfo.protocol}://${this.serverInfo.host}:${this.serverInfo.port}`;
        // ... WebSocket 连接逻辑
    }
}
```

## 3. 测试用例

### 3.1 单元测试
```javascript
// test/cases/login_test.js
class LoginTest extends BaseTest {
    async test() {
        // 测试无效登录
        try {
            await this.login('', '123456');
            assert.fail('Should not allow empty account');
        } catch (error) {
            assert.strictEqual(
                error.response.errorCode,
                ProtoHelper.ErrorCode.ERROR_CODE_INVALID_ACCOUNT
            );
        }
    }
}
```

## 4. 压力测试

### 4.1 使用方法
```bash
# 查看帮助
node test/benchmark/cli.js --help

# 运行压测
node test/benchmark/cli.js run login -c 100 -n 1000
node test/benchmark/cli.js run bag -s localhost -p 8022
```

### 4.2 参数说明
```
Options:
  -c, --concurrent <number>  并发用户数
  -n, --total <number>      总请求数
  -t, --timeout <number>    请求超时时间(ms)
  -s, --server <host>       服务器地址
  -p, --port <number>       服务器端口
```

## 5. 性能监控

### 5.1 监控指标
- 并发连接数
- QPS (每秒查询数)
- 响应时间 (平均/最大/最小)
- 错误率
- 内存使用
- CPU使用率

### 5.2 监控方法
```javascript
// 开启监控
monitor.start({
    interval: 1000,    // 采样间隔
    metrics: ['qps', 'rt', 'error']  // 监控指标
});

// 记录请求
monitor.recordRequest(time);

// 获取报告
const report = monitor.getReport();
```

## 6. 调试技巧

### 6.1 环境变量
```bash
# 调试日志
export DEBUG=game:*
export LOG_LEVEL=debug

# 测试环境
export NODE_TLS_REJECT_UNAUTHORIZED=0
export TEST_SERVER=test-server.com
export TEST_PORT=8022
```

### 6.2 错误处理
```javascript
try {
    await client.login('test', '123456');
} catch (error) {
    if (error.response?.errorCode) {
        console.error('Login failed:', error.response.errorMsg);
    } else {
        console.error('Network error:', error);
    }
}
```

更多协议细节请参考 [protocol.md](protocol.md) 