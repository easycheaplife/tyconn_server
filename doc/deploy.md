# 部署指南

## 环境准备

### 1. 系统要求
- 操作系统: CentOS 7+ / Ubuntu 18.04+
- CPU: 4核+
- 内存: 8GB+
- 磁盘: 50GB+

### 2. 依赖安装
```bash
# CentOS
yum install -y git gcc make autoconf readline-devel
yum install -y mysql-devel mysql-server redis nginx

# Ubuntu
apt-get install -y git gcc make autoconf libreadline-dev
apt-get install -y libmysqlclient-dev mysql-server redis-server nginx
```

### 3. Lua环境
```bash
# 安装LuaJIT
git clone https://github.com/LuaJIT/LuaJIT.git
cd LuaJIT
make && make install

# 设置环境变量
echo "export LUAJIT_LIB=/usr/local/lib" >> ~/.bashrc
echo "export LUAJIT_INC=/usr/local/include/luajit-2.1" >> ~/.bashrc
source ~/.bashrc
```

## 服务器部署

### 1. 获取代码
```bash
git clone https://github.com/yourusername/tyconn.git
cd tyconn
git submodule update --init --recursive
```

### 2. 编译安装
```bash
# 编译skynet
cd skynet
make linux

# 编译项目
cd ..
make
```

### 3. 配置数据库
```bash
# 创建数据库
mysql -u root -p
> CREATE DATABASE tyconn;
> GRANT ALL PRIVILEGES ON tyconn.* TO 'tyconn'@'localhost' IDENTIFIED BY 'your_password';
> FLUSH PRIVILEGES;
> EXIT;

# 导入数据库结构
mysql -u tyconn -p tyconn < sql/schema.sql
```

### 4. 配置Nginx
```bash
# 复制Nginx配置
sudo cp nginx/conf/game.conf /etc/nginx/conf.d/

# 修改配置
sudo vim /etc/nginx/conf.d/game.conf
# 修改upstream中的服务器地址和端口

# 重启Nginx
sudo systemctl restart nginx
```

### 5. 配置服务器
```bash
# 复制配置文件
cp etc/config.example.lua etc/config.lua

# 修改配置
vim etc/config.lua
# 修改数据库连接信息和其他配置

# 设置环境变量
cp env.example .env
vim .env
source .env
```

### 6. 启动服务器
```bash
# 启动所有服务
./scripts/server.sh start

# 检查状态
./scripts/server.sh status

# 查看日志
./scripts/server.sh logs game1
```

## 集群部署

### 1. 修改集群配置
```lua
-- etc/cluster.lua
login = "192.168.1.10:1001"    -- 登录服务器
game1 = "192.168.1.11:2001"    -- 游戏服务器1
game2 = "192.168.1.12:2002"    -- 游戏服务器2
gate1 = "192.168.1.13:3001"    -- 网关服务器1
gate2 = "192.168.1.14:3002"    -- 网关服务器2
db_proxy = "192.168.1.15:4001" -- 数据库代理
```

### 2. 配置负载均衡
```nginx
# nginx/conf/upstream.conf
upstream game_server {
    ip_hash;  # 使用IP哈希确保同一客户端连接到同一服务器
    server 192.168.1.13:8031;  # gate1
    server 192.168.1.14:8032;  # gate2
}
```

### 3. 启动集群
```bash
# 在各个服务器上启动对应服务

# 登录服务器
./scripts/server.sh start login

# 游戏服务器
./scripts/server.sh start game1
./scripts/server.sh start game2

# 网关服务器
./scripts/server.sh start gate1
./scripts/server.sh start gate2

# 数据库代理
./scripts/server.sh start db_proxy
```

## 监控部署

### 1. 配置监控
```bash
# 安装监控工具
yum install -y prometheus grafana

# 复制监控配置
cp monitor/prometheus.yml /etc/prometheus/
cp monitor/grafana.ini /etc/grafana/
```

### 2. 启动监控
```bash
# 启动Prometheus
systemctl start prometheus

# 启动Grafana
systemctl start grafana-server
```

## 常见问题

### 1. 端口被占用
```bash
# 检查端口占用
netstat -tunlp | grep PORT

# 关闭占用进程
kill -9 PID
```

### 2. 日志查看
```bash
# 实时查看日志
tail -f logs/game1.log

# 查看错误日志
grep ERROR logs/game1.log
```

### 3. 性能问题
```bash
# 查看CPU使用
top -H -p PID

# 查看内存使用
pmap PID
``` 