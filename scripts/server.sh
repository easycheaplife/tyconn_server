#!/bin/bash

# 服务器管理脚本使用说明：
#
# 1. 添加执行权限：
#    chmod +x scripts/server.sh
#
# 2. 可用命令：
#    启动服务器：./scripts/server.sh start
#    停止服务器：./scripts/server.sh stop
#    重启服务器：./scripts/server.sh restart
#    查看状态：./scripts/server.sh status
#    查看日志：./scripts/server.sh logs <node_name>
#
# 3. 日志查看选项：
#    - db_proxy：数据库代理日志
#    - game1/game2：游戏服务器日志
#    - gate1/gate2：网关服务器日志
#
# 4. 示例：
#    ./scripts/server.sh start      # 启动所有服务器
#    ./scripts/server.sh status     # 查看服务器状态
#    ./scripts/server.sh logs game1 # 查看游戏服务器1的日志
#    ./scripts/server.sh stop       # 停止所有服务器

# 服务器配置
WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"  # 获取项目根目录的绝对路径
SKYNET_PATH="$WORK_DIR/skynet/skynet"
PID_DIR="$WORK_DIR/run"
LOG_DIR="$WORK_DIR/logs"
GAME_NODES=2  # 默认游戏节点数
GATE_NODES=2  # 默认网关节点数

# 确保目录存在
mkdir -p "$PID_DIR" "$LOG_DIR"

# 获取进程ID文件路径
get_pid_file() {
    echo "$PID_DIR/$1.pid"
}

# 保存进程ID
save_pid() {
    echo "$2" > "$(get_pid_file "$1")"
}

# 读取进程ID
get_pid() {
    local pid_file
    pid_file=$(get_pid_file "$1")
    if [ -f "$pid_file" ]; then
        cat "$pid_file"
    fi
}

# 检查进程是否运行
is_process_running() {
    local pid=$1
    if [ -n "$pid" ]; then
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# 启动服务器
start_server() {
    echo "Starting servers..."
    
    # 切换到项目根目录
    cd "$WORK_DIR"
    
    # 启动数据库代理
    echo "Starting DB proxy..."
    nohup "$SKYNET_PATH" etc/config/db_proxy.lua > "$LOG_DIR/db_proxy.log" 2>&1 &
    save_pid "db_proxy" $!
    sleep 2
    
    # 启动游戏服务器
    for i in $(seq 1 "$GAME_NODES"); do
        echo "Starting game node $i..."
        nohup "$SKYNET_PATH" etc/config/game$i.lua > "$LOG_DIR/game$i.log" 2>&1 &
        save_pid "game$i" $!
        sleep 1
    done
    
    # 启动网关服务器
    for i in $(seq 1 "$GATE_NODES"); do
        echo "Starting gate node $i..."
        nohup "$SKYNET_PATH" etc/config/gate$i.lua > "$LOG_DIR/gate$i.log" 2>&1 &
        save_pid "gate$i" $!
        sleep 1
    done
    
    echo "All servers started"
}

# 停止服务器
stop_server() {
    echo "Stopping servers..."
    
    # 切换到项目根目录
    cd "$WORK_DIR"
    
    # 停止所有进程
    local processes=("db_proxy")
    for i in $(seq 1 "$GAME_NODES"); do
        processes+=("game$i")
    done
    for i in $(seq 1 "$GATE_NODES"); do
        processes+=("gate$i")
    done
    
    for proc in "${processes[@]}"; do
        local pid
        pid=$(get_pid "$proc")
        if [ -n "$pid" ] && is_process_running "$pid"; then
            echo "Stopping $proc (PID: $pid)..."
            kill -9 "$pid"  # 使用 SIGKILL 确保进程被终止
            rm -f "$(get_pid_file "$proc")"
        fi
    done
    
    echo "All servers stopped"
}

# 检查服务器状态
check_status() {
    echo "Server Status:"
    
    # 切换到项目根目录
    cd "$WORK_DIR"
    
    # 检查所有进程
    local processes=("db_proxy")
    for i in $(seq 1 "$GAME_NODES"); do
        processes+=("game$i")
    done
    for i in $(seq 1 "$GATE_NODES"); do
        processes+=("gate$i")
    done
    
    for proc in "${processes[@]}"; do
        local pid
        pid=$(get_pid "$proc")
        if [ -n "$pid" ] && is_process_running "$pid"; then
            echo "- $proc: Running (PID: $pid)"
            ps -p "$pid" -o pid,ppid,user,%cpu,%mem,time,command
        else
            echo "- $proc: Stopped"
            # 清理过期的 PID 文件
            rm -f "$(get_pid_file "$proc")"
        fi
    done
}

# 显示日志
show_logs() {
    local node=$1
    if [ -z "$node" ]; then
        echo "Usage: $0 logs <node_name>"
        echo "Available nodes: db_proxy, game1, game2, gate1, gate2"
        return 1
    fi
    
    local log_file="$LOG_DIR/$node.log"
    if [ -f "$log_file" ]; then
        tail -f "$log_file"
    else
        echo "Log file not found: $log_file"
        return 1
    fi
}

# 主函数
main() {
    case "$1" in
        start)
            start_server
            ;;
        stop)
            stop_server
            ;;
        restart)
            stop_server
            sleep 2
            start_server
            ;;
        status)
            check_status
            ;;
        logs)
            show_logs "$2"
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status|logs}"
            echo "Options for logs: db_proxy, game1, game2, gate1, gate2"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"