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
    // 游戏登录请求/响应
    C2G_LOGIN_GAME_REQUEST = 7;   // 客户端到游戏服务器的登录请求
    G2C_LOGIN_GAME_RESPONSE = 8;  // 游戏服务器到客户端的登录响应
    
    // 卡牌系统 (101-200)
    C2G_USER_CARDS_REQUEST = 101;   // 获取用户卡牌请求
    G2C_USER_CARDS_RESPONSE = 102;  // 获取用户卡牌响应
    
    // 物品系统 (201-300)
    C2G_BAG_INFO_REQUEST = 201;     // 获取背包信息请求
    G2C_BAG_INFO_RESPONSE = 202;    // 获取背包信息响应
    C2G_USE_ITEM_REQUEST = 203;     // 使用物品请求
    G2C_USE_ITEM_RESPONSE = 204;    // 使用物品响应
    C2G_EXPAND_BAG_REQUEST = 205;   // 扩展背包请求
    G2C_EXPAND_BAG_RESPONSE = 206;  // 扩展背包响应
    C2G_SORT_BAG_REQUEST = 207;     // 整理背包请求
    G2C_SORT_BAG_RESPONSE = 208;    // 整理背包响应
    C2G_MOVE_ITEM_REQUEST = 209;    // 移动物品请求
    G2C_MOVE_ITEM_RESPONSE = 210;   // 移动物品响应
    C2G_COMPOSE_ITEM_REQUEST = 211; // 物品合成请求
    G2C_COMPOSE_ITEM_RESPONSE = 212;// 物品合成响应
    C2G_DECOMPOSE_ITEM_REQUEST = 213;// 物品分解请求
    G2C_DECOMPOSE_ITEM_RESPONSE = 214;// 物品分解响应
    
    // GM系统 (301-400)
    C2G_GM_COMMAND_REQUEST = 301;   // GM命令请求
    G2C_GM_COMMAND_RESPONSE = 302;  // GM命令响应

    // 装备相关 (401-500)
    C2G_EQUIP_INFO_REQUEST = 401;        // 获取装备信息请求
    G2C_EQUIP_INFO_RESPONSE = 402;       // 获取装备信息响应
    C2G_EQUIP_ITEM_REQUEST = 403;        // 装备物品请求
    G2C_EQUIP_ITEM_RESPONSE = 404;       // 装备物品响应
    C2G_UNEQUIP_ITEM_REQUEST = 405;      // 卸下装备请求
    G2C_UNEQUIP_ITEM_RESPONSE = 406;     // 卸下装备响应
    C2G_EQUIP_LEVEL_INFO_REQUEST = 409;  // 获取装备等级信息请求
    G2C_EQUIP_LEVEL_INFO_RESPONSE = 410; // 获取装备等级信息响应
    C2G_EQUIP_LEVEL_UPGRADE_REQUEST = 411; // 装备等级升级请求
    G2C_EQUIP_LEVEL_UPGRADE_RESPONSE = 412; // 装备等级升级响应

    G2C_EQUIPMENT_EXPIRED_PUSH = 451;  // 装备过期推送
    G2C_EQUIPMENT_LEVEL_UPGRADED_PUSH = 452;  // 装备等级升级完成推送

    // 邮件系统 (501-600)
    C2G_MAIL_LIST_REQUEST = 501;      // 获取邮件列表请求
    G2C_MAIL_LIST_RESPONSE = 502;     // 获取邮件列表响应
    C2G_READ_MAIL_REQUEST = 503;      // 读取邮件请求
    G2C_READ_MAIL_RESPONSE = 504;     // 读取邮件响应
    C2G_CLAIM_MAIL_ITEMS_REQUEST = 505;  // 领取邮件附件请求
    G2C_CLAIM_MAIL_ITEMS_RESPONSE = 506; // 领取邮件附件响应
    C2G_DELETE_MAIL_REQUEST = 507;     // 删除邮件请求
    G2C_DELETE_MAIL_RESPONSE = 508;    // 删除邮件响应
    G2C_NEW_MAIL_PUSH = 551;          // 新邮件推送
    
    // 伙伴系统 (601-700)
    C2G_PARTNER_LIST_REQUEST = 601;      // 获取伙伴列表请求
    G2C_PARTNER_LIST_RESPONSE = 602;     // 获取伙伴列表响应
    C2G_PARTNER_LEVEL_UP_REQUEST = 603;  // 伙伴升级请求
    G2C_PARTNER_LEVEL_UP_RESPONSE = 604; // 伙伴升级响应
    C2G_PARTNER_STAR_UP_REQUEST = 605;   // 伙伴升星请求
    G2C_PARTNER_STAR_UP_RESPONSE = 606;  // 伙伴升星响应
    C2G_PARTNER_UNLOCK_REQUEST = 607;    // 伙伴解锁请求
    G2C_PARTNER_UNLOCK_RESPONSE = 608;   // 伙伴解锁响应
    G2C_PARTNER_PROPERTY_CHANGED_PUSH = 651; // 伙伴属性变化推送
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
    
    // 伙伴系统 (500-599)
    ERROR_CODE_PARTNER_NOT_FOUND = 500;      // 伙伴不存在
    ERROR_CODE_PARTNER_ALREADY_EXISTS = 501; // 伙伴已存在
    ERROR_CODE_FRAGMENT_NOT_ENOUGH = 502;    // 碎片不足
    ERROR_CODE_LEVEL_NOT_ENOUGH = 503;      // 等级不足
    ERROR_CODE_LEVEL_MAX = 504;            // 已达到最高等级
    ERROR_CODE_STAR_MAX = 505;             // 已达到最高星级
    ERROR_CODE_MATERIAL_NOT_ENOUGH = 506;  // 材料不足
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
| send_mail | type user_id title content [item_id count]... | 发送邮件 | send_mail 1 1001 "标题" "内容" 1001 100 2001 5 |
| send_system_mail | title content [item_id count]... | 发送系统邮件 | send_system_mail "标题" "内容" 1001 100 |

