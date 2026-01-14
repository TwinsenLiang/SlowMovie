#!/bin/bash

# SlowMovie 一键安装脚本
# 适用于 Raspberry Pi OS (Bullseye/Bookworm)
# 支持 Python 3.9+

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo ""
    echo -e "${GREEN}===================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}===================================${NC}"
}

# 检查是否为 root 用户
if [ "$EUID" -eq 0 ]; then
    print_error "请不要使用 root 或 sudo 运行此脚本"
    print_info "脚本会在需要时自动请求 sudo 权限"
    exit 1
fi

# 检查是否在项目目录
if [ ! -f "slowmovie.py" ]; then
    print_error "请在 SlowMovie 项目根目录下运行此脚本"
    exit 1
fi

print_step "SlowMovie 一键安装脚本"

# 检查 Python 版本
print_info "检查 Python 版本..."
PYTHON_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+')
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

print_info "检测到 Python $PYTHON_VERSION"

if [ "$PYTHON_MAJOR" -lt 3 ] || [ "$PYTHON_MINOR" -lt 9 ]; then
    print_error "需要 Python 3.9 或更高版本"
    exit 1
fi

# 检查 SPI 是否启用
print_info "检查 SPI 接口..."
if [ ! -e /dev/spidev0.0 ]; then
    print_warning "SPI 接口未启用"
    print_info "请运行 'sudo raspi-config' 并在 Interface Options 中启用 SPI"
    read -p "是否现在打开 raspi-config? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo raspi-config
        print_info "配置完成后，请重新运行此安装脚本"
        exit 0
    else
        print_warning "跳过 SPI 配置，安装将继续"
        print_warning "注意：运行前需要手动启用 SPI 接口"
    fi
fi

# 安装系统依赖
print_step "步骤 1: 安装系统依赖"
print_info "需要安装: ffmpeg, build-essential, python3-dev, swig, liblgpio-dev"

read -p "是否继续安装系统依赖? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "用户取消安装"
    exit 1
fi

print_info "更新软件包列表..."
sudo apt update

print_info "安装系统依赖..."
sudo apt install -y ffmpeg build-essential python3-dev swig liblgpio-dev

print_success "系统依赖安装完成"

# 创建虚拟环境
print_step "步骤 2: 创建 Python 虚拟环境"

if [ -d "venv" ]; then
    print_warning "虚拟环境已存在"
    read -p "是否删除并重新创建? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "删除旧的虚拟环境..."
        rm -rf venv
    else
        print_info "使用现有虚拟环境"
    fi
fi

if [ ! -d "venv" ]; then
    print_info "创建虚拟环境..."
    python3 -m venv venv
    print_success "虚拟环境创建成功"
fi

# 激活虚拟环境
print_info "激活虚拟环境..."
source venv/bin/activate

# 升级 pip
print_info "升级 pip..."
pip install --upgrade pip

# 安装主程序依赖
print_step "步骤 3: 安装主程序依赖"
print_info "安装 ffmpeg-python 和 Pillow..."
pip install -r requirements.txt
print_success "主程序依赖安装完成"

# 安装 IT8951 驱动
print_step "步骤 4: 安装 IT8951 墨水屏驱动"
print_info "安装驱动依赖..."
cd driver/IT8951
pip install -r requirements.txt

print_info "编译并安装 IT8951 驱动（使用 Cython）..."
if [ "$PYTHON_MINOR" -ge 12 ]; then
    print_info "检测到 Python 3.12+，使用 Cython 从源码编译"
    USE_CYTHON=1 pip install --no-build-isolation ./
else
    print_info "使用标准安装方式"
    USE_CYTHON=1 pip install --no-build-isolation ./
fi

cd ../..
print_success "IT8951 驱动安装完成"

# 设置用户权限
print_step "步骤 5: 设置 SPI 和 GPIO 权限（可选）"
print_info "将当前用户添加到 spi 和 gpio 组可以无需 sudo 运行程序"

read -p "是否设置权限? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo usermod -aG spi,gpio $USER
    print_success "权限设置完成"
    print_warning "需要重新登录或重启后权限才会生效"
else
    print_info "跳过权限设置，运行程序时需要使用 sudo"
fi

# 运行测试
print_step "步骤 6: 测试安装"
print_info "运行屏幕测试..."

read -p "是否运行屏幕测试? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./service.sh test
    TEST_RESULT=$?

    if [ $TEST_RESULT -eq 0 ]; then
        print_success "测试通过！屏幕工作正常"
    else
        print_warning "测试未通过，但安装已完成"
        print_info "可能的原因："
        print_info "  1. 墨水屏未正确连接"
        print_info "  2. SPI 接口未启用"
        print_info "  3. 需要 sudo 权限运行"
    fi
else
    print_info "跳过测试"
fi

# 安装完成
print_step "安装完成！"
print_success "SlowMovie 已成功安装"
echo ""
print_info "快速使用指南："
echo "  1. 测试屏幕：./service.sh test"
echo "  2. 启动服务：./service.sh start"
echo "  3. 查看状态：./service.sh status"
echo "  4. 查看日志：./service.sh logs"
echo "  5. 停止服务：./service.sh stop"
echo ""
print_info "视频文件放入 Videos/ 目录即可播放"
echo ""

if groups | grep -q "spi" && groups | grep -q "gpio"; then
    print_info "权限已配置，可以直接运行程序"
else
    print_warning "权限未配置或未生效"
    print_info "重新登录后生效，或使用 sudo 运行程序"
fi

print_success "祝使用愉快！"
