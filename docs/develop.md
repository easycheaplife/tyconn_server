# 开发指南

## 开发环境搭建

### 1. 开发工具
- VSCode
- Git
- MySQL Workbench
- Redis Desktop Manager
- Postman

### 2. VSCode插件
- Lua
- Lua Debug
- Proto3
- REST Client
- GitLens

### 3. 调试配置
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "lua",
            "request": "launch",
            "name": "Debug Game Server",
            "program": "${workspaceFolder}/skynet/skynet",
            "args": ["etc/config/game1.lua"],
            "cwd": "${workspaceFolder}"
        }
    ]
}
```

## 代码规范

### 1. 命名规范
```lua
-- 模块名使用小写
local logger = require "logger"

-- 类名使用大驼峰
local UserManager = {}

-- 函数名使用小驼峰
function UserManager.getUserInfo(userId)
end

-- 常量使用大写下划线
local MAX_USERS = 1000

-- 变量使用小驼峰
local userCount = 0
```

### 2. 注释规范
```lua
--- 模块说明
-- @module UserManager
-- @author yourname
-- @date 2024-01-01
local M = {}

--- 函数说明
-- @param userId number 用户ID
-- @return table 用户信息
-- @return string 错误信息
function M.getUserInfo(userId)
end
```

### 3. 文件组织
```
service/
├── game/
│   ├── handlers/     -- 消息处理器
│   ├── models/       -- 数据模型
│   ├── utils/        -- 工具函数
│   └── server.lua    -- 服务入口
```

## 开发流程

### 1. 新增功能
1. 创建功能分支
```bash
git checkout -b feature/user-info
```

2. 添加协议定义
```protobuf
// proto/command/user.proto
message C2GUserInfoRequest {
    string userId = 1;
}
```

3. 实现处理器
```lua
-- service/game/handlers/user_info.lua
local M = {}

function M.handle(client_id, msg)
    -- 处理逻辑
end

return M
```

4. 注册处理器
```lua
-- service/game/message_mgr.lua
M.register(pb.enum("common.MessageID", "C2G_USER_INFO_REQUEST"), 
    require "game.handlers.user_info_handler")
```

### 2. 修复Bug
1. 创建修复分支
```bash
git checkout -b fix/heartbeat-timeout
```

2. 添加测试用例
```lua
-- test/heartbeat_test.lua
function test_heartbeat_timeout()
    -- 测试代码
end
```

3. 修复问题
```lua
-- service/game/server.lua
local heartbeat_timeout = 180  -- 修改超时时间
```

### 3. 代码提交
```bash
# 添加修改
git add .

# 提交代码
git commit -m "feat: add user info api"

# 推送分支
git push origin feature/user-info
```

## 测试指南

### 1. 单元测试
```lua
-- test/user_test.lua
local function test_create_user()
    local user = UserModel.create({
        name = "test",
        level = 1
    })
    assert(user.name == "test")
    assert(user.level == 1)
end
```

### 2. 接口测试
```javascript
// test/api_test.js
async function testUserInfo() {
    const response = await client.getUserInfo("10001");
    assert(response.code === 0);
    assert(response.data.name === "test");
}
```

### 3. 压力测试
```bash
# 运行压测脚本
./test/benchmark.sh -c 100 -n 1000
```

## 发布流程

### 1. 版本规范
- 主版本号: 不兼容的API修改
- 次版本号: 向下兼容的功能性新增
- 修订号: 向下兼容的问题修正

### 2. 发布步骤
1. 更新版本号
```lua
-- etc/config/version.lua
return {
    version = "1.0.1",
    min_version = "1.0.0"
}
```

2. 生成更新日志
```bash
# 生成changelog
git-changelog -t "v1.0.1"
```

3. 创建发布分支
```bash
git checkout -b release/v1.0.1
```

4. 合并到主分支
```bash
git checkout main
git merge release/v1.0.1
git tag v1.0.1
git push origin main --tags
```

## 模块开发指南

### 1. 物品系统
1. 添加物品
2. 使用物品
3. 物品合成

### 2. 伙伴系统

#### 伙伴系统概述
伙伴系统是游戏中的核心功能，允许玩家收集、升级和使用不同的伙伴角色。系统包括伙伴解锁、升级、升星等功能。

#### 数据结构设计
```lua
-- 伙伴基础数据(units表)
units = {
    unit_id,          -- 单位ID
    name,             -- 名称
    quality,          -- 品质
    fragment_id,      -- 对应碎片ID
    unlock_fragment,  -- 解锁所需碎片数量
    base_hp,          -- 基础生命值
    base_attack,      -- 基础攻击力
    base_defense      -- 基础防御力
}

-- 玩家伙伴数据(partners表)
partners = {
    partner_id,       -- 伙伴ID
    user_id,          -- 用户ID
    unit_id,          -- 单位ID
    level,            -- 等级
    star,             -- 星级
    exp,              -- 经验值
    create_time,      -- 创建时间
    update_time       -- 更新时间
}

