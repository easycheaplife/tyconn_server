# TyConn 游戏服务器框架

## 架构概览

### 服务器组成
- 登录服务器 (Login Server)
- 网关服务器 (Gate Server)
- 游戏服务器 (Game Server)
- 数据库代理 (DB Proxy)

### 目录结构
    ├── doc/                    # 文档
    │   └── README.md          # 项目说明文档
    ├── etc/                   # 配置文件
    │   ├── config/           # 具体配置
    │   │   ├── login.lua     # 登录服务器配置
    │   │   ├── game1.lua     # 游戏服务器1配置
    │   │   ├── game2.lua     # 游戏服务器2配置
    │   │   ├── gate1.lua     # 网关服务器1配置
    │   │   ├── gate2.lua     # 网关服务器2配置
    │   │   ├── mysql.lua     # MySQL数据库配置
    │   │   └── db_proxy.lua  # 数据库代理配置
    │   └── cluster.lua       # 集群配置
    ├── lualib/               # Lua库
    │   ├── cluster_util.lua  # 集群工具
    │   ├── db/              # 数据库相关
    │   │   ├── mysql.lua    # MySQL操作封装
    │   │   └── pool.lua     # 连接池实现
    │   ├── jwt.lua          # JWT实现
    │   ├── logger.lua       # 日志库
    │   ├── node_selector.lua # 节点选择器
    │   ├── protoloader.lua  # Proto加载器
    │   ├── utils.lua        # 通用工具函数
    │   └── websocket.lua    # WebSocket库
    ├── nginx/               # Nginx配置
    │   └── conf/
    │       └── game.conf    # 游戏服务器配置
    ├── proto/               # 协议定义
    │   ├── command/        # 命令协议
    │   │   └── command.proto
    │   ├── common/         # 通用协议
    │   │   ├── error.proto
    │   │   ├── message.proto
    │   │   └── user.proto
    │   └── internal/       # 内部协议
    │       └── service.proto
    ├── scripts/            # 脚本工具
    │   └── server.sh      # 服务器管理脚本
    ├── service/           # 服务实现
    │   ├── db_proxy/     # 数据库代理服务
    │   │   ├── cache/    # 缓存实现
    │   │   │   └── cache.lua
    │   │   ├── const.lua # 常量定义
    │   │   ├── db/       # 数据库操作
    │   │   │   └── pool.lua
    │   │   ├── models/   # 数据模型
    │   │   │   ├── token.lua
    │   │   │   └── user.lua
    │   │   ├── server.lua
    │   │   ├── sql/      # SQL定义
    │   │   │   └── user.lua
    │   │   └── utils/    # 工具函数
    │   │       └── db_util.lua
    │   ├── game/        # 游戏服务
    │   │   ├── cmd_mgr.lua
    │   │   ├── handlers/  # 消息处理器
    │   │   │   ├── heartbeat.lua
    │   │   │   └── user_info.lua
    │   │   ├── message_mgr.lua
    │   │   ├── models/   # 游戏模型
    │   │   │   └── user.lua
    │   │   ├── server.lua
    │   │   ├── user_mgr.lua
    │   │   └── utils/    # 工具函数
    │   │       ├── message.lua
    │   │       └── name_generator.lua
    │   ├── gate/       # 网关服务
    │   │   ├── agent.lua
    │   │   ├── manager.lua
    │   │   └── server.lua
    │   ├── login/      # 登录服务
    │   │   ├── gate_mgr.lua
    │   │   ├── handlers/
    │   │   │   └── login_handler.lua
    │   │   ├── login_mgr.lua
    │   │   ├── network/
    │   │   │   └── ws_server.lua
    │   │   └── server.lua
    │   └── node/      # 节点启动脚本
    │       ├── db_proxy.lua
    │       ├── game.lua
    │       ├── gate.lua
    │       └── login.lua
    └── test/         # 测试工具
        ├── builders/ # 请求构建器
        │   ├── get_user_info_builder.js
        │   ├── heartbeat_builder.js
        │   └── login_request_builder.js
        ├── client.js # 测试客户端
        ├── config/   # 测试配置
        │   └── config.js
        ├── lib/      # 测试库
        │   ├── proto_helper.js
        │   ├── response_handler.js
        │   └── ws_client.js
        ├── package.json
        └── tests/    # 测试用例
            ├── heartbeat_test.js
            ├── login_test.js
            └── user_info_test.js

