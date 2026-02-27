#!/bin/bash

# ============================================================
# 服务管理脚本通用范本
# ============================================================
#
# 用法: ./service.sh [start|stop|restart|status|logs|test|help]
#
# 命令说明:
#   start   - 后台启动服务
#   stop    - 停止服务
#   restart - 重启服务
#   status  - 查看服务状态
#   logs    - 查看实时日志
#   test    - 运行测试程序（test/helloworld.py）
#   help    - 显示帮助信息

# ============================================================
# 配置变量 - 根据实际项目修改这些变量
# ============================================================

# 服务显示名称
SERVICE_NAME="SlowMovie 慢电影播放器"

# 应用名称（用于标识）
APP_NAME="slowmovie"

# PID 文件路径
PID_FILE="slowmovie.pid"

# 日志文件路径
LOG_FILE="logs/slowmovie.log"

# 启动命令（根据项目类型修改）
START_CMD="python3 slowmovie.py"

# 服务端口（用于状态检查，可选）
SERVICE_PORT=""

# 是否启用 Python 虚拟环境 (true/false)
USE_VENV="true"

# 是否需要检查依赖 (true/false)
CHECK_DEPS="false"

# 依赖文件路径（如果 CHECK_DEPS=true）
DEPS_FILE="requirements.txt"

# ============================================================
# 以下为通用功能代码，一般不需要修改
# ============================================================

# 显示帮助信息
# 以下为通用功能代码，一般不需要修改
# ============================================================

# 显示帮助信息
show_help() {
    echo "$SERVICE_NAME - 服务管理脚本"
    echo ""
    echo "用法: $0 [install|start|stop|restart|status|logs|cleanup|test|help]"
    echo ""
    echo "命令说明:"
    echo "  install - 初始化项目（创建目录、安装依赖、编译等）"
    echo "  start   - 后台启动服务"
    echo "  stop    - 停止服务"
    echo "  restart - 重启服务"
    echo "  status  - 查看服务状态"
    echo "  logs    - 查看实时日志"
    echo "  cleanup - 清理僵尸进程和端口占用"
    echo "  test    - 运行测试程序（helloworld.py）"
    echo "  help    - 显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 install  # 首次使用，初始化项目"
    echo "  $0 start    # 启动服务"
    echo "  $0 status   # 查看状态"
    echo "  $0 cleanup  # 清理僵尸进程"
    echo "  $0 logs     # 查看日志"
    echo "  $0 stop     # 停止服务"
}

# 检查 Python 环境（仅在 USE_VENV=true 时使用）
check_python() {
    if ! command -v python3 &> /dev/null; then
        echo "错误: 未找到 Python3，请先安装 Python3"
        exit 1
    fi
}

# 清理 GPIO 占用的僵尸进程（SlowMovie 专用）
cleanup_gpio() {
    echo "检查 GPIO 占用情况..."
    
    # 查找占用 gpiochip0 的进程
    local GPIO_PIDS=$(lsof /dev/gpiochip0 2>/dev/null | grep -v "^COMMAND" | awk '{print $2}' | sort -u)
    
    if [ -n "$GPIO_PIDS" ]; then
        echo "发现占用 GPIO 的进程:"
        for pid in $GPIO_PIDS; do
            local CMD=$(ps -p $pid -o cmd --no-headers 2>/dev/null)
            echo "  PID $pid: $CMD"
        done
        
        echo "正在清理 GPIO 占用进程..."
        for pid in $GPIO_PIDS; do
            kill -9 $pid 2>/dev/null
            echo "  ✓ 已终止 PID $pid"
        done
        
        # 等待 GPIO 释放
        sleep 2
        
        # 验证清理结果
        local REMAINING=$(lsof /dev/gpiochip0 2>/dev/null | grep -v "^COMMAND" | wc -l)
        if [ "$REMAINING" -eq 0 ]; then
            echo "✓ GPIO 已释放"
        else
            echo "⚠️ 警告: GPIO 仍被占用，可能需要手动检查"
        fi
    else
        echo "✓ GPIO 未被占用"
    fi
    
    # 同时清理可能存在的旧 slowmovie 进程
    local OLD_PIDS=$(pgrep -f "slowmovie.py" | grep -v "$$")
    if [ -n "$OLD_PIDS" ]; then
        echo "发现遗留的 slowmovie 进程:"
        for pid in $OLD_PIDS; do
            echo "  终止 PID $pid"
            kill -9 $pid 2>/dev/null
        done
    fi
}

