# 配置说明

## 环境变量配置

### 1. MySQL配置
```bash
# 数据库连接配置
export MYSQL_HOST="127.0.0.1"      # MySQL主机地址
export MYSQL_PORT="3306"           # MySQL端口
export MYSQL_USER="tyconn"         # MySQL用户名
export MYSQL_PASSWORD="your_password"    # MySQL密码
export MYSQL_DATABASE="tyconn"      # 数据库名
```

### 2. 服务器配置
```bash
# 服务器地址(用于客户端连接,默认127.0.0.1)
export SERVER_HOST="127.0.0.1"

# WebSocket协议(ws或wss,默认ws)
export WS_PROTOCOL="ws"

# 日志配置
export LOG_LEVEL=1                  # 日志级别(1:DEBUG,2:INFO,3:WARN,4:ERROR,5:FATAL)

# SSL配置(使用wss时需要)
export SSL_KEY_FILE="cert/server.key"   # SSL私钥文件路径
export SSL_CERT_FILE="cert/server.crt"  # SSL证书文件路径

# JWT配置
export JWT_SECRET="your_jwt_secret_key" # JWT密钥
export JWT_EXPIRE=3600             # JWT过期时间(秒)

# 版本配置
export VERSION_MIN="1.0.0"         # 最低支持版本
export VERSION_LATEST="1.0.0"      # 最新版本
export VERSION_FORCE_UPDATE="false" # 是否强制更新
```

## 服务器配置

### 1. 登录服务器(etc/config/login.lua)
```lua
include "../config/path.lua"

-- 基础配置
thread = 8                         -- 工作线程数
harbor = 0                         -- 集群编号

-- 启动配置
bootstrap = "snlua bootstrap"      -- 启动器
start = "node/login"              -- 入口服务

-- 集群配置
cluster = "etc/cluster.lua"       -- 集群配置文件
node_name = "login"               -- 节点名称

-- WebSocket配置
websocket_port = 8021             -- WebSocket端口
```

### 2. 网关服务器(etc/config/gate1.lua)
```lua
include "../config/path.lua"

-- 基础配置
thread = 8
harbor = 0

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/gate"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "gate1"

-- WebSocket配置
websocket_host = "127.0.0.1"
websocket_port = 8031

-- 状态同步配置
sync_interval = 60                -- 同步间隔(秒)

-- 节点选择配置
node_selector = "connection_hash" -- 节点选择策略
```

### 3. 游戏服务器(etc/config/game1.lua)
```lua
include "../config/path.lua"

-- 基础配置
thread = 8
harbor = 0

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/game"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "game1"

-- 心跳配置
heartbeat_timeout = 180          -- 心跳超时时间(秒)
```

### 4. 数据库代理(etc/config/db_proxy.lua)
```lua
include "../config/path.lua"

-- 基础配置
thread = 8
harbor = 0

-- 启动配置
bootstrap = "snlua bootstrap"
start = "node/db_proxy"

-- 集群配置
cluster = "etc/cluster.lua"
node_name = "db_proxy"
```

## 集群配置(etc/cluster.lua)
```lua
__nowaiting = true

login = "127.0.0.1:1001"
game1 = "127.0.0.1:2001"
game2 = "127.0.0.1:2002"
gate1 = "127.0.0.1:3001"
gate2 = "127.0.0.1:3002"
db_proxy = "127.0.0.1:4001"
```

## 路径配置(etc/config/path.lua)
```lua
root = "./"
skynet_root = "./skynet/"

-- C服务路径
cpath = skynet_root.."cservice/?.so"

-- Lua加载器
lualoader = skynet_root.."lualib/loader.lua"

-- Lua服务路径
luaservice = root.."service/?.lua;"..
            root.."service/game/?.lua;"..
            root.."service/gate/?.lua;"..
            root.."service/?/init.lua;"..
            skynet_root.."service/?.lua"

-- Lua模块路径
lua_path = root.."lualib/?.lua;"..
          root.."service/?.lua;"..
          root.."service/game/?.lua;"..
          root.."etc/?.lua;"..
          skynet_root.."lualib/?.lua;"..
          skynet_root.."lualib/?/init.lua"

-- C模块路径
lua_cpath = root.."luaclib/?.so;"..
           skynet_root.."luaclib/?.so"

-- protobuf 路径
proto_path = root.."proto/"
``` 