# 架构设计

## 服务器架构

### 1. 分层架构
```
+----------------+
|    客户端层    |
+----------------+
         ↓
+----------------------------------+
|        接入层(Login Server)       |  ← 处理登录验证,返回网关信息
+----------------------------------+
         ↓
+----------------------------------+
|        网关层(Gate Server)        |  ← 维护WebSocket连接,转发消息
+----------------------------------+
         ↓
+----------------------------------+
|        逻辑层(Game Server)        |  ← 处理游戏逻辑
+----------------------------------+
         ↓
+----------------------------------+
|        数据层(DB Proxy)           |  ← 处理数据库访问
+----------------------------------+
```

### 2. 服务器组成

#### 登录服务器 (Login Server)
- 处理客户端登录请求
- 验证账号密码
- 生成和管理JWT Token
- 分配网关服务器
- 支持多节点部署和负载均衡

#### 网关服务器 (Gate Server)
- 维护WebSocket长连接
- 消息转发到Game Server
- 心跳检测
- 连接状态管理
- 定期向Login Server上报状态

#### 游戏服务器 (Game Server)
- 处理具体游戏逻辑
- 验证用户Token
- 管理用户会话
- 通过DB Proxy访问数据

#### 数据库代理 (DB Proxy)
- 统一的数据库访问接口
- 数据库连接池管理
- 支持多节点部署和负载均衡
- 支持读写分离(待实现)

## 请求流程

### 1. 登录流程
```
[Client] → [Login Server] 
    1. 验证账号密码
    2. 生成JWT Token
    3. 选择并返回网关信息

[Client] → [Gate Server]  
    1. 建立WebSocket连接
    2. 使用Token验证身份
    3. 分配到Game Server

[Gate Server] ←→ [Game Server]
    1. 转发游戏消息
    2. 处理游戏逻辑

[Game Server] → [DB Proxy]
    1. 读写数据库
```

### 2. 集群部署
```
                    ┌→ [Login Server 1]
                    ├→ [Login Server 2]
[Client] → [SLB] →  │
                    ├→ [Gate Server 1] → [Game Server 1] → [DB Proxy 1]
                    └→ [Gate Server 2] → [Game Server 2] → [DB Proxy 2]
```

## 关键特性

### 1. 负载均衡
- Login Server通过service_balancer实现负载均衡
- DB Proxy通过service_balancer实现负载均衡
- Gate Server通过Login Server分配

### 2. 高可用设计
- Login Server和DB Proxy支持多节点部署
- 服务节点故障自动切换
- 服务状态自动同步

### 3. 扩展性设计
- 模块化架构
- 基于skynet的Actor模型
- 支持服务动态扩容