-- 玩家伙伴碎片(fragments表)
fragments = {
    id,               -- ID
    user_id,          -- 用户ID
    fragment_id,      -- 碎片ID
    count,            -- 数量
    update_time       -- 更新时间
}
```

#### 开发步骤
1. **添加协议定义**

```proto
// proto/command/partner.proto
syntax = "proto3";
package command;

import "common/common.proto";

message C2GPartnerListRequest {
    string token = 1;
}

message G2CPartnerListResponse {
    repeated common.PartnerInfo partners = 1;
}

message C2GPartnerUpgradeRequest {
    string token = 1;
    int64 partner_id = 2;
}

message G2CPartnerUpgradeResponse {
    bool success = 1;
    common.PartnerInfo partner = 2;
}

// 其他伙伴相关协议...
```

2. **实现伙伴DAO层**

```lua
-- service/game/dao/partner_dao.lua
local M = {}

-- 获取用户伙伴列表
function M.get_user_partners(user_id)
    -- 优先从缓存获取
    local cache_key = string.format("user_partners:%d", user_id)
    local cached = cache.get(cache_key)
    if cached then
        return cached
    end
    
    -- 从数据库获取并缓存
    local sql = "SELECT * FROM partners WHERE user_id = ? ORDER BY partner_id"
    local partners = db.query(sql, {user_id})
    
    cache.set(cache_key, partners, 300)  -- 缓存5分钟
    return partners
end

-- 获取用户碎片
function M.get_user_fragments(user_id)
    -- 实现碎片查询逻辑
end

-- 其他DAO方法...

return M
```

3. **实现伙伴服务**

```lua
-- service/game/services/partner_service.lua
local M = {}
local partner_dao = require "game.dao.partner_dao"

-- 获取伙伴列表
function M.get_partner_list(user_id)
    -- 获取已拥有的伙伴
    local partners = partner_dao.get_user_partners(user_id)
    
    -- 获取所有单位配置
    local all_units = config_mgr.get_units()
    
    -- 获取用户碎片
    local fragments = partner_dao.get_user_fragments(user_id)
    local fragment_map = {}
    for _, fragment in ipairs(fragments) do
        fragment_map[fragment.fragment_id] = fragment.count
    end
    
    -- 处理伙伴状态
    local result = {}
    for _, unit in pairs(all_units) do
        local partner = M.find_partner_by_unit_id(partners, unit.unit_id)
        
        if partner then
            -- 已解锁
            partner.state = 1
            table.insert(result, partner)
        else
            -- 未解锁，检查可否解锁
            local frag_count = fragment_map[unit.fragment_id] or 0
            local state = frag_count >= unit.unlock_fragment and 2 or 3
            
            table.insert(result, {
                partner_id = 0,
                unit_id = unit.unit_id,
                level = 0,
                star = 0,
                exp = 0,
                state = state,
                fragment_count = frag_count,
                attributes = M.calculate_attributes(unit, 1, 0)
            })
        end
    end
    
    return result
end

-- 伙伴升级
function M.upgrade_partner(user_id, partner_id)
    -- 实现升级逻辑
end

-- 其他服务方法...

return M
```

4. **实现处理器**

```lua
-- service/game/handlers/partner/partner_list_handler.lua
local M = {}
local partner_service = require "game.services.partner_service"

function M.handle(client_id, msg)
    -- 验证token
    local user_id = auth.verify_token(msg.token)
    if not user_id then
        return error_mgr.token_invalid()
    end
    
    -- 获取伙伴列表
    local partners = partner_service.get_partner_list(user_id)
    
    -- 返回响应
    return {
        partners = partners
    }
end

return M
```

5. **注册处理器**

```lua
-- service/game/message_mgr.lua
local partner_list_handler = require "game.handlers.partner.partner_list_handler"
local partner_upgrade_handler = require "game.handlers.partner.partner_upgrade_handler"

-- 注册处理器
M.register(pb.enum("common.MessageID", "C2G_PARTNER_LIST_REQUEST"), partner_list_handler)
M.register(pb.enum("common.MessageID", "C2G_PARTNER_UPGRADE_REQUEST"), partner_upgrade_handler)
-- 注册其他伙伴相关处理器...
```

#### 注意事项
1. 伙伴属性计算需考虑等级、星级、品质等因素
2. 伙伴状态更新应及时清除缓存
3. 解锁新伙伴时需确保数据一致性
4. 升级和升星操作需要正确扣除所需材料
5. 多节点部署时需确保缓存一致性

#### 常见问题
1. **Q: 伙伴状态不正确?**
   A: 检查碎片数量计算逻辑，确保正确设置状态值(1:已解锁 2:可解锁 3:未解锁)
   
2. **Q: 属性计算错误?**
   A: 检查属性计算公式，确保正确应用各种加成

3. **Q: 缓存不一致?**
   A: 在修改伙伴数据后，确保调用 `cache.delete(key)` 清除相关缓存

// ... existing code ... 