# 检查虚拟环境（仅在 USE_VENV=true 时使用）
check_venv() {
    if [ ! -d "venv" ]; then
        echo "正在创建虚拟环境..."
        python3 -m venv venv

        if [ $? -ne 0 ]; then
            echo "错误: 虚拟环境创建失败"
            exit 1
        fi
    fi
}

# 安装依赖（仅在 CHECK_DEPS=true 时使用）
install_deps() {
    if [ ! -f "$DEPS_FILE" ]; then
        echo "警告: 依赖文件 $DEPS_FILE 不存在，跳过依赖安装"
        return
    fi

    echo "检查并安装依赖包..."

    if [ "$USE_VENV" = "true" ]; then
        source venv/bin/activate
    fi

    pip install -r "$DEPS_FILE" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "错误: 依赖包安装失败"
        exit 1
    fi

    echo "依赖包检查完成"
}

# 启动服务
start_service() {
    echo "=========================================="
    echo "$SERVICE_NAME - 启动服务"
    echo "=========================================="

    # 检查服务是否已经运行
    if [ -f "$PID_FILE" ]; then
        PID=$(cat $PID_FILE)
        if ps -p $PID > /dev/null 2>&1; then
            echo "服务已经在运行中 (PID: $PID)"
            echo "如需重启，请使用: $0 restart"
            exit 1
        else
            echo "PID 文件存在但进程不存在，清理旧的 PID 文件"
            rm -f $PID_FILE
        fi
    fi

    # 检查环境和依赖（如果启用）
    if [ "$USE_VENV" = "true" ]; then
        check_python
        check_venv
    fi

    if [ "$CHECK_DEPS" = "true" ]; then
        install_deps
    fi

    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")"

    # 清理 GPIO 占用（SlowMovie 专用）
    cleanup_gpio
    echo ""

    # 检查端口是否被占用（如果配置了端口）
    if [ -n "$SERVICE_PORT" ]; then
        echo "检查端口 $SERVICE_PORT 可用性..."

        # 尝试多种检测方式
        PORT_OCCUPIED=false
        OCCUPIER_INFO=""

        if command -v lsof &> /dev/null; then
            if lsof -i :$SERVICE_PORT -sTCP:LISTEN >/dev/null 2>&1; then
                PORT_OCCUPIED=true
                OCCUPIER_INFO=$(lsof -i :$SERVICE_PORT -sTCP:LISTEN | tail -1)
            fi
        elif command -v netstat &> /dev/null; then
            if netstat -tlnp 2>/dev/null | grep ":$SERVICE_PORT " >/dev/null; then
                PORT_OCCUPIED=true
                OCCUPIER_INFO=$(netstat -tlnp 2>/dev/null | grep ":$SERVICE_PORT ")
            fi
        elif command -v ss &> /dev/null; then
            if ss -tlnp 2>/dev/null | grep ":$SERVICE_PORT " >/dev/null; then
                PORT_OCCUPIED=true
                OCCUPIER_INFO=$(ss -tlnp 2>/dev/null | grep ":$SERVICE_PORT ")
            fi
        fi

        if [ "$PORT_OCCUPIED" = true ]; then
            echo "✗ 端口 $SERVICE_PORT 已被占用！"
            echo ""
            echo "占用进程信息:"
            echo "  $OCCUPIER_INFO"
            echo ""
            echo "解决方案："
            echo "  1. 修改本项目的 SERVICE_PORT 为其他端口"
            echo "  2. 停止占用该端口的其他服务"
            echo "  3. 使用 $0 cleanup 清理僵尸进程"
            exit 1
        fi

        echo "✓ 端口 $SERVICE_PORT 可用"
    fi

    echo "正在启动服务..."

    # 准备启动命令
    if [ "$USE_VENV" = "true" ]; then
        EXEC_CMD="source venv/bin/activate && $START_CMD"
    else
        EXEC_CMD="$START_CMD"
    fi

    # 启动服务
    nohup bash -c "$EXEC_CMD" > "$LOG_FILE" 2>&1 &
    PID=$!

    # 保存 PID
    echo $PID > $PID_FILE

    # 等待启动
    sleep 2

    # 检查进程是否真的在运行
    if ps -p $PID > /dev/null 2>&1; then
        echo "✓ 服务启动成功!"
        echo "  PID: $PID"
        echo "  日志文件: $LOG_FILE"

        # 显示访问地址（如果配置了端口）
        if [ -n "$SERVICE_PORT" ]; then
            echo ""
            echo "📡 访问地址:"
            echo "  本地访问: http://localhost:$SERVICE_PORT"

            # 获取局域网IP地址
            LOCAL_IP=""
            if command -v ip &> /dev/null; then
                # Linux 系统使用 ip 命令
                LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
            elif command -v ifconfig &> /dev/null; then
                # macOS 或其他系统使用 ifconfig
                LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
            fi

            if [ -n "$LOCAL_IP" ]; then
                echo "  局域网访问: http://$LOCAL_IP:$SERVICE_PORT"
            fi
        fi

        echo ""
        echo "管理命令:"
        echo "  $0 status - 查看状态"
        echo "  $0 logs   - 查看日志"
        echo "  $0 stop   - 停止服务"
    else
        echo "✗ 服务启动失败，请检查日志: $LOG_FILE"
        rm -f $PID_FILE
        exit 1
    fi
}

