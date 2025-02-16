# 协议说明

## 1. 通信协议

### 1.1 基础消息格式
```protobuf
message BaseRequest {
    Session session = 1;    // 会话信息
    bytes payload = 2;      // 消息内容
}

message BaseResponse {
    Session session = 1;    // 会话信息
    int32 errorCode = 2;    // 错误码
    string errorMsg = 3;    // 错误信息
    bytes payload = 4;      // 消息负载
}

message Session {
    int32 messageId = 1;    // 消息ID
    int32 sequence = 2;     // 序列号
    int64 timestamp = 3;    // 时间戳
    string version = 4;     // 客户端版本
}
```

### 1.2 消息ID定义
```protobuf
enum MessageID {
    NONE = 0;
    C2L_LOGIN_REQUEST = 1;          // 客户端到登录服务器的登录请求
    L2C_LOGIN_RESPONSE = 2;         // 登录服务器到客户端的登录响应
    C2G_HEARTBEAT_REQUEST = 3;      // 客户端到游戏服务器的心跳请求
    G2C_HEARTBEAT_RESPONSE = 4;     // 游戏服务器到客户端的心跳响应
    C2G_USER_INFO_REQUEST = 5;      // 获取用户信息请求
    G2C_USER_INFO_RESPONSE = 6;     // 获取用户信息响应
    C2G_USER_CARD_BAG_REQUEST = 7;  // 获取用户卡包请求
    G2C_USER_CARD_BAG_RESPONSE = 8; // 获取用户卡包响应
}
```

### 1.3 心跳协议
```protobuf
// 心跳请求
message C2GHeartbeatRequest {
    int64 timestamp = 1;    // 时间戳
    string token = 2;       // JWT令牌,用于身份验证
}

// 心跳响应
message G2CHeartbeatResponse {
    int64 timestamp = 1;    // 服务器时间戳
    int32 code = 2;        // 状态码
}
```

### 1.4 卡包协议
```protobuf
// 获取用户卡包请求
message C2GUserCardsRequest {
    string token = 1;       // JWT令牌
}

// 获取用户卡包响应
message G2CUserCardsResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    repeated CardInfo cards = 3;  // 卡牌列表
}
```

## 2. 接口说明

### 2.1 登录接口

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求参数:**
```protobuf
message C2LLoginRequest {
    string account = 1;      // 账号
    string password = 2;     // 密码
    string device_id = 3;    // 设备ID
    string platform = 4;     // 平台标识
    string version = 5;      // 客户端版本
}
```

**响应格式:**
```protobuf
message L2CLoginResponse {
    int32 code = 1;         // 错误码
    string message = 2;     // 错误信息
    string token = 3;       // JWT令牌
    string ws_addr = 4;     // WebSocket地址
    int32 ws_port = 5;     // WebSocket端口
}
```

**错误码说明:**
- 0: 成功
- 3: 无效账号
- 4: 密码错误
- 6: 账号不存在
- 9: 服务器繁忙

### 2.2 心跳接口

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GHeartbeatRequest {
    string token = 1;       // JWT令牌
    int64 timestamp = 2;    // 时间戳
}
```

**响应格式:**
```protobuf
message G2CHeartbeatResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    int64 server_time = 3; // 服务器时间
}
```

**错误码说明:**
- 0: 成功
- 7: 无效的令牌
- 8: 令牌已过期

### 2.3 获取用户信息

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GUserInfoRequest {
    string token = 1;       // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CUserInfoResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    UserInfo user = 3;     // 用户信息
}

message UserInfo {
    int64 user_id = 1;      // 用户ID
    string username = 2;     // 用户名
    int32 level = 3;        // 等级
    int64 exp = 4;          // 经验值
    int32 vip_level = 5;    // VIP等级
    int64 create_time = 6;  // 创建时间
    int64 login_time = 7;   // 最后登录时间
}
```

### 2.4 获取用户卡包

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GUserCardsRequest {
    string token = 1;       // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CUserCardsResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    repeated CardInfo cards = 3;  // 卡牌列表
}

message CardInfo {
    int64 card_id = 1;      // 卡牌ID
    int32 card_type = 2;    // 卡牌类型
    int32 level = 3;        // 等级
    int32 exp = 4;          // 经验值
    int32 quality = 5;      // 品质
    int32 star = 6;         // 星级
    int64 create_time = 7;  // 获得时间
    int32 power = 8;        // 战力
}
```

**错误码说明:**
- 0: 成功
- 7: 无效的令牌
- 8: 令牌已过期

## 3. 服务端口

### 3.1 外部端口
- 登录服务器: 8021 (WebSocket)
- 游戏网关: 8031, 8032 (WebSocket)
- HTTP代理: 8010 (HTTP/WS)
- HTTPS代理: 8011 (HTTPS/WSS)

### 3.2 内部端口
- 数据库代理: 12001
- 登录服务器: 13001  
- 游戏服务器: 14001, 14002
- 网关服务器: 15001, 15002

## 4. 协议规范

### 4.1 命名规则
- 请求消息: C2G/C2L 前缀 + 功能名 + Request
- 响应消息: G2C/L2C 前缀 + 功能名 + Response
- 字段名称: 小写下划线命名

### 4.2 版本控制
- 每个消息都包含版本号
- 向下兼容原则
- 不删除已有字段
- 新增字段使用optional

### 4.3 安全说明
- 所有接口使用JWT进行身份验证
- WebSocket连接支持WSS加密
- 异常连接自动断开
- 分层验证机制

## 5. 错误码定义
```protobuf
enum ErrorCode {
    ERROR_CODE_SUCCESS = 0;              // 成功
    ERROR_CODE_SYSTEM_ERROR = 1;         // 系统错误
    ERROR_CODE_INVALID_PARAM = 2;        // 无效参数
    ERROR_CODE_INVALID_ACCOUNT = 3;      // 无效账号
    ERROR_CODE_WRONG_PASSWORD = 4;       // 密码错误
    ERROR_CODE_ACCOUNT_EXISTS = 5;       // 账号已存在
    ERROR_CODE_ACCOUNT_NOT_EXIST = 6;    // 账号不存在
    ERROR_CODE_TOKEN_INVALID = 7;        // 无效的令牌
    ERROR_CODE_TOKEN_EXPIRED = 8;        // 令牌已过期
    ERROR_CODE_SERVER_BUSY = 9;          // 服务器繁忙
}
```