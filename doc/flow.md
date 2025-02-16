# 流程说明

## 1. 登录流程

```mermaid
sequenceDiagram
    participant C as Client
    participant N as Nginx
    participant L as Login Server
    participant G as Gate Server
    participant GM as Game Server
    
    C->>N: 1. 登录请求
    N->>L: 2. 转发到登录服务器
    L->>L: 3. 验证账号密码
    L->>L: 4. 生成Token
    L->>L: 5. 选择最优网关
    L-->>C: 6. 返回Token和网关地址
    C->>G: 7. 连接网关(Token)
    G->>G: 8. 基础Token验证
    G-->>C: 9. 连接成功
    
    Note over C,GM: 后续业务请求
    C->>G: 10. 业务请求
    G->>GM: 11. 转发到游戏服务器
    GM->>GM: 12. 完整Token验证
    GM-->>C: 13. 业务响应
```

**流程说明:**
1. 客户端发送登录请求到Nginx
2. Nginx根据配置转发到登录服务器
3. 登录服务器验证账号密码
4. 验证成功后生成JWT Token
5. 根据负载均衡策略选择合适的网关
6. 返回Token和网关信息给客户端
7. 客户端使用Token连接网关
8. 网关进行基础Token验证(格式、过期时间)
9. 验证通过后建立WebSocket连接
10. 客户端发送业务请求
11. 网关转发请求到游戏服务器
12. 游戏服务器进行完整Token验证(包括权限、状态等)
13. 返回业务响应

## 2. 心跳机制

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gate Server
    
    C->>G: 1. 心跳请求
    G-->>C: 2. 心跳响应
    
    Note over C,G: 心跳超时
    G->>G: 3. 检测超时
    G->>C: 4. 断开连接
```

**流程说明:**
1. 客户端定期发送心跳请求
2. 网关返回心跳响应
3. 网关检测心跳超时
4. 超时后断开连接

## 3. 获取用户信息流程

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gate Server
    participant GM as Game Server
    participant DB as DB Proxy
    
    C->>G: 1. 获取用户信息请求(token)
    G->>GM: 2. 转发请求
    GM->>DB: 3. 验证Token
    DB-->>GM: 4. Token有效
    GM->>DB: 5. 查询用户信息
    DB-->>GM: 6. 返回用户数据
    GM-->>G: 7. 返回用户信息
    G-->>C: 8. 返回响应
```

**流程说明:**
1. 客户端发送获取用户信息请求
2. 网关转发请求到游戏服务器
3. 游戏服务器通过DB代理验证Token
4. Token验证通过
5. 游戏服务器查询用户数据
6. DB代理返回用户信息
7. 游戏服务器处理并返回数据
8. 网关将响应发送给客户端

## 4. 获取用户卡牌流程

```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gate Server
    participant GM as Game Server
    participant DB as DB Proxy
    
    C->>G: 1. 获取卡牌请求(token)
    G->>GM: 2. 转发请求
    GM->>DB: 3. 验证Token
    DB-->>GM: 4. Token有效
    GM->>DB: 5. 查询用户卡牌
    DB-->>GM: 6. 返回卡牌数据
    GM-->>G: 7. 返回卡牌信息
    G-->>C: 8. 返回响应
```

**流程说明:**
1. 客户端发送获取卡牌请求
2. 网关转发请求到游戏服务器
3. 游戏服务器通过DB代理验证Token
4. Token验证通过
5. 游戏服务器查询用户卡牌数据
6. DB代理返回卡牌信息
7. 游戏服务器处理并返回数据
8. 网关将响应发送给客户端

## 5. 物品系统流程

### 5.1 获取背包流程
```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gate Server
    participant GM as Game Server
    participant DB as DB Proxy
    
    C->>G: 1. 获取背包请求(token)
    G->>GM: 2. 转发请求
    GM->>DB: 3. 验证Token
    DB-->>GM: 4. Token有效
    GM->>DB: 5. 查询用户物品
    DB-->>GM: 6. 返回物品列表
    GM-->>G: 7. 返回背包信息
    G-->>C: 8. 返回响应
```

**流程说明:**
1. 客户端发送获取背包请求
2. 网关转发请求到游戏服务器
3. 游戏服务器通过DB代理验证Token
4. Token验证通过
5. 游戏服务器查询用户物品数据
6. DB代理返回物品列表
7. 游戏服务器处理并返回数据
8. 网关将响应发送给客户端

### 5.2 使用物品流程
```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gate Server
    participant GM as Game Server
    participant DB as DB Proxy
    
    C->>G: 1. 使用物品请求
    G->>GM: 2. 转发请求
    GM->>DB: 3. 验证物品
    DB-->>GM: 4. 物品有效
    GM->>DB: 5. 更新物品数量
    DB-->>GM: 6. 更新成功
    GM->>DB: 7. 记录变化日志
    GM-->>G: 8. 返回使用结果
    G-->>C: 9. 返回响应
```

**流程说明:**
1. 客户端发送使用物品请求
2. 网关转发请求到游戏服务器
3. 游戏服务器验证物品是否可用
4. 物品验证通过
5. 更新物品数量
6. 数据库更新成功
7. 记录物品变化日志
8. 游戏服务器返回使用结果
9. 网关将响应发送给客户端

### 5.3 物品变化通知流程
```mermaid
sequenceDiagram
    participant C as Client
    participant G as Gate Server
    participant GM as Game Server
    participant DB as DB Proxy
    
    Note over GM,DB: 物品发生变化
    GM->>DB: 1. 记录变化日志
    GM->>G: 2. 发送变化通知
    G->>C: 3. 推送变化消息
    C->>G: 4. 确认收到通知
    G->>GM: 5. 更新通知状态
```

**流程说明:**
1. 游戏服务器记录物品变化日志
2. 游戏服务器通知网关
3. 网关推送变化消息给客户端
4. 客户端确认收到通知
5. 网关更新通知状态