# 停止服务
stop_service() {
    echo "=========================================="
    echo "$SERVICE_NAME - 停止服务"
    echo "=========================================="

    # 检查 PID 文件是否存在
    if [ ! -f "$PID_FILE" ]; then
        echo "服务未运行（PID 文件不存在）"
        return 0
    fi

    # 读取 PID
    PID=$(cat $PID_FILE)

    # 检查进程是否存在
    if ! ps -p $PID > /dev/null 2>&1; then
        echo "进程不存在 (PID: $PID)，清理 PID 文件"
        rm -f $PID_FILE
        return 0
    fi

    echo "正在停止服务 (PID: $PID)..."

    # 尝试优雅停止
    kill $PID

    # 等待进程结束
    for i in {1..10}; do
        if ! ps -p $PID > /dev/null 2>&1; then
            echo "✓ 服务已优雅停止"
            rm -f $PID_FILE

            # 额外检查：如果配置了端口，确保端口已释放
            if [ -n "$SERVICE_PORT" ]; then
                sleep 1  # 等待端口释放

                if command -v lsof &> /dev/null; then
                    if lsof -i :$SERVICE_PORT >/dev/null 2>&1; then
                        echo "⚠️  检测到端口 $SERVICE_PORT 仍被占用，正在清理..."
                        PORT_PID=$(lsof -i :$SERVICE_PORT -t 2>/dev/null)
                        if [ -n "$PORT_PID" ]; then
                            kill -9 $PORT_PID 2>/dev/null
                            echo "✓ 端口占用进程已清理 (PID: $PORT_PID)"
                        fi
                    fi
                fi
            fi

            return 0
        fi
        echo "等待进程结束... ($i/10)"
        sleep 1
    done

    # 如果优雅停止失败，强制停止
    echo "优雅停止失败，强制停止服务..."
    kill -9 $PID

    # 再次检查
    if ! ps -p $PID > /dev/null 2>&1; then
        echo "✓ 服务已强制停止"
        rm -f $PID_FILE

        # 额外检查：如果配置了端口，确保端口已释放
        if [ -n "$SERVICE_PORT" ]; then
            sleep 1  # 等待端口释放

            if command -v lsof &> /dev/null; then
                if lsof -i :$SERVICE_PORT >/dev/null 2>&1; then
                    echo "⚠️  检测到端口 $SERVICE_PORT 仍被占用，正在清理..."
                    PORT_PID=$(lsof -i :$SERVICE_PORT -t 2>/dev/null)
                    if [ -n "$PORT_PID" ]; then
                        kill -9 $PORT_PID 2>/dev/null
                        echo "✓ 端口占用进程已清理 (PID: $PORT_PID)"
                    fi
                fi
            fi
        fi

        return 0
    else
        echo "✗ 无法停止服务，请手动检查"
        return 1
    fi
}

# 重启服务
restart_service() {
    echo "=========================================="
    echo "$SERVICE_NAME - 重启服务"
    echo "=========================================="

    echo "正在停止服务..."
    stop_service

    echo ""
    echo "正在启动服务..."
    start_service
}

