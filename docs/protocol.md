# 协议说明

## 1. 基础协议

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
    // 账号系统 (1-99)
    C2L_LOGIN_REQUEST = 1;          // 客户端到登录服务器的登录请求
    L2C_LOGIN_RESPONSE = 2;         // 登录服务器到客户端的登录响应
    C2G_HEARTBEAT_REQUEST = 3;      // 客户端到游戏服务器的心跳请求
    G2C_HEARTBEAT_RESPONSE = 4;     // 游戏服务器到客户端的心跳响应
    C2G_USER_INFO_REQUEST = 5;      // 获取用户信息请求
    G2C_USER_INFO_RESPONSE = 6;     // 获取用户信息响应

    // 卡牌系统 (100-199)
    C2G_USER_CARDS_REQUEST = 100;   // 获取用户卡牌请求
    G2C_USER_CARDS_RESPONSE = 101;  // 获取用户卡牌响应

    // 物品系统 (200-299)
    C2G_BAG_INFO_REQUEST = 200;     // 获取背包信息请求
    G2C_BAG_INFO_RESPONSE = 201;    // 获取背包信息响应
    C2G_USE_ITEM_REQUEST = 202;     // 使用物品请求
    G2C_USE_ITEM_RESPONSE = 203;    // 使用物品响应
    C2G_EXPAND_BAG_REQUEST = 204;   // 扩展背包请求
    G2C_EXPAND_BAG_RESPONSE = 205;  // 扩展背包响应
    C2G_SORT_BAG_REQUEST = 206;     // 整理背包请求
    G2C_SORT_BAG_RESPONSE = 207;    // 整理背包响应
    C2G_MOVE_ITEM_REQUEST = 208;    // 移动物品请求
    G2C_MOVE_ITEM_RESPONSE = 209;   // 移动物品响应
    C2G_COMPOSE_ITEM_REQUEST = 210; // 物品合成请求
    G2C_COMPOSE_ITEM_RESPONSE = 211;// 物品合成响应
    C2G_DECOMPOSE_ITEM_REQUEST = 212;// 物品分解请求
    C2G_DECOMPOSE_ITEM_RESPONSE = 213;// 物品分解响应

    // GM系统 (300-399)
    C2G_GM_COMMAND_REQUEST = 300;   // GM命令请求
    G2C_GM_COMMAND_RESPONSE = 301;  // GM命令响应
}
```
### 1.3 错误码
```protobuf
enum ErrorCode {
    // 系统错误 (0-99)
    ERROR_CODE_SUCCESS = 0;              // 成功
    ERROR_CODE_SYSTEM_ERROR = 1;         // 系统错误
    ERROR_CODE_INVALID_PARAM = 2;        // 无效参数
    ERROR_CODE_SERVER_BUSY = 9;          // 服务器繁忙
    ERROR_CODE_VERSION_MISMATCH = 10;    // 版本不匹配
    ERROR_CODE_DB_ERROR = 12;            // 数据库错误

    // 账号相关 (100-199)
    ERROR_CODE_INVALID_ACCOUNT = 100;      // 无效账号
    ERROR_CODE_WRONG_PASSWORD = 101;       // 密码错误
    ERROR_CODE_ACCOUNT_EXISTS = 102;       // 账号已存在
    ERROR_CODE_ACCOUNT_NOT_EXIST = 103;    // 账号不存在
    ERROR_CODE_TOKEN_INVALID = 104;        // 无效的令牌
    ERROR_CODE_TOKEN_EXPIRED = 105;        // 令牌已过期
    ERROR_CODE_GATE_NOT_AVAILABLE = 106;   // 网关不可用

    // 物品系统 (200-299)
    ERROR_CODE_ITEM_NOT_FOUND = 200;      // 物品不存在
    ERROR_CODE_ITEM_NOT_ENOUGH = 201;     // 物品数量不足
    ERROR_CODE_BAG_NOT_EXIST = 202;       // 背包不存在
    ERROR_CODE_BAG_MAX_SIZE_LIMIT = 203;  // 超过背包最大容量限制
    ERROR_CODE_BAG_EXPAND_FAILED = 204;   // 扩展背包失败
    ERROR_CODE_INVALID_BAG_TYPE = 205;    // 无效的背包类型
    ERROR_CODE_INSUFFICIENT_SPACE = 206;   // 背包空间不足
    ERROR_CODE_INVALID_SLOT = 207;        // 无效的格子
    ERROR_CODE_SLOT_LOCKED = 208;         // 格子被锁定

    // GM系统 (300-399)
    ERROR_CODE_GM_COMMAND_FAILED = 300;   // GM指令执行失败
    ERROR_CODE_PERMISSION_DENIED = 301;   // 权限不足

