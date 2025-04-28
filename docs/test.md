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

### 3.2 GM 指令测试
```javascript
// test/cases/gm_command_test.js
class GMCommandTest extends BaseTest {
    async testAddItem() {
        // 添加物品测试
        const response = await this.client.gmCommand('add_item', ['1001', '100']);
        assert.strictEqual(response.result, 'success');
        
        // 验证物品数量
        const bagInfo = await this.client.getBagInfo();
        const totalCount = bagInfo.bags[0].items
            .filter(i => i.item_id === 1001)
            .reduce((sum, i) => sum + i.count, 0);
        assert.strictEqual(totalCount, 100);
    }
}
```

#### GM 指令说明

##### 基础指令
| 指令名称    | 参数说明                | 功能描述       | 使用示例                                 |
|------------|------------------------|--------------|----------------------------------------|
| `set_level`  | level                   | 设置角色等级   | `set_level 99`                          |

##### 物品管理指令
| 指令名称    | 参数说明                | 功能描述       | 使用示例                                 |
|------------|------------------------|--------------|----------------------------------------|
| `add_item`   | item_id, count          | 添加物品       | `add_item 1001 100`                     |
| `del_item`   | item_id, count          | 删除物品       | `del_item 1001 50`                      |
| `clear_bag`  | bag_type                | 清空背包       | `clear_bag 1`                           |

##### 伙伴系统指令
| 指令名称           | 参数说明                | 功能描述       | 使用示例                                 |
|-------------------|------------------------|--------------|----------------------------------------|
| `add_partner`      | unit_id                | 添加伙伴       | `add_partner 4301`                      |
| `add_fragments`    | fragment_id, count     | 添加伙伴碎片   | `add_fragments 5301 100`                |
| `set_partner_level`| partner_id, level      | 设置伙伴等级   | `set_partner_level 40113330800919552 50`|
| `set_partner_star` | partner_id, star       | 设置伙伴星级   | `set_partner_star 40113330800919552 5`  |

#### 运行测试
```bash
# 运行所有 GM 测试
node test/run_test.js -t gm_command

# 运行指定测试用例
node test/run_test.js -t gm_command_test add_item     # 测试添加物品
node test/run_test.js -t gm_command_test delete_item  # 测试删除物品
node test/run_test.js -t gm_command_test set_level    # 测试设置等级
node test/run_test.js -t gm_command_test clear_bag    # 测试清空背包
node test/run_test.js -t gm_command_test error_cases  # 测试错误处理
node test/run_test.js -t gm_command_test add_partner  # 测试添加伙伴
node test/run_test.js -t gm_command_test add_fragments # 测试添加碎片
node test/run_test.js -t gm_command_test set_partner_level # 测试设置伙伴等级
node test/run_test.js -t gm_command_test set_partner_star # 测试设置伙伴星级

# 直接执行特定GM命令
node test/run_test.js -t gm_command add_item 1001 100    # 添加指定物品和数量
node test/run_test.js -t gm_command add_partner 4301     # 添加特定伙伴
```

#### 注意事项
- 测试前确保服务器正常运行
- 测试账号需要有 GM 权限
- 背包需要有足够空间
- 物品 1001 和 2012 的最大堆叠数量为 2000
- 伙伴ID (unit_id) 和伙伴实例ID (partner_id) 是不同概念
- 伙伴命令会自动处理伙伴不存在的情况