## 服务器功能

### 1. 登录服务器
- 处理客户端登录请求
- 验证账号密码
- 生成和管理JWT Token
- 分配负载最低的网关服务器
- 监控网关状态

### 2. 网关服务器
- 维护WebSocket连接
- 心跳检测
- 消息转发
- 连接状态管理
- 负载上报

### 3. 游戏服务器
- 验证用户Token
- 管理用户会话
- 处理游戏逻辑
- 同步游戏状态

### 4. 数据库代理
- 数据库连接池管理
- Token缓存和自动续期
- 事务支持
- 数据模型封装

## 登录流程

### 1. 客户端登录
    [Client] ----> [Login Server]
    | |
    | | 1. 验证账号密码
    | | 2. 生成JWT Token
    | | 3. 选择网关
    | |
    |<-------------|
    | |
    | |
    [Client] ----> [Gate Server]
    | |
    | | 1. 验证Token
    | | 2. 创建连接
    | |
    |<-------------|
    | |
    [Client] <----> [Game Server]

### 2. 协议示例

#### 登录请求
```json
    {
        "cmd": "login",
        "params": {
        "account": "test",
        "password": "123456",
        "device_id": "test_device",
        "platform": "test",
        "version": "1.0.0"
    }
}
```

#### 登录响应
```json
{
    "cmd": "login",
    "result": {
        "code": 0,
        "token": "xxx.yyy.zzz",
        "gate": {
            "host": "127.0.0.1",
            "port": 5001
        }
    }
}
```

## 配置说明

### 1. 登录服务器 (etc/config/login.lua)
```lua
include "../config/path.lua"

thread = 8
harbor = 0
start = "node/login"
node_name = "login"

-- JWT配置
jwt_secret = "your_jwt_secret_key"
jwt_expire = 3600

-- 日志配置
LOG_LEVEL = 1
```

### 2. 游戏服务器 (etc/config/game1.lua)
```lua
include "../config/path.lua"

thread = 8
harbor = 0
start = "node/game"
node_name = "game1"

-- 心跳配置
heartbeat_timeout = 180

-- 日志配置
LOG_LEVEL = 1
```

## 关键特性

### 1. Token管理
- JWT格式保证安全性
- 自动续期机制
- 多级缓存支持
- 过期清理

### 2. 网关管理
- 动态负载均衡
- 心跳检测
- 自动清理超时连接
- 状态监控

### 3. 数据库代理
- 连接池管理
- 自动重连
- 事务支持
- 查询缓存

## 错误码说明
| 错误码 | 说明 |
|--------|------|
| 0 | 成功 |
| 1 | 系统错误 |
| 2 | 参数错误 |
| 3 | 账号或密码错误 |
| 4 | Token无效 |
| 5 | 版本过低 |

## 测试工具

### 配置 (test/config/config.js)
```javascript
module.exports = {
    loginServer: 'ws://127.0.0.1:8021',
    account: 'test',
    password: '123456',
    deviceId: 'test_device',
    platform: 'test',
    version: '1.0.0'
};
```

## 部署说明

### 启动顺序
1. 数据库代理: `./skynet etc/config/db_proxy.lua`
2. 登录服务器: `./skynet etc/config/login.lua`
3. 游戏服务器: `./skynet etc/config/game1.lua`
4. 网关服务器: `./skynet etc/config/gate1.lua`

