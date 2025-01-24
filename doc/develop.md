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
    require "game.handlers.user_info")
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