    // 卡牌系统 (400-499)
    ERROR_CODE_CARD_NOT_FOUND = 400;      // 卡牌不存在
    ERROR_CODE_CARD_ALREADY_EXISTS = 401; // 卡牌已存在
    ERROR_CODE_CARD_NOT_ENOUGH = 402;     // 卡牌数量不足
}
```

## 2. 功能模块

### 2.1 账号系统
#### 2.1.1 基础定义
```protobuf
// 账号状态
enum AccountStatus {
    ACCOUNT_STATUS_NONE = 0;    // 无效状态
    ACCOUNT_STATUS_NORMAL = 1;  // 正常
    ACCOUNT_STATUS_BANNED = 2;  // 封禁
    ACCOUNT_STATUS_DELETED = 3; // 删除
}

// 登录类型
enum LoginType {
    LOGIN_TYPE_NONE = 0;     // 无效类型
    LOGIN_TYPE_ACCOUNT = 1;  // 账号密码
    LOGIN_TYPE_GUEST = 2;    // 游客
    LOGIN_TYPE_WECHAT = 3;   // 微信
    LOGIN_TYPE_GOOGLE = 4;   // Google
}
```

#### 2.1.2 协议消息
```protobuf
// 登录协议
message C2LLoginRequest {
    string account = 1;      // 账号
    string password = 2;     // 密码
    string device_id = 3;    // 设备ID
    string platform = 4;     // 平台标识
    string version = 5;      // 客户端版本
    LoginType login_type = 6;// 登录类型
}

message L2CLoginResponse {
    string token = 1;       // JWT令牌
    string ws_addr = 2;     // WebSocket地址
    int32 ws_port = 3;      // WebSocket端口
    AccountStatus status = 4;// 账号状态
}

// 心跳协议
message C2GHeartbeatRequest {
    int64 timestamp = 1;    // 时间戳
    string token = 2;       // JWT令牌
}

message G2CHeartbeatResponse {
    int64 timestamp = 1;    // 服务器时间戳
    int32 online_time = 2;  // 在线时长(秒)
}

// 用户信息协议
message C2GUserInfoRequest {
    string token = 1;       // JWT令牌
}

message G2CUserInfoResponse {
    UserInfo user = 1;      // 用户信息
}
```

### 2.2 卡牌系统
#### 2.2.1 基础定义
```protobuf
// 卡牌品质
enum CardQuality {
    CARD_QUALITY_NONE = 0;   // 无品质
    CARD_QUALITY_WHITE = 1;  // 白色
    CARD_QUALITY_GREEN = 2;  // 绿色
    CARD_QUALITY_BLUE = 3;   // 蓝色
    CARD_QUALITY_PURPLE = 4; // 紫色
    CARD_QUALITY_ORANGE = 5; // 橙色
}

// 卡牌类型
enum CardType {
    CARD_TYPE_NONE = 0;      // 无类型
}
```

#### 2.2.2 协议消息
```protobuf
// 获取卡牌列表
message C2GUserCardsRequest {
    string token = 1;       // JWT令牌
    CardType card_type = 2; // 卡牌类型(可选)
    int32 quality = 3;      // 品质(可选)
}

message G2CUserCardsResponse {
    repeated CardInfo cards = 1;  // 卡牌列表
}
```

### 2.3 物品系统
#### 2.3.1 基础定义
```protobuf
// 物品相关枚举定义
enum ItemEffectType {
    EFFECT_TYPE_NONE = 0;    // 无效果
    EFFECT_TYPE_EXP = 1;     // 经验
    EFFECT_TYPE_GOLD = 2;    // 金币
}

enum BagType {
    BAG_TYPE_NONE = 0;
    BAG_TYPE_MAIN = 1;      // 主背包
    BAG_TYPE_STORAGE = 2;   // 仓库
    BAG_TYPE_EQUIP = 3;     // 装备栏
}

enum ItemChangeType {
    CHANGE_TYPE_NONE = 0;    // 无变化
    CHANGE_TYPE_ADD = 1;     // 增加
    CHANGE_TYPE_REDUCE = 2;  // 减少
    CHANGE_TYPE_USE = 3;     // 使用
}

enum ItemChangeSource {
    SOURCE_NONE = 0;
    SOURCE_SYSTEM = 1;
    SOURCE_USER = 2;
}

// 物品基础信息
message ItemInfo {
    int64 id = 1;          // 物品实例ID
    int32 item_id = 2;     // 物品类型ID
    int32 count = 3;       // 数量
    int32 slot_index = 4;  // 格子索引
    int32 bag_type = 5;    // 所属背包类型
    int64 create_time = 6; // 获得时间
    int64 update_time = 7; // 更新时间
}