### 注意事项
- 确保MySQL服务已启动
- 检查配置文件中的地址和端口
- 确保JWT密钥在所有服务器上一致
- 建议使用supervisor等工具管理进程

## 开发指南

### 1. 添加新的消息处理
```lua
-- service/game/handlers/new_handler.lua
local M = {}

function M.handle(client, params)
    -- 验证参数
    if not params.some_param then
        return {code = 2, message = "Missing parameter"}
    end
    
    -- 处理逻辑
    local result = do_something(params)
    
    -- 返回结果
    return {code = 0, data = result}
end

return M
```

### 2. 添加新的数据模型
```lua
-- service/db_proxy/models/new_model.lua
local M = {}

-- 创建记录
function M.create(data)
    return db_util.transaction(function()
        -- 数据库操作
        local sql = string.format([[
            INSERT INTO table_name (field1, field2)
            VALUES (%s, %s)
        ]], 
        db_util.escape(data.field1),
        db_util.escape(data.field2))
        
        return db_util.query(sql)
    end)
end

return M
```

## 调试指南

### 1. 日志级别
```lua
-- 日志级别说明
LOG_LEVEL = 0  -- DEBUG: 所有日志
LOG_LEVEL = 1  -- INFO: 信息、警告和错误
LOG_LEVEL = 2  -- WARN: 警告和错误
LOG_LEVEL = 3  -- ERROR: 只显示错误
```

### 2. 常见问题

#### 连接问题
- 检查网关服务器状态
- 确认防火墙配置
- 验证WebSocket连接参数

#### Token问题
- 检查JWT密钥配置
- 确认Token是否过期
- 查看Token续期日志

#### 数据库问题
- 检查连接池状态
- 确认事务是否正确提交
- 查看查询性能日志

## 性能优化

### 1. 连接池配置
```lua
-- service/db_proxy/db/pool.lua
local pool = {
    max_size = 10,     -- 最大连接数
    min_size = 2,      -- 最小连接数
    idle_timeout = 60  -- 空闲超时(秒)
}
```

### 2. 缓存策略
```lua
-- service/db_proxy/cache/cache.lua
local CACHE_CONFIG = {
    max_items = 10000,  -- 最大缓存条目
    ttl = 3600,        -- 缓存时间(秒)
    clean_interval = 60 -- 清理间隔(秒)
}
```

## 监控指标

### 1. 系统状态
- CPU使用率
- 内存占用
- 连接数量
- 响应时间

### 2. 业务指标
- 在线用户数
- 登录成功率
- Token续期率
- 数据库性能

## 安全说明

### 1. Token安全
- 使用JWT保证安全性
- 定期轮换密钥
- 控制Token有效期
- 支持Token吊销

### 2. 通信安全
- WebSocket over TLS
- 消息加密
- 防重放攻击
- 参数验证

## 服务器通信

### 1. 集群通信
```lua
-- 调用其他节点的服务
local cluster = require "skynet.cluster"

-- 同步调用
local ok, result = pcall(cluster.call, "game1", "@game_server", "verify_token", account, token)

-- 异步调用
cluster.send("game1", "@game_server", "broadcast", message)
```

### 2. 服务间通信
```lua
-- 同一节点内服务通信
local skynet = require "skynet"

-- 同步调用
local result = skynet.call(service_addr, "lua", "cmd", ...)

-- 异步调用
skynet.send(service_addr, "lua", "notify", ...)
```

## 数据库操作

### 1. 事务示例
```lua
-- 使用事务包装器
return db_util.transaction(function()
    -- 查询数据
    local user = db_util.query([[
        SELECT * FROM users 
        WHERE account = %s
        FOR UPDATE
    ]], account)
    
    -- 更新数据
    local ok = db_util.query([[
        UPDATE users SET 
        gold = gold + %d
        WHERE account = %s
    ]], amount, account)
    
    if not ok then
        return false, "Update failed"
    end
    
    return true
end)
```

