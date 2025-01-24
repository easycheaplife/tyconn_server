# API文档

## 登录服务

### 1. 登录接口

**请求**
```javascript
WebSocket: ws://login_server:8021

{
    "session": {
        "messageId": 1,  // C2L_LOGIN_REQUEST
        "sequence": 1,
        "timestamp": 1648888888,
        "version": "1.0.0"
    },
    "payload": {
        "account": "test",
        "password": "123456",
        "device_id": "test_device",
        "platform": "ios",
        "version": "1.0.0"
    }
}
```

**响应**
```javascript
{
    "session": {
        "messageId": 2,  // L2C_LOGIN_RESPONSE
        "sequence": 1,
        "timestamp": 1648888889
    },
    "errorCode": 0,
    "errorMsg": "success",
    "payload": {
        "token": "eyJhbGciOiJIUzI1NiIs...",
        "ws_addr": "127.0.0.1",
        "ws_port": 8031
    }
}
```

## 游戏服务

### 1. 心跳接口

**请求**
```javascript
WebSocket: ws://game_server:8031

{
    "session": {
        "messageId": 5,  // C2G_HEARTBEAT
        "sequence": 1,
        "timestamp": 1648888888
    },
    "payload": {
        "timestamp": 1648888888,
        "clientId": 12345
    }
}
```

**响应**
```javascript
{
    "session": {
        "messageId": 6,  // G2C_HEARTBEAT
        "sequence": 1,
        "timestamp": 1648888889
    },
    "errorCode": 0,
    "errorMsg": "success",
    "payload": {
        "timestamp": 1648888889,
        "code": 0
    }
}
```

### 2. 获取用户信息

**请求**
```javascript
WebSocket: ws://game_server:8031

{
    "session": {
        "messageId": 7,  // C2G_USER_INFO_REQUEST
        "sequence": 1,
        "timestamp": 1648888888
    },
    "payload": {
        "token": "eyJhbGciOiJIUzI1NiIs...",
        "name": "player1",     // 可选,创建角色时使用
        "gender": 1,           // 可选,创建角色时使用
        "job": 1               // 可选,创建角色时使用
    }
}
```

**响应**
```javascript
{
    "session": {
        "messageId": 8,  // G2C_USER_INFO_RESPONSE
        "sequence": 1,
        "timestamp": 1648888889
    },
    "errorCode": 0,
    "errorMsg": "success",
    "payload": {
        "user": {
            "user_id": 10001,
            "name": "player1",
            "level": 1,
            "gender": 1,
            "job": 1,
            "exp": 0,
            "create_time": 1648888889,
            "login_time": 1648888889
        },
        "is_new": true
    }
}
```

## 错误码说明

| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| 0 | 成功 | - |
| 1 | 系统错误 | 重试或联系客服 |
| 2 | 无效参数 | 检查参数格式 |
| 3 | 无效账号 | 检查账号格式 |
| 4 | 密码错误 | 检查密码是否正确 |
| 5 | 账号已存在 | 更换账号 |
| 6 | 账号不存在 | 检查账号或注册 |
| 7 | 无效的令牌 | 重新登录 |
| 8 | 令牌已过期 | 重新登录 |
| 9 | 服务器繁忙 | 稍后重试 |
| 10 | 版本不匹配 | 更新客户端 |
| 11 | 网关不可用 | 重新登录 |

## WebSocket状态码

| 状态码 | 说明 | 处理建议 |
|--------|------|----------|
| 1000 | 正常关闭 | 重新连接 |
| 1001 | 服务端关闭 | 等待服务恢复 |
| 1002 | 协议错误 | 检查协议格式 |
| 1003 | 数据类型错误 | 检查数据格式 |
| 1006 | 异常关闭 | 重新连接 |
| 1007 | 数据格式错误 | 检查数据格式 |
| 1008 | 策略违规 | 检查请求是否合规 |
| 1009 | 消息过大 | 减小消息大小 |
| 1010 | 客户端关闭 | 检查客户端状态 |
| 1011 | 服务器错误 | 等待服务恢复 |

## 服务器功能

### 1. 登录服务器
- 验证账号密码
- 生成Token
- 选择网关

### 2. 网关服务器
- 维护客户端连接
- 消息转发
- 心跳检测

### 3. 游戏服务器
- 处理游戏逻辑
- 管理用户数据
- 同步游戏状态

### 4. 数据库代理
- 数据库操作封装
- 连接池管理
- 数据缓存 