// 背包信息
message BagInfo {
    int32 bag_type = 1;    // 背包类型
    int32 size = 2;        // 背包大小
    repeated ItemInfo items = 3;  // 物品列表
}
```

#### 2.3.2 协议消息
```protobuf
// 获取背包信息
message C2GBagInfoRequest {
    string token = 1;       // JWT令牌
}

message G2CBagInfoResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    repeated common.BagInfo bags = 3;  // 背包信息列表
}

// 扩展背包
message C2GExpandBagRequest {
    string token = 1;       // JWT令牌
    BagType bag_type = 2;   // 背包类型
    int32 add_size = 3;     // 扩展格子数
}

message G2CExpandBagResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    BagInfo bag = 3;      // 背包信息
}

// 使用物品
message C2GUseItemRequest {
    string token = 1;      // JWT令牌
    int32 item_id = 2;     // 物品ID
    int32 count = 3;       // 使用数量
}

message G2CUseItemResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    repeated ItemInfo items = 3;  // 变化的物品列表
}

// 整理背包
message C2GSortBagRequest {
    string token = 1;       // JWT令牌
    BagType bag_type = 2;   // 背包类型
    int32 sort_rule = 3;    // 整理规则(1:类型 2:品质 3:等级)
}

message G2CSortBagResponse {    
    repeated common.ItemInfo items = 1;     // 整理后的物品列表
}

// 移动物品
message C2GMoveItemRequest {
    string token = 1;
    int32 src_bag_type = 2;     // 源背包类型
    int32 src_slot = 3;         // 源格子位置
    int32 dst_bag_type = 4;     // 目标背包类型
    int32 dst_slot = 5;         // 目标格子位置
    int32 count = 6;   // 可选的移动数量
}

message G2CMoveItemResponse {
    repeated common.ItemInfo changed_items = 1;  // 所有变化的物品
}

// 物品合成
message C2GComposeItemRequest {
    string token = 1;
    int32 target_id = 2;    // 目标物品ID
    repeated int32 material_slots = 3;  // 材料所在格子
}

message G2CComposeItemResponse {
    bool success = 1;       // 是否成功
    common.ItemInfo new_item = 2;  // 合成的新物品
    repeated common.ItemInfo remain_items = 3;  // 剩余材料
}

// 物品分解
message C2GDecomposeItemRequest {
    string token = 1;
    repeated int32 item_slots = 2;   // 要分解的物品格子
}   

message G2CDecomposeItemResponse {
    repeated common.ItemInfo result_items = 1;  // 分解获得的物品
}
```

### 2.4 GM系统
- GM指令协议
- 权限控制

## 3. 接口说明

### 3.1 登录接口

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
    string token = 1;       // JWT令牌
    string ws_addr = 2;     // WebSocket地址
    int32 ws_port = 3;     // WebSocket端口
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_INVALID_ACCOUNT: 无效账号
- ERROR_CODE_WRONG_PASSWORD: 密码错误
- ERROR_CODE_ACCOUNT_NOT_EXIST: 账号不存在
- ERROR_CODE_SERVER_BUSY: 服务器繁忙

### 3.2 心跳接口

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GHeartbeatRequest {
    int64 timestamp = 1;    // 时间戳
    string token = 2;       // JWT令牌,用于身份验证
}
```

**响应格式:**
```protobuf
message G2CHeartbeatResponse {
    int64 timestamp = 1;    // 服务器时间戳
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期

### 3.3 获取用户信息

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

### 3.4 获取用户卡牌列表

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
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_CARD_NOT_FOUND: 卡牌不存在

### 3.5 物品系统接口

#### 3.5.1 获取背包信息

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GBagInfoRequest {
    string token = 1;       // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CBagInfoResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    repeated common.BagInfo bags = 3;  // 背包信息列表
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_ITEM_NOT_FOUND: 物品不存在
- ERROR_CODE_ITEM_NOT_ENOUGH: 物品数量不足
- ERROR_CODE_BAG_NOT_EXIST: 背包不存在
- ERROR_CODE_INSUFFICIENT_SPACE: 背包空间不足

#### 3.5.2 扩展背包

**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GExpandBagRequest {
    string token = 1;       // JWT令牌
    BagType bag_type = 2;   // 背包类型
    int32 add_size = 3;     // 扩展格子数
}
```

**响应格式:**
```protobuf
message G2CExpandBagResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    BagInfo bag = 3;      // 背包信息
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_BAG_NOT_EXIST: 背包不存在
- ERROR_CODE_BAG_MAX_SIZE_LIMIT: 超过背包最大容量限制
- ERROR_CODE_BAG_EXPAND_FAILED: 扩展背包失败
- ERROR_CODE_INVALID_BAG_TYPE: 无效的背包类型

#### 3.5.3 使用物品

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GUseItemRequest {
    string token = 1;      // JWT令牌
    int32 item_id = 2;     // 物品ID
    int32 count = 3;       // 使用数量
}
```

