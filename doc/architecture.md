# 架构设计

## 服务器架构

### 1. 分层架构
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

### 2. 服务器组成

#### 登录服务器 (Login Server)
- 处理客户端登录请求
- 验证账号密码
- 生成和管理JWT Token
- 分配负载最低的网关服务器
- 监控网关状态

#### 网关服务器 (Gate Server)
- 维护WebSocket连接
- 心跳检测
- 消息转发
- 连接状态管理
- 负载上报

#### 游戏服务器 (Game Server)
- 验证用户Token
- 管理用户会话
- 处理游戏逻辑
- 同步游戏状态

#### 数据库代理 (DB Proxy)
- 数据库连接池管理
- Token缓存和自动续期
- 事务支持
- 数据模型封装

## 进程模型
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
[Client] --> [SLB] --> [DB Proxy]
                   --> [Login Server]
                   --> [Game Server 1]
                   --> [Game Server 2]
                   --> [Gate Server 1]
                   --> [Gate Server 2]
```

## 关键特性

### 1. 负载均衡
- 网关服务器动态负载均衡
- 游戏服务器分区分服
- 数据库读写分离

### 2. 高可用设计
- 服务器多副本部署
- 自动故障转移
- 会话数据持久化

### 3. 扩展性设计
- 模块化架构
- 插件式开发
- 配置驱动 

## 目录结构
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