### 2. 缓存使用
```lua
-- 带缓存的查询
local function get_user_with_cache(account)
    -- 查询缓存
    local cached = cache.get("user:" .. account)
    if cached then
        return cached
    end
    
    -- 查询数据库
    local user = db_util.query([[
        SELECT * FROM users
        WHERE account = %s
    ]], account)
    
    -- 更新缓存
    if user then
        cache.set("user:" .. account, user, 3600)
    end
    
    return user
end
```

## 测试指南

### 1. 单元测试
```javascript
// test/login_test.js
const WebSocket = require('ws');
const assert = require('assert');
const config = require('./config/config');

describe('Login Tests', () => {
    it('should login successfully', async () => {
        const ws = new WebSocket(config.loginServer);
        
        // 发送登录请求
        const loginReq = {
            cmd: 'login',
            params: {
                account: config.account,
                password: config.password
            }
        };
        
        ws.send(JSON.stringify(loginReq));
        
        // 等待响应
        const response = await new Promise(resolve => {
            ws.once('message', data => {
                resolve(JSON.parse(data));
            });
        });
        
        assert.equal(response.result.code, 0);
        assert(response.result.token);
    });
});
```

### 2. 压力测试
```javascript
// test/stress_test.js
const WebSocket = require('ws');
const config = require('./config/config');

async function runStressTest() {
    const connections = 1000;
    const clients = [];
    
    for (let i = 0; i < connections; i++) {
        const ws = new WebSocket(config.loginServer);
        clients.push(ws);
        
        // 模拟用户登录
        ws.on('open', () => {
            ws.send(JSON.stringify({
                cmd: 'login',
                params: {
                    account: `test${i}`,
                    password: '123456'
                }
            }));
        });
    }
}
```

## 运维工具

### 1. 服务管理脚本
```bash
#!/bin/bash
# scripts/manage.sh

case "$1" in
    start)
        ./skynet etc/config/db_proxy.lua
        sleep 2
        ./skynet etc/config/login.lua
        sleep 1
        ./skynet etc/config/game1.lua
        ./skynet etc/config/gate1.lua
        ;;
    stop)
        killall skynet
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
esac
```

### 2. 监控脚本
```lua
-- scripts/monitor.lua
local function check_service_status()
    local services = {
        {name = "login", port = 8021},
        {name = "game1", port = 5001},
        {name = "gate1", port = 8031},
        {name = "db_proxy", port = 4003}
    }
    
    for _, service in ipairs(services) do
        -- 检查端口是否开放
        local ok = socket.connect("127.0.0.1", service.port)
        if not ok then
            logger.error("%s service may be down!", service.name)
            -- 发送告警
            alert_service_down(service.name)
        end
    end
end
```

## 协议列表

### 1. 登录相关
```
C2L_LOGIN_REQUEST(1)        # 登录请求
L2C_LOGIN_RESPONSE(2)       # 登录响应
```

### 2. 心跳相关
```
C2G_HEARTBEAT(5)           # 心跳请求
G2C_HEARTBEAT(6)           # 心跳响应
```

### 3. 用户信息
```
C2G_USER_INFO_REQUEST(7)   # 获取用户信息请求
G2C_USER_INFO_RESPONSE(8)  # 获取用户信息响应
```

### 4. 错误码
```
ERROR_CODE_SUCCESS = 0              # 成功
ERROR_CODE_SYSTEM_ERROR = 1         # 系统错误
ERROR_CODE_INVALID_PARAMS = 2       # 无效参数
ERROR_CODE_INVALID_ACCOUNT = 3      # 无效账号
ERROR_CODE_INVALID_PASSWORD = 4     # 密码错误
ERROR_CODE_TOKEN_INVALID = 7        # 无效的令牌
ERROR_CODE_TOKEN_EXPIRED = 8        # 令牌已过期
ERROR_CODE_SERVER_BUSY = 9          # 服务器繁忙
ERROR_CODE_VERSION_NOT_MATCH = 10   # 版本不匹配
ERROR_CODE_GATE_NOT_AVAILABLE = 11  # 网关不可用
```