**错误码说明:**
- ERROR_CODE_PERMISSION_DENIED: 无权限
- ERROR_CODE_GM_COMMAND_FAILED: GM指令执行失败
- ERROR_CODE_INVALID_PARAM: 无效参数

### 3.7 邮件系统接口    

#### 3.7.1 获取用户邮件列表
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GGetMailListRequest {
    string token = 1;       // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CGetMailListResponse {
    repeated common.MailInfo mails = 1;  // 邮件列表
}
``` 

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期


#### 3.7.2 领取邮件附件
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf 
message C2GGetMailListRequest {
    string token = 1;       // JWT令牌
    int64 mail_id = 2;      // 邮件ID
}
``` 

**响应格式:**
```protobuf
message G2CGetMailListResponse {
    repeated common.MailInfo mails = 1;  // 邮件列表
}
``` 

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_MAIL_NOT_FOUND: 邮件不存在

#### 3.7.3 删除邮件
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf 
message C2GDeleteMailRequest {
    string token = 1;       // JWT令牌
    int64 mail_id = 2;      // 邮件ID
}
``` 

**响应格式:**
```protobuf
message G2CDeleteMailResponse {
    bool success = 1;       // 是否成功
}
``` 

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_MAIL_NOT_FOUND: 邮件不存在

#### 3.7.4 读取邮件
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf 
message C2GReadMailRequest {
    string token = 1;       // JWT令牌
    int64 mail_id = 2;      // 邮件ID
}
``` 

**响应格式:**
```protobuf
message G2CReadMailResponse {
    bool success = 1;       // 是否成功
}
``` 

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_MAIL_NOT_FOUND: 邮件不存在

### 3.8 登录游戏接口

**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GLoginGameRequest {
    string token = 1;       // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CLoginGameResponse {
    common.UserInfo user = 1;           // 用户信息
    bool is_new_user = 2;               // 是否为新用户
    repeated common.BagInfo bags = 3;    // 背包信息列表
    repeated common.ResourceInfo resources = 4; // 资源信息列表
    int64 server_time = 5;              // 服务器时间(毫秒)
}

// 用户信息
message UserInfo {
    int64 user_id = 1;         // 用户ID
    string username = 2;       // 用户名
    int32 level = 3;           // 等级
    int64 exp = 4;          // 经验值
    int32 vip_level = 5;      // VIP等级
}