**响应格式:**
```protobuf
message G2CUseItemResponse {
    int32 code = 1;        // 错误码
    string message = 2;    // 错误信息
    repeated ItemInfo items = 3;  // 变化的物品列表
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_ITEM_NOT_FOUND: 物品不存在
- ERROR_CODE_ITEM_NOT_ENOUGH: 物品数量不足
- ERROR_CODE_BAG_NOT_EXIST: 背包不存在
- ERROR_CODE_INVALID_SLOT: 无效的格子
- ERROR_CODE_SLOT_LOCKED: 格子被锁定

#### 3.5.5 整理背包

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GSortBagRequest {
    string token = 1;       // JWT令牌
    BagType bag_type = 2;   // 背包类型
    int32 sort_rule = 3;    // 整理规则(1:类型 2:品质 3:等级)
}
``` 

**响应格式:**
```protobuf
message G2CSortBagResponse {
    repeated common.ItemInfo items = 1;     // 整理后的物品列表
}
``` 

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_BAG_NOT_EXIST: 背包不存在
- ERROR_CODE_INVALID_SORT_RULE: 无效的整理规则


#### 3.5.6 移动物品

**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GMoveItemRequest {
    string token = 1;
    int32 src_bag_type = 2;     // 源背包类型
    int32 src_slot = 3;         // 源格子位置
    int32 dst_bag_type = 4;     // 目标背包类型
    int32 dst_slot = 5;         // 目标格子位置
    int32 count = 6;   // 可选的移动数量
}   
```

**响应格式:**
```protobuf
message G2CMoveItemResponse {
    repeated common.ItemInfo changed_items = 1;  // 所有变化的物品
}   
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期  

#### 3.5.7 物品合成
**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GComposeItemRequest {
    string token = 1;
    int32 target_id = 2;    // 目标物品ID
    repeated int32 material_slots = 3;  // 材料所在格子
}   
```

**响应格式:**
```protobuf 
message G2CComposeItemResponse {
    bool success = 1;       // 是否成功
    common.ItemInfo new_item = 2;  // 合成的新物品
    repeated common.ItemInfo remain_items = 3;  // 剩余材料
}
``` 

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_ITEM_NOT_FOUND: 物品不存在
- ERROR_CODE_ITEM_NOT_ENOUGH: 物品数量不足      

#### 3.5.8 物品分解
**连接类型:** `WebSocket`  
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GDecomposeItemRequest {
    string token = 1;
    repeated int32 item_slots = 2;   // 要分解的物品格子
}
```

**响应格式:**
```protobuf
message G2CDecomposeItemResponse {
    repeated common.ItemInfo result_items = 1;  // 分解获得的物品
}
```

**错误码说明:** 
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_ITEM_NOT_FOUND: 物品不存在
- ERROR_CODE_ITEM_NOT_ENOUGH: 物品数量不足

### 3.6 GM指令接口
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**GM 指令列表:**
| 指令 | 参数 | 说明 | 示例 |
|------|------|------|------|
| add_item | item_id, count | 添加物品 | add_item 1001 100 |
| del_item | item_id, count | 删除物品 | del_item 1001 50 |
| set_level | level | 设置等级 | set_level 99 |
| clear_bag | bag_type | 清空背包 | clear_bag 1 |

**错误码说明:**
- ERROR_CODE_PERMISSION_DENIED: 无权限
- ERROR_CODE_GM_COMMAND_FAILED: GM指令执行失败
- ERROR_CODE_INVALID_PARAM: 无效参数

## 4. 系统配置

### 4.1 服务端口

### 4.1.1 外部端口
- 登录服务器: 8021 (WebSocket)
- 游戏网关: 8031, 8032 (WebSocket)
- HTTP代理: 8010 (HTTP/WS)
- HTTPS代理: 8011 (HTTPS/WSS)

### 4.1.2 内部端口
- 数据库代理: 12001
- 登录服务器: 13001  
- 游戏服务器: 14001, 14002
- 网关服务器: 15001, 15002

### 4.2 协议规范

### 4.2.1 命名规则
- 请求消息: C2G/C2L 前缀 + 功能名 + Request
- 响应消息: G2C/L2C 前缀 + 功能名 + Response
- 通知消息: C2G/G2C 前缀 + 功能名 + Notify
- 字段名称: 小写下划线命名

### 4.2.2 版本控制
- 每个消息都包含版本号
- 向下兼容原则
- 不删除已有字段
- 新增字段使用optional

### 4.3 安全说明
- 所有接口使用JWT进行身份验证
- WebSocket连接支持WSS加密
- 异常连接自动断开
- 分层验证机制

### 4.4 通知机制
- 服务器主动推送变化
- 客户端确认接收
- 支持批量通知
- 保证通知送达