## 错误处理

### 1. 错误响应格式
```json
{
    "cmd": "命令名",
    "result": {
        "code": 错误码,
        "message": "错误描述"
    }
}
```

### 2. 常见错误码
| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| 0 | 成功 | - |
| 1 | 系统错误 | 检查服务器日志 |
| 2 | 参数错误 | 检查请求参数 |
| 3 | 账号或密码错误 | 提示用户重新输入 |
| 4 | Token无效 | 重新登录 |
| 5 | 版本过低 | 提示用户更新客户端 |
| 6 | 网关未就绪 | 稍后重试 |
| 7 | 连接超时 | 检查网络连接 |

## 版本管理

### 1. 版本号格式
- 主版本号.次版本号.修订号
- 例如: 1.0.0

### 2. 版本检查
```lua
-- 比较版本号
local function compare_version(v1, v2)
    local function parse_version(v)
        local major, minor, patch = string.match(v, "(%d+)%.(%d+)%.(%d+)")
        return {
            tonumber(major) or 0,
            tonumber(minor) or 0,
            tonumber(patch) or 0
        }
    end
    
    local v1_parts = parse_version(v1)
    local v2_parts = parse_version(v2)
    
    for i = 1, 3 do
        if v1_parts[i] > v2_parts[i] then
            return 1
        elseif v1_parts[i] < v2_parts[i] then
            return -1
        end
    end
    return 0
end
```

## 部署架构

### 1. 单机部署
```
[Client] --> [Nginx] --> [DB Proxy]
                     --> [Login Server]
                     --> [Game Server]
                     --> [Gate Server]
```

### 2. 集群部署
```
[Client] --> [SLB] --> [DB Proxy 1]
                   --> [Login Server]
                   --> [Game Server 1]
                   --> [Game Server 2]
                   --> [Gate Server 1]
                   --> [Gate Server 2]
```

## 性能指标

### 1. 并发连接
- 单个网关支持5000并发
- 单个游戏服支持2000在线
- 单个登录服支持1000 QPS

### 2. 响应时间
- 登录响应 < 100ms
- 心跳响应 < 10ms
- 游戏指令 < 50ms

### 3. 资源消耗
- CPU: 单核心负载 < 80%
- 内存: 单进程 < 1GB
- 带宽: 单连接 < 5KB/s

## 开发环境搭建

### 1. 依赖安装
```bash
# 安装基础依赖
sudo apt-get install build-essential
sudo apt-get install libreadline-dev
sudo apt-get install mysql-server

# 安装Node.js (用于测试)
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install nodejs
```

### 2. 编译skynet
```bash
git clone https://github.com/cloudwu/skynet.git
cd skynet
make linux
```

### 3. 配置MySQL
```sql
-- 创建数据库
CREATE DATABASE tyconn CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 创建用户并授权
CREATE USER 'tyconn'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON tyconn.* TO 'tyconn'@'localhost';
FLUSH PRIVILEGES;
```

## 代码规范

### 1. 命名规范
```lua
-- 模块名使用小写字母，用下划线分隔
local login_mgr = require "login.login_mgr"

-- 常量使用大写字母
local MAX_CONNECTIONS = 1000

-- 函数名使用小驼峰
local function getUserInfo(account)
end

-- 类名使用大驼峰
local LoginManager = {}
```

### 2. 注释规范
```lua
--- 模块说明
-- @module login_mgr
-- @author your_name
-- @copyright 2024
local M = {}

--- 函数说明
-- @param account string 账号
-- @param password string 密码
-- @return boolean 是否成功
-- @return string 错误信息
function M.verifyAccount(account, password)
end
```

