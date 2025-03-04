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

### 3. 服务负载均衡

#### Balancer Service原理
```
                          ┌→ [Node 1] ←→ [Health Check]
[Client] → [Balancer] →   ├→ [Node 2] ←→ [Health Check]
                          └→ [Node 3] ←→ [Health Check]
```

1. 节点管理
- 维护服务节点列表(service_nodes)
- 记录节点健康状态(node_status)
- 支持动态添加/移除节点

2. 健康检查
- 定期检查节点健康状态(check_node_health)
- 支持自定义健康检查接口(如 DB Proxy 的 ping)
- 使用 pcall 安全处理节点调用
- 记录节点状态变化

3. 负载均衡策略
- 轮询方式分配请求(Round Robin)
- 只路由到健康节点
- 自动跳过不健康节点
- 支持节点权重(待实现)

4. 状态同步机制
```
                     ┌→ [Node 1]
[Service] ----→      ├→ [Node 2]  定期广播状态
                     └→ [Node 3]
```

- 服务节点定期向其他节点广播状态
- 使用 balancer_service.broadcast 实现可靠广播
- 支持自定义状态数据格式
- 广播失败自动标记目标节点不健康

示例:
```lua
-- 广播状态
balancer_service.broadcast("login",    -- 目标服务类型
    skynet.getenv("node_name"),       -- 调用方节点名
    "update_status",                  -- 更新命令
    {                                 -- 状态数据
        node_name = "gate1",
        service_type = "gate", 
        timestamp = os.time(),
        ...其他状态数据
    }
)
```

5. 故障处理
- 自动检测节点故障
- 将故障节点标记为不健康
- 故障节点恢复后自动加回
- 无健康节点时重新检查所有节点
- 广播失败不影响服务正常运行
- 支持节点动态扩缩容

6. 调用示例
```lua
-- 获取健康节点
local node = balancer_service.get_node("db_proxy", caller_node)
if node then
    -- 调用节点服务
    local ok, result = pcall(cluster.call, node, "@"..node, "some_method")
end
```

这种设计确保了:
- 服务发现和负载均衡的可靠性
- 节点状态的实时同步
- 系统的高可用性
- 集群的动态伸缩能力
- 良好的可观测性

## 请求流程

### 4. 登录流程
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

### 6. 集群部署
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
