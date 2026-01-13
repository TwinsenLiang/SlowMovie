# 慢电影墨水屏播放器（基于 Python）

![](Extras/img.jpg)

## 设备准备

1. Raspberry Pi 4B (https://www.raspberrypi.org/products/raspberry-pi-4-model-b/)
2. 6inch HD e-Paper HAT from Waveshare (https://www.waveshare.net/wiki/6inch_HD_e-Paper_HAT)
3. VÄSTANHED from Ikea (https://www.ikea.cn/cn/zh/p/vaestanhed-wei-tan-he-hua-kuang-hei-se-20479217/)

## 项目说明

最早是在网上看到慢电影这个项目觉得比较有意思。准备了手头的一些设备之后发现是个坑，微雪的 6 寸高清屏走的是 IT8951 的控制器。国外旧有 Python 项目并没有对高清屏 IT8951 的支持。于是就手动合并了两个 git 上面的项目，给有兴趣的小伙伴耍耍。

### 项目架构

本项目采用模块化架构：
- **SlowMovie（主程序）**: 视频帧提取和播放控制
- **IT8951（驱动层）**: 微雪高清墨水屏硬件驱动

详细架构说明请查看 [ARCHITECTURE.md](ARCHITECTURE.md)

## 安装步骤

### 1. 启用 SPI 接口

```bash
sudo raspi-config
```

或者参照其他方法[打开 SPI](https://www.raspberrypi-spy.co.uk/2014/08/enabling-the-spi-interface-on-the-raspberry-pi/)

### 2. 安装系统依赖

```bash
sudo apt update
sudo apt install -y ffmpeg build-essential python3-dev
```

**依赖说明**:
- `ffmpeg`: 视频帧提取工具
- `build-essential`: C 编译工具（IT8951 驱动编译需要）
- `python3-dev`: Python 开发头文件

### 3. 安装 Python 依赖和驱动

#### 方法一：使用 rpi-lgpio（推荐，适用于 Python 3.12+）

```bash
git clone https://github.com/TwinsenLiang/SlowMovie.git
cd SlowMovie

# 创建虚拟环境（在项目根目录）
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 安装主程序依赖
pip install -r requirements.txt

# 安装 IT8951 驱动
cd IT8951
pip install -r requirements.txt
pip install ./
cd ..
```

**关于 GPIO 库选择**:
- `rpi-lgpio` 是 `RPi.GPIO` 的现代替代品，API 完全兼容，支持 Python 3.12+
- Python 3.12+ 移除了 `longintrepr.h`，导致旧版 `RPi.GPIO` 无法编译
- 如果遇到 `fatal error: longintrepr.h: No such file or directory` 错误，请使用此方法

#### 方法二：使用系统预编译的 RPi.GPIO（适用于 Python 3.11 及以下）

```bash
git clone https://github.com/TwinsenLiang/SlowMovie.git
cd SlowMovie

# 安装系统级 GPIO 库
sudo apt install python3-rpi.gpio

# 创建虚拟环境（允许使用系统包）
python3 -m venv --system-site-packages venv

# 激活虚拟环境
source venv/bin/activate

# 安装主程序依赖
pip install -r requirements.txt

# 安装 IT8951 驱动（跳过 rpi-lgpio）
cd IT8951
pip install pillow
pip install ./
cd ..
```

### 4. 设置 SPI 和 GPIO 权限（可选但推荐）

```bash
# 将当前用户加入 spi 和 gpio 组
sudo usermod -aG spi,gpio $USER

# 重新登录或重启以使权限生效
# 这样就可以无需 sudo 运行程序
```

## 使用方法

### 测试安装

```bash
cd ~/SlowMovie/
./service.sh test
```

理应能看到只睡觉的企鹅：

![avatar](/images/sleeping_penguin.png)

### 启动服务

SlowMovie 使用统一的 `service.sh` 脚本管理服务：

```bash
cd ~/SlowMovie/

# 运行测试
./service.sh test

# 启动服务（后台运行）
./service.sh start

# 查看服务状态
./service.sh status

# 查看实时日志
./service.sh logs

# 停止服务
./service.sh stop

# 重启服务
./service.sh restart
```

### 命令行参数

可以通过 `slowmovie.py` 直接运行（前台模式）：

```bash
source venv/bin/activate
python3 slowmovie.py [参数]
```

可用参数：
- `-f FILE`: 指定视频文件
- `-d DELAY`: 帧间延迟（秒，默认 120）
- `-i INCREMENT`: 每次跳过的帧数（默认 5）
- `-s START`: 起始帧位置
- `-r`: 随机模式

示例：
```bash
# 播放特定视频，每 10 秒更新一帧
python3 slowmovie.py -f Videos/movie.mp4 -d 10 -i 1
```

## 设定自启动

### 方法一：修改树莓派启动项

```bash
sudo nano /etc/profile
```

在最后加入代码：
```bash
cd ~/SlowMovie/
./service.sh start
```

### 方法二：使用 PM2

```bash
# 安装 PM2
sudo npm install -g pm2

# 设置 PM2 开机启动
pm2 startup
# 运行此命令后会显示一个类似如下的命令，复制此命令到终端运行
# sudo env PATH=$PATH:/usr/bin /usr/local/lib/node_modules/pm2/bin/pm2 startup systemd -u pi --hp /home/pi

# 使用 PM2 启动 SlowMovie
cd ~/SlowMovie/
pm2 start service.sh -- start

# 保存 PM2 配置
pm2 save

# 停止服务（可选）
pm2 stop service
```

## 项目结构

```
SlowMovie/
├── venv/                    # Python 虚拟环境
├── requirements.txt         # 主程序依赖（ffmpeg-python, pillow）
├── service.sh               # 服务管理脚本（包含 test 命令）
├── slowmovie.py            # 主程序
├── helloworld.py           # 测试程序
├── functions.py            # 通用函数
├── Videos/                 # 视频文件目录
├── logs/                   # 日志目录
└── IT8951/                 # 墨水屏驱动模块
    ├── requirements.txt    # 驱动依赖（rpi-lgpio, pillow）
    ├── setup.py           # 驱动安装脚本
    └── IT8951/            # 驱动源代码
```

## 依赖说明

### 主程序依赖（requirements.txt）
- `pillow>=10.0`: 图像处理
- `ffmpeg-python`: 视频帧提取（需要系统安装 ffmpeg）

### IT8951 驱动依赖（IT8951/requirements.txt）
- `rpi-lgpio`: GPIO 控制（替代 RPi.GPIO）
- `pillow`: 图像处理（驱动层需要）

## 兼容性

### 系统架构支持

SlowMovie 项目完全支持 **32位和64位** ARM 架构：

| 树莓派型号 | 系统架构 | 支持情况 | 说明 |
|-----------|---------|---------|------|
| 树莓派 Zero / Zero W | 32位 (armv6l) | ✅ 完全支持 | 成本最优方案 |
| 树莓派 1 | 32位 (armv6l) | ✅ 完全支持 | |
| 树莓派 2/3/4 (32位系统) | 32位 (armv7l) | ✅ 完全支持 | |
| 树莓派 3/4/5 (64位系统) | 64位 (aarch64) | ✅ 完全支持 | |

**核心组件架构兼容性**：
- ✅ **IT8951 驱动**: 从源码编译，自动适配目标架构
- ✅ **主程序 (slowmovie.py)**: 纯 Python，跨架构兼容
- ⚠️ **e-paper 目录**: 仅适用于 64 位系统（包含预编译 64 位库）

### 软件版本要求

- **Python 版本**: 3.9+ (推荐 3.11 或 3.13)
- **操作系统**: Raspberry Pi OS Bullseye / Bookworm
- **墨水屏**: Waveshare 6inch HD e-Paper HAT (IT8951 控制器)

详细兼容性信息请查看 [COMPATIBILITY.md](COMPATIBILITY.md)

## 原始的一些仓库和资料

Forked from [TomWhitwell/SlowMovie](https://github.com/TomWhitwell/SlowMovie/tree/v0.2-revisions)
TomWhitwell 的 main 版本驱动配置有点问题，建议非 HDMI 的同学用回 0.2 版本。

Forked from [GregDMeyer/IT8951](https://github.com/GregDMeyer/IT8951)

Waveshare 针对 IT8951 的仓库 [Waveshare/IT8951-ePaper](https://github.com/waveshare/IT8951-ePaper)

慢电影原始项目 (https://medium.com/@tomwhitwell/how-to-build-a-very-slow-movie-player-in-2020-c5745052e4e4)

Bryan 的帖子 (https://medium.com/s/story/very-slow-movie-player-499f76c48b62)

## 常见问题

### Q: 遇到 `longintrepr.h: No such file or directory` 错误？
A: 这是 Python 3.12+ 的已知问题。请使用方法一安装（使用 rpi-lgpio）。

### Q: 遇到 `font.getsize()` 相关错误？
A: Pillow 10.0+ 移除了此方法。项目代码已修复此问题，请确保使用最新版本。

### Q: 需要 sudo 权限才能运行？
A: 执行步骤 4 将用户加入 spi 和 gpio 组，然后重新登录即可。

### Q: 如何更换视频？
A: 将视频文件（.mp4 格式）放入 `Videos/` 目录，程序会自动播放。

### Q: 在 32 位系统上运行 e-paper 示例时报错 "wrong ELF class: ELFCLASS64"？
A: 这是正常的。`e-paper/` 目录包含 Waveshare 官方的 64 位预编译库，不兼容 32 位系统（如树莓派 Zero）。请使用主项目的 IT8951 驱动，它完全支持 32 位和 64 位系统。详见 [e-paper/README.md](e-paper/README.md)。

## 更新日志

详见 [CHANGES.md](CHANGES.md)

## License

本项目基于原项目的开源协议。