## 日志规范

### 1. 日志格式
```lua
-- 错误日志
logger.error("[%s] Failed to connect database: %s", service_name, err)

-- 警告日志
logger.warn("[%s] Token expired: account=%s", service_name, account)

-- 信息日志
logger.info("[%s] Service started on port %d", service_name, port)

-- 调试日志
logger.debug("[%s] Processing request: cmd=%s", service_name, cmd)
```

### 2. 关键节点日志
- 服务启动和关闭
- 连接建立和断开
- 重要操作的执行
- 错误和异常情况
- 性能关键数据

## 监控报警

### 1. 监控项目
```lua
-- 系统监控
local function check_system()
    local cpu_usage = get_cpu_usage()
    if cpu_usage > 80 then
        alert("CPU usage too high: " .. cpu_usage)
    end
    
    local mem_usage = get_mem_usage()
    if mem_usage > 90 then
        alert("Memory usage too high: " .. mem_usage)
    end
end
```

### 2. 报警方式
- 日志记录
- 邮件通知
- 短信告警
- 微信推送

## 压测方案

### 1. 登录压测
```javascript
const cluster = require('cluster');
const numCPUs = require('os').cpus().length;

if (cluster.isMaster) {
    // 启动多个工作进程
    for (let i = 0; i < numCPUs; i++) {
        cluster.fork();
    }
} else {
    // 工作进程运行压测
    runStressTest({
        connections: 1000,
        duration: 300,  // 压测时长(秒)
        rampUp: 60     // 预热时间(秒)
    });
}
```

### 2. 性能分析
```lua
-- 记录执行时间
local function time_cost(name, func, ...)
    local start = skynet.now()
    local ok, result = xpcall(func, debug.traceback, ...)
    local cost = skynet.now() - start
    
    if cost > 100 then  -- 超过1秒
        logger.warn("[%s] Time cost too long: %dms", name, cost/100)
    end
    
    if not ok then
        logger.error("[%s] Failed: %s", name, result)
        return false, result
    end
    return result
end
```

## 服务器架构详解

### 1. 服务器分层
```
+----------------+
|    客户端层    |
+----------------+
         ↓
+----------------+
|   接入层(网关)  |
+----------------+
         ↓
+----------------+
|   逻辑层(游戏)  |
+----------------+
         ↓
+----------------+
|   数据层(DB)   |
+----------------+
```

### 2. 进程模型
```
[主进程]
    ├── [登录服务]
    │     ├── WebSocket服务器
    │     ├── 登录管理器
    │     └── 网关管理器
    │
    ├── [网关服务]
    │     ├── 连接管理器
    │     └── 消息转发器
    │
    ├── [游戏服务]
    │     ├── 用户管理器
    │     └── 游戏逻辑处理器
    │
    └── [数据库代理]
          ├── 连接池管理器
          ├── 数据模型
          └── 缓存管理器
```

### 3. 消息流转
```
[客户端] → [网关] → [游戏服务]
     ↑          ↓          ↓
     └──────────┴──────────┘
        返回响应消息
```

## 扩展开发

### 1. 添加新服务
```lua
-- service/new_service/server.lua
local skynet = require "skynet"
local logger = require "logger"

local CMD = {}

-- 服务初始化
function CMD.start(config)
    -- 初始化代码
    return true
end

-- 服务入口
skynet.start(function()
    -- 注册消息处理函数
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            logger.error("Unknown command: %s", cmd)
        end
    end)
end)
```

### 2. 添加新协议
```lua
-- service/game/handlers/new_proto.lua
local M = {}

-- 协议处理函数
function M.handle(client, params)
    -- 参数验证
    if not params.required_field then
        return {
            code = 2,
            message = "Missing required field"
        }
    end
    
    -- 业务逻辑
    local result = process_business(params)
    
    -- 返回结果
    return {
        code = 0,
        data = result
    }
end

return M
```