// 资源信息
message ResourceInfo {
    int32 type = 1;            // 资源类型，参见ResourceType枚举
    int32 amount = 2;          // 资源数量
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_SYSTEM_ERROR: 系统错误

**特别说明:**
1. `login_time` 字段会在每次用户登录时自动更新
2. `resources` 字段返回用户拥有的所有资源类型和数量
3. `is_new_user` 字段表示是否为首次登录的新用户
4. 当为新用户时，系统会自动初始化用户数据（卡牌、背包等）

### 3.9 伙伴系统接口

#### 3.9.1 获取伙伴列表
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GPartnerListRequest {
    string token = 1;       // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CPartnerListResponse {
    repeated PartnerInfo partners = 1;  // 伙伴列表
}

message PartnerInfo {
    PartnerBaseInfo base_info = 1;   // 伙伴基本信息
    int32 state = 2;                 // 伙伴状态，参见PartnerState枚举
    int32 fragment_count = 3;        // 拥有的碎片数量
    int32 fragment_need = 4;         // 升级所需碎片
    int32 fragment_item_id = 5;      // 碎片物品ID
    bool can_level_up = 6;           // 是否可以升级
    bool can_star_up = 7;            // 是否可以升星
    repeated ItemInfo level_up_cost = 8;   // 升级消耗
    repeated ItemInfo star_up_cost = 9;    // 升星消耗
    int32 power = 10;                // 伙伴战力
}

message PartnerBaseInfo {
    int64 partner_id = 1;            // 伙伴ID
    int32 unit_id = 2;               // 单位ID
    int32 level = 3;                 // 等级
    int32 exp = 4;                   // 经验值
    int32 quality = 5;               // 品质，参见Quality枚举
    int32 star = 6;                  // 星级
    int64 create_time = 7;           // 创建时间
    int32 race = 8;                  // 种族
    int32 forte = 9;                 // 职业
    repeated PropertyInfo properties = 10; // 属性列表
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期

#### 3.9.2 伙伴升级
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GPartnerLevelUpRequest {
    string token = 1;       // JWT令牌
    int64 partner_id = 2;   // 伙伴ID
}
```

**响应格式:**
```protobuf
message G2CPartnerLevelUpResponse {
    PartnerInfo partner = 1;  // 更新后的伙伴信息
    repeated PropertyInfo property_changes = 2;  // 变化属性
    repeated BagInfo bags = 3;  // 变化的物品列表
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_PARTNER_NOT_FOUND: 伙伴不存在
- ERROR_CODE_LEVEL_MAX: 已达到最高等级
- ERROR_CODE_MATERIAL_NOT_ENOUGH: 材料不足

#### 3.9.3 伙伴升星
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GPartnerStarUpRequest {
    string token = 1;       // JWT令牌
    int64 partner_id = 2;   // 伙伴ID
}
```

**响应格式:**
```protobuf
message G2CPartnerStarUpResponse {
    PartnerInfo partner = 1;  // 更新后的伙伴信息
    repeated PropertyInfo property_changes = 2;  // 变化属性
    repeated BagInfo bags = 3;  // 变化的物品列表
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_PARTNER_NOT_FOUND: 伙伴不存在
- ERROR_CODE_STAR_MAX: 已达到最高星级
- ERROR_CODE_MATERIAL_NOT_ENOUGH: 材料不足

#### 3.9.4 伙伴解锁
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GPartnerUnlockRequest {
    string token = 1;       // JWT令牌
    int32 unit_id = 2;      // 单位ID
}
```

**响应格式:**
```protobuf
message G2CPartnerUnlockResponse {
    PartnerInfo partner = 1;  // 新解锁的伙伴信息
    repeated BagInfo bags = 2;  // 变化的物品列表
    repeated PropertyInfo property_changes = 3;  // 伙伴初始属性
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_PARTNER_ALREADY_EXISTS: 伙伴已存在
- ERROR_CODE_FRAGMENT_NOT_ENOUGH: 碎片不足

#### 3.9.5 伙伴属性变化推送
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**推送格式:**
```protobuf
message G2CPartnerPropertyChangedPush {
    int64 partner_id = 1;            // 伙伴ID
    repeated PropertyInfo property_changes = 2;  // 变化属性
    string reason = 3;               // 变化原因
}

message PropertyInfo {
    int32 prop_id = 1;   // 属性ID，参见PropType枚举
    int32 value = 2;     // 属性值
}
```

### 3.10 大富翁游戏接口

#### 3.10.1 获取地图信息
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GMapInfoRequest {
    string token = 1;      // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CMapInfoResponse {
    int32 chapter_id = 1;                    // 章节ID
    int32 current_position = 2;              // 当前位置（对应格子ID）
    int32 direction = 3;                     // 移动朝向(1:正向, -1:反向)
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期

#### 3.10.2 掷骰子
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GRollDiceRequest {
    string token = 1;      // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CRollDiceResponse {
    int32 dice_value = 1;                    // 骰子点数
    int32 from_position = 2;                 // 起始位置
    int32 to_position = 3;                   // 目标位置
    message EventInfo {
        int32 event_id = 1;                  // 事件ID
        int32 cell_id = 2;                   // 事件所在格子ID
    }
    repeated EventInfo event_ids = 4;        // 触发的事件列表
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_SYSTEM_ERROR: 系统错误

#### 3.10.3 处理格子事件
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GHandleCellEventRequest {
    string token = 1;           // JWT令牌
    int32 event_id = 2;         // 当前处理的事件ID
    int32 cell_id = 3;          // 事件所在格子ID
}
```

**响应格式:**
```protobuf
message G2CHandleCellEventResponse {
    int32 event_id = 1;                      // 当前处理的事件ID
    bool success = 2;                        // 是否成功处理
    repeated common.BagInfo bags = 3;        // 背包变化信息
    int32 next_event_id = 4;                 // 下一个需要处理的事件ID (0表示所有事件已处理完)
    repeated int32 remaining_events = 5;     // 剩余未处理的事件列表
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_SYSTEM_ERROR: 系统错误
- ERROR_CODE_INVALID_PARAM: 无效参数

#### 3.10.4 领取通关奖励
**连接类型:** `WebSocket`
**请求路径:** `/ws`

**请求格式:**
```protobuf
message C2GClaimRewardRequest {
    string token = 1;      // JWT令牌
}
```

**响应格式:**
```protobuf
message G2CClaimRewardResponse {
    bool success = 1;                      // 是否成功
    repeated common.BagInfo bags = 2;      // 背包变化信息
    int32 next_chapter = 3;                // 下一章节ID
}
```

**错误码说明:**
- ERROR_CODE_SUCCESS: 成功
- ERROR_CODE_TOKEN_INVALID: 无效的令牌
- ERROR_CODE_TOKEN_EXPIRED: 令牌已过期
- ERROR_CODE_SYSTEM_ERROR: 系统错误
- ERROR_CODE_INVALID_PARAM: 无效参数

**特别说明:**
1. 领取奖励需要满足章节的胜利条件
2. 每个章节的奖励只能领取一次
3. 领取奖励后会自动进入下一章节
4. 如果已经是最后一个章节，next_chapter 将为 0

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

// 资源类型
enum ResourceType {
    RESOURCE_TYPE_NONE = 0;   // 无效类型
    RESOURCE_TYPE_GOLD = 1;   // 金币
    RESOURCE_TYPE_EXP = 2;    // 经验
}

// 伙伴相关枚举定义
enum PartnerState {
    PARTNER_STATE_NONE = 0;      // 无效状态
    PARTNER_STATE_UNLOCKED = 1;  // 已解锁
    PARTNER_STATE_UNLOCKABLE = 2; // 可解锁
    PARTNER_STATE_LOCKED = 3;    // 未解锁
}

enum PartnerAttributeType {
    ATTRIBUTE_TYPE_NONE = 0;     // 无效类型
    ATTRIBUTE_TYPE_HP = 1;       // 生命值
    ATTRIBUTE_TYPE_ATTACK = 2;   // 攻击力
    ATTRIBUTE_TYPE_DEFENSE = 3;  // 防御力
    ATTRIBUTE_TYPE_CRIT = 4;     // 暴击率
    ATTRIBUTE_TYPE_SPEED = 5;    // 速度
}