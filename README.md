# TyConn 游戏服务器框架

TyConn是一个基于Skynet的游戏服务器框架,提供基础的游戏服务器功能。

## 主要特性

- 分布式架构
- 支持集群部署
- WebSocket通信
- 数据库连接池
- 缓存管理
- 心跳机制
- 日志系统
- 监控报警

## 快速开始

### 环境要求

- Linux/MacOS
- Lua 5.3+
- MySQL 5.7+

### 安装

```bash
# 克隆仓库
git clone git@github.com:easycheaplife/tyconn_server.git
cd tyconn_server
git clone https://github.com/cloudwu/skynet.git
ln -s skynet/skynet ./skynet
```

### 配置

1. 修改配置
```lua
-- etc/config/mysql.lua
host = "127.0.0.1"
user = "root"
password = "123456"
database = "tyconn"
```

### 运行

```bash
# 启动服务器
./scripts/server.sh start

# 查看状态
./scripts/server.sh status

# 停止服务器
./scripts/server.sh stop
```

## 文档

- [架构设计](doc/architecture.md)
- [协议说明](doc/protocol.md)
- [配置说明](doc/config.md)
- [API文档](doc/api.md)
- [部署指南](doc/deploy.md)
- [开发指南](doc/develop.md)
- [测试说明](doc/test.md)

## 测试

```bash
# 安装测试依赖
cd test
npm install

# 运行测试
npm test
```