## 性能调优

### 1. 内存优化
```lua
-- 1. 对象池
local object_pool = {
    pool = {},
    max_size = 1000
}

function object_pool.get()
    return table.remove(object_pool.pool) or {}
end

function object_pool.put(obj)
    if #object_pool.pool < object_pool.max_size then
        table.clear(obj)
        table.insert(object_pool.pool, obj)
    end
end

-- 2. 字符串优化
local string_cache = setmetatable({}, {__mode = "kv"})

function get_cached_string(str)
    local cached = string_cache[str]
    if not cached then
        cached = str
        string_cache[str] = cached
    end
    return cached
end
```

### 2. CPU优化
```lua
-- 1. 批量处理
function process_batch(items)
    local batch_size = 100
    local total = #items
    local processed = 0
    
    while processed < total do
        local batch = table.slice(items, processed + 1, processed + batch_size)
        process_items(batch)
        processed = processed + #batch
        
        -- 让出CPU
        if processed % 1000 == 0 then
            skynet.sleep(1)
        end
    end
end

-- 2. 定时器优化
local timer = {}
local timer_pool = {}

function timer.add(interval, func)
    local timer_obj = table.remove(timer_pool) or {}
    timer_obj.interval = interval
    timer_obj.func = func
    timer_obj.next_time = skynet.now() + interval
    return timer_obj
end
```

## 服务器通信详解

### 1. 集群间通信
```
[Login Server] ←→ [Game Server]
       ↑               ↑
       ↓               ↓
[Gate Server]  ←→  [DB Proxy]
```

### 2. 消息路由
```lua
-- 1. 客户端消息
Client → Gate → Game → DB Proxy

-- 2. 广播消息
Game → Gate → Client(s)

-- 3. 集群消息
Login → Game → DB Proxy
```

### 3. 通信协议
```lua
-- 1. 客户端协议 (WebSocket + JSON)
{
    cmd = "命令名",
    params = {
        -- 参数
    }
}

-- 2. 服务器间协议 (Skynet Message)
skynet.send(dest, "lua", "cmd", ...)
skynet.call(dest, "lua", "cmd", ...)
```

## 数据流详解

### 1. 登录流程数据流
```
1. Client → Login: 账号密码
2. Login → DB: 验证账号
3. Login → DB: 生成Token
4. Login → Client: Token + 网关信息
5. Client → Gate: Token验证
6. Gate → Game: 创建用户会话
```

### 2. 游戏数据流
```
1. Client → Gate: 游戏指令
2. Gate → Game: 转发指令
3. Game → DB: 读写数据
4. Game → Gate: 返回结果
5. Gate → Client: 指令响应
```

### 3. 广播数据流
```
1. Game → Gate: 广播消息
2. Gate: 查找目标客户端
3. Gate → Clients: 发送消息
```

## 服务启动流程

### 1. 数据库代理启动
```lua
-- 1. 初始化数据库连接池
pool.init()

-- 2. 启动定时清理
skynet.fork(function()
    while true do
        clean_expired_data()
        skynet.sleep(100)
    end
end)

-- 3. 注册集群服务
cluster.register("db_proxy", skynet.self())
```

### 2. 登录服务器启动
```lua
-- 1. 初始化管理器
login_mgr.init()
gate_mgr.init()

-- 2. 启动WebSocket服务器
ws_server.start()

-- 3. 启动状态检查
start_status_check()
```

### 3. 游戏服务器启动
```lua
-- 1. 初始化用户管理器
user_mgr.init()

-- 2. 启动心跳检查
start_heartbeat_check()

-- 3. 注册集群服务
cluster.register("game", skynet.self())
```

## 关键算法实现