# 查看服务状态
show_status() {
    echo "=========================================="
    echo "$SERVICE_NAME - 服务状态"
    echo "=========================================="

    # 检查 PID 文件是否存在
    if [ ! -f "$PID_FILE" ]; then
        echo "服务状态: 未运行"
        echo "PID 文件不存在"
        echo ""
        echo "启动服务: $0 start"
        exit 0
    fi

    # 读取 PID
    PID=$(cat $PID_FILE)

    # 检查进程是否存在
    if ps -p $PID > /dev/null 2>&1; then
        # 获取进程信息
        CMDLINE=$(ps -p $PID -o cmd --no-headers)
        START_TIME=$(ps -p $PID -o lstart --no-headers)
        CPU_USAGE=$(ps -p $PID -o %cpu --no-headers)
        MEM_USAGE=$(ps -p $PID -o %mem --no-headers)

        echo "服务状态: ✓ 正在运行"
        echo "进程ID: $PID"
        echo "启动时间: $START_TIME"
        echo "CPU使用: ${CPU_USAGE}%"
        echo "内存使用: ${MEM_USAGE}%"
        echo "命令行: $CMDLINE"
        echo ""

        # 显示访问地址（如果配置了端口）
        if [ -n "$SERVICE_PORT" ]; then
            echo "📡 访问地址:"
            echo "  本地访问: http://localhost:$SERVICE_PORT"

            # 获取局域网IP地址
            LOCAL_IP=""
            if command -v ip &> /dev/null; then
                # Linux 系统使用 ip 命令
                LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
            elif command -v ifconfig &> /dev/null; then
                # macOS 或其他系统使用 ifconfig
                LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
            fi

            if [ -n "$LOCAL_IP" ]; then
                echo "  局域网访问: http://$LOCAL_IP:$SERVICE_PORT"
            fi

            # 检查端口是否在监听
            echo ""
            echo "端口监听状态:"
            PORT_LISTENING=false
            if command -v netstat &> /dev/null; then
                if netstat -tlnp 2>/dev/null | grep ":$SERVICE_PORT " > /dev/null; then
                    echo "  端口 $SERVICE_PORT: ✓ 正在监听"
                    PORT_LISTENING=true
                else
                    echo "  端口 $SERVICE_PORT: ✗ 未监听"
                fi
            elif command -v ss &> /dev/null; then
                if ss -tlnp 2>/dev/null | grep ":$SERVICE_PORT " > /dev/null; then
                    echo "  端口 $SERVICE_PORT: ✓ 正在监听"
                    PORT_LISTENING=true
                else
                    echo "  端口 $SERVICE_PORT: ✗ 未监听"
                fi
            elif command -v lsof &> /dev/null; then
                if lsof -i :$SERVICE_PORT -sTCP:LISTEN > /dev/null 2>&1; then
                    echo "  端口 $SERVICE_PORT: ✓ 正在监听"
                    PORT_LISTENING=true
                else
                    echo "  端口 $SERVICE_PORT: ✗ 未监听"
                fi
            else
                echo "  (无法检查端口状态，缺少 netstat/ss/lsof 命令)"
            fi
            echo ""
        fi

        echo "日志文件: $LOG_FILE"
        echo ""
        echo "管理命令:"
        echo "  $0 logs     - 查看日志"
        echo "  $0 restart  - 重启服务"
        echo "  $0 stop     - 停止服务"

    else
        echo "服务状态: ✗ 进程不存在"
        echo "PID 文件存在但进程不在运行"
        echo "清理 PID 文件..."
        rm -f $PID_FILE
        echo ""
        echo "启动服务: $0 start"
    fi
}

# 查看日志
show_logs() {
    echo "=========================================="
    echo "$SERVICE_NAME - 实时日志"
    echo "=========================================="
    echo "按 Ctrl+C 退出日志查看"
    echo ""

    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        echo "日志文件不存在: $LOG_FILE"
        echo "请先启动服务: $0 start"
    fi
}

# 清理服务
cleanup_service() {
    echo "=========================================="
    echo "$SERVICE_NAME - 清理服务"
    echo "=========================================="

    CLEANED=false

    # 1. 清理 PID 文件对应的进程
    if [ -f "$PID_FILE" ]; then
        PID=$(cat $PID_FILE)
        if ps -p $PID > /dev/null 2>&1; then
            echo "清理 PID 文件中的进程 ($PID)..."
            kill -9 $PID 2>/dev/null
            CLEANED=true
        fi
        rm -f $PID_FILE
        echo "✓ PID 文件已清理"
    fi

    # 2. 清理端口占用进程
    if [ -n "$SERVICE_PORT" ]; then
        if command -v lsof &> /dev/null; then
            PORT_PIDS=$(lsof -i :$SERVICE_PORT -t 2>/dev/null)
            if [ -n "$PORT_PIDS" ]; then
                echo "清理端口 $SERVICE_PORT 占用进程..."
                for pid in $PORT_PIDS; do
                    kill -9 $pid 2>/dev/null
                    echo "  已清理进程: $pid"
                    CLEANED=true
                done
            fi
        fi
    fi

    if [ "$CLEANED" = false ]; then
        echo "未发现需要清理的进程"
    else
        echo ""
        echo "✓ 清理完成"
    fi
}