### 3.3 伙伴系统测试
```javascript
// test/cases/partner/partner_list_test.js
class PartnerListTest extends BaseTest {
    async test() {
        // 获取伙伴列表
        const response = await this.client.getPartnerList();
        assert.strictEqual(response.errorCode, 0);
        
        // 验证列表结构
        assert(Array.isArray(response.partners));
        
        // 检查伙伴状态
        if (response.partners.length > 0) {
            const partner = response.partners[0];
            assert(partner.partner_id > 0);
            assert(partner.unit_id > 0);
            assert([1, 2, 3].includes(partner.state)); // 检查状态是否合法
        }
    }
}

// test/cases/partner/partner_upgrade_test.js
class PartnerUpgradeTest extends BaseTest {
    async test() {
        // 首先获取伙伴列表
        const listResponse = await this.client.getPartnerList();
        assert.strictEqual(listResponse.errorCode, 0);
        
        // 确保至少有一个已解锁的伙伴
        const unlockedPartner = listResponse.partners.find(p => p.state === 1);
        
        if (!unlockedPartner) {
            // 如果没有已解锁的伙伴，使用GM命令添加一个
            await this.client.gmCommand('add_partner', ['4301']);
            const newList = await this.client.getPartnerList();
            const newPartner = newList.partners.find(p => p.state === 1);
            assert(newPartner, "Failed to add test partner");
            
            // 使用新添加的伙伴测试升级
            const upgradeResponse = await this.client.upgradePartner(newPartner.partner_id);
            assert.strictEqual(upgradeResponse.errorCode, 0);
            assert(upgradeResponse.partner.level > newPartner.level);
        } else {
            // 使用已有伙伴测试升级
            const upgradeResponse = await this.client.upgradePartner(unlockedPartner.partner_id);
            assert.strictEqual(upgradeResponse.errorCode, 0);
            assert(upgradeResponse.partner.level > unlockedPartner.level);
        }
    }
}

// test/cases/partner/partner_unlock_test.js
class PartnerUnlockTest extends BaseTest {
    async test() {
        // 先获取一个可解锁状态的伙伴
        const listResponse = await this.client.getPartnerList();
        const unlockablePartner = listResponse.partners.find(p => p.state === 2);
        
        if (!unlockablePartner) {
            // 如果没有可解锁的伙伴，使用GM命令添加足够的碎片
            await this.client.gmCommand('add_fragments', ['4302', '50']);
            const newList = await this.client.getPartnerList();
            const newUnlockable = newList.partners.find(p => p.state === 2);
            assert(newUnlockable, "Failed to create unlockable partner");
            
            // 测试解锁
            const unlockResponse = await this.client.unlockPartner(newUnlockable.unit_id);
            assert.strictEqual(unlockResponse.errorCode, 0);
            assert.strictEqual(unlockResponse.partner.state, 1);
        } else {
            // 测试解锁已有的可解锁伙伴
            const unlockResponse = await this.client.unlockPartner(unlockablePartner.unit_id);
            assert.strictEqual(unlockResponse.errorCode, 0);
            assert.strictEqual(unlockResponse.partner.state, 1);
        }
    }
}
```

#### 运行伙伴系统测试
```bash
# 运行所有伙伴系统测试
node test/run_test.js -t partner

# 运行指定测试用例
node test/run_test.js -t partner_list     # 测试获取伙伴列表
node test/run_test.js -t partner_upgrade  # 测试伙伴升级
node test/run_test.js -t partner_star     # 测试伙伴升星
node test/run_test.js -t partner_unlock   # 测试伙伴解锁
```

#### 伙伴系统GM指令

##### 伙伴管理指令
| 指令名称           | 参数说明                | 功能描述       | 使用示例                                 |
|-------------------|------------------------|--------------|----------------------------------------|
| `add_partner`      | unit_id                | 添加伙伴       | `add_partner 4301`                      |
| `add_fragments`    | fragment_id, count     | 添加伙伴碎片   | `add_fragments 5301 100`                |
| `set_partner_level`| partner_id, level      | 设置伙伴等级   | `set_partner_level 40113330800919552 50`|
| `set_partner_star` | partner_id, star       | 设置伙伴星级   | `set_partner_star 40113330800919552 5`  |

#### 注意事项
- 伙伴升级和升星测试需要足够的材料或经验
- 伙伴解锁测试需要足够的碎片
- 单位ID 4301-4350 为测试用伙伴
- 伙伴ID (unit_id) 是配置表中的单位ID，而伙伴实例ID (partner_id) 是创建后的实例ID
- 测试命令会自动处理伙伴不存在的情况，会先尝试添加伙伴再进行操作
- 如果指定伙伴不可用，测试会尝试使用第一个已解锁的伙伴

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