### 1. 负载均衡算法
```lua
function select_gate()
    local min_load = 1.0
    local selected = nil
    
    -- 1. 计算负载分数
    for name, info in pairs(gates) do
        local score = calculate_load_score(info)
        if score < min_load then
            min_load = score
            selected = name
        end
    end
    
    return selected
end

function calculate_load_score(info)
    -- 综合评分:
    -- 1. 连接数权重: 50%
    -- 2. CPU使用率: 30%
    -- 3. 内存使用率: 20%
    return (info.connections / MAX_CONNECTIONS) * 0.5 +
           (info.cpu_usage / 100) * 0.3 +
           (info.mem_usage / 100) * 0.2
end
```

### 2. 心跳超时检测
```lua
function check_heartbeat()
    local now = skynet.now()
    local timeout = heartbeat_timeout * 100
    
    for fd, client in pairs(clients) do
        if now - client.last_heartbeat > timeout then
            -- 1. 记录日志
            logger.warn("Client timeout: fd=%d, account=%s", 
                fd, client.account)
            
            -- 2. 清理会话
            cleanup_session(client)
            
            -- 3. 关闭连接
            close_connection(fd)
        end
    end
end
```

## 计划功能

### 1. 服务器状态管理 (待实现)
- 服务状态监控
- CPU/内存使用率统计
- 状态上报机制

### 2. 服务器容错机制 (待实现)
- 全局错误处理
- 自动恢复机制
- 数据备份

### 3. 性能优化 (待实现)
- 对象池
- 字符串缓存
- 批量处理
- 定时器优化

### 4. 监控报警 (待实现)
- 系统监控
- 邮件/短信/微信通知
- 性能指标收集

## 环境变量配置

### 1. MySQL配置
```bash
export MYSQL_HOST="127.0.0.1"
export MYSQL_USER="tyconn"
export MYSQL_PASSWORD="your_password"
export MYSQL_DATABASE="tyconn"
```

### 2. 服务器配置
```bash
# 日志级别
export LOG_LEVEL=1

# JWT配置
export JWT_SECRET="your_jwt_secret_key"
export JWT_EXPIRE=3600

# 版本配置
export VERSION_MIN="1.0.0"
export VERSION_LATEST="1.0.0"
export VERSION_FORCE_UPDATE="false"
```

## 路径配置说明

### 1. 基础路径 (etc/config/path.lua)
```lua
root = "./"
skynet_root = "./skynet/"

-- C服务路径
cpath = skynet_root.."cservice/?.so"

-- Lua加载器
lualoader = skynet_root.."lualib/loader.lua"

-- Lua服务路径
luaservice = root.."service/?.lua;"..
            root.."service/game/?.lua;"..
            root.."service/gate/?.lua;"..
            root.."service/?/init.lua;"..
            skynet_root.."service/?.lua"

-- Lua模块路径
lua_path = root.."lualib/?.lua;"..
          root.."service/?.lua;"..
          root.."service/game/?.lua;"..
          root.."etc/?.lua;"..
          skynet_root.."lualib/?.lua;"..
          skynet_root.."lualib/?/init.lua"

-- C模块路径
lua_cpath = root.."luaclib/?.so;"..
           skynet_root.."luaclib/?.so"

-- protobuf 路径
proto_path = root.."proto/"
```

### 2. 数据库配置 (etc/config/mysql.lua)
```lua
-- 从环境变量读取数据库配置
local host = os.getenv("MYSQL_HOST") or "127.0.0.1"
local user = os.getenv("MYSQL_USER") or "root"
local password = os.getenv("MYSQL_PASSWORD") or "123456"
local database = os.getenv("MYSQL_DATABASE") or "tyconn"

return {
    -- 数据库连接配置
    connection = {
        host = host,
        port = 3306,
        user = user,
        password = password,
        charset = "utf8mb4",
        max_packet_size = 1024 * 1024
    },
    
    -- 数据库名称
    database = database,
    
    -- 连接池配置
    pool = {
        max_connections = 5,
        idle_timeout = 60  -- 秒
    }
}
```