# 初始化安装
install_service() {
    echo "=========================================="
    echo "$SERVICE_NAME - 初始化安装"
    echo "=========================================="
    echo ""

    # 1. 创建必要的目录
    echo "📁 创建必要的目录..."

    # 从 LOG_FILE 提取目录路径
    LOG_DIR=$(dirname "$LOG_FILE")
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        echo "  ✓ 创建日志目录: $LOG_DIR"
    else
        echo "  ✓ 日志目录已存在: $LOG_DIR"
    fi

    # 创建其他常用目录（如果需要）
    for dir in data tmp cache; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "  ✓ 创建目录: $dir"
        fi
    done

    echo ""

    # 2. 检查和创建 Python 虚拟环境
    if [ "$USE_VENV" = "true" ]; then
        echo "🐍 检查 Python 环境..."
        check_python

        if [ ! -d "venv" ]; then
            echo "  正在创建虚拟环境..."
            python3 -m venv venv
            if [ $? -eq 0 ]; then
                echo "  ✓ 虚拟环境创建成功"
            else
                echo "  ✗ 虚拟环境创建失败"
                exit 1
            fi
        else
            echo "  ✓ 虚拟环境已存在"
        fi
        echo ""
    fi

    # 3. 安装依赖
    if [ "$CHECK_DEPS" = "true" ] && [ -f "$DEPS_FILE" ]; then
        echo "📦 安装项目依赖..."

        if [ "$USE_VENV" = "true" ]; then
            source venv/bin/activate
        fi

        # 根据依赖文件类型选择包管理器
        if [ "$DEPS_FILE" = "requirements.txt" ]; then
            pip install -r "$DEPS_FILE"
            if [ $? -eq 0 ]; then
                echo "  ✓ Python 依赖安装成功"
            else
                echo "  ✗ Python 依赖安装失败"
                exit 1
            fi
        elif [ "$DEPS_FILE" = "package.json" ]; then
            npm install
            if [ $? -eq 0 ]; then
                echo "  ✓ Node.js 依赖安装成功"
            else
                echo "  ✗ Node.js 依赖安装失败"
                exit 1
            fi
        elif [ "$DEPS_FILE" = "go.mod" ]; then
            go mod download
            if [ $? -eq 0 ]; then
                echo "  ✓ Go 依赖安装成功"
            else
                echo "  ✗ Go 依赖安装失败"
                exit 1
            fi
        fi
        echo ""
    fi

    # 4. 编译步骤（如果需要）
    # 可以在这里添加项目特定的编译命令
    # 例如: Go 项目编译、前端构建等

    echo "=========================================="
    echo "✓ 初始化完成！"
    echo "=========================================="
    echo ""
    echo "下一步:"
    echo "  $0 start    # 启动服务"
    echo "  $0 status   # 查看状态"
}

# 运行测试
run_test() {
    echo "=========================================="
    echo "$SERVICE_NAME - 运行测试"
    echo "=========================================="

    # 检查环境
    if [ "$USE_VENV" = "true" ]; then
        check_python
        check_venv
    fi

    # 检查测试文件是否存在
    if [ ! -f "test/helloworld.py" ]; then
        echo "错误: 测试文件 test/helloworld.py 不存在"
        exit 1
    fi

    echo "正在运行 test/helloworld.py 测试..."
    echo ""

    # 运行测试
    if [ "$USE_VENV" = "true" ]; then
        source venv/bin/activate
        python3 test/helloworld.py "$@"
    else
        python3 test/helloworld.py "$@"
    fi

    TEST_RESULT=$?

    echo ""
    if [ $TEST_RESULT -eq 0 ]; then
        echo "✓ 测试完成"
    else
        echo "✗ 测试失败，退出码: $TEST_RESULT"
        exit $TEST_RESULT
    fi
}

# 主程序
main() {
    case "$1" in
        install)
            install_service
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        cleanup)
            cleanup_service
            ;;
        test)
            shift  # 移除 'test' 参数
            run_test "$@"  # 传递剩余参数给测试程序
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            echo "错误: 未知命令 '$1'"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 执行主程序
main "$@"
