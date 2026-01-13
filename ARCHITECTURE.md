# SlowMovie 项目架构分析

## 项目关系图

```
┌─────────────────────────────────────────────────────────┐
│ SlowMovie (核心应用)                                      │
│ - slowmovie.py: 主程序                                   │
│ - helloworld.py: 测试程序                                │
│ - functions.py: 通用函数                                 │
│ - 依赖: ffmpeg, ffmpeg-python, pillow                   │
└─────────────────────┬───────────────────────────────────┘
                      │
                      │ 使用 (依赖墨水屏驱动)
                      ▼
    ┌─────────────────────────────────────────────────────┐
    │ 墨水屏驱动层 (二选一)                                 │
    ├─────────────────────────────────────────────────────┤
    │                                                       │
    │ 方案A: IT8951 (微雪高清屏专用)                        │
    │   - 适用于: 6inch HD e-Paper HAT                     │
    │   - 目录: IT8951/                                    │
    │   - 依赖: rpi-lgpio, pillow                          │
    │   - 特点: 自己合并的驱动，支持高清屏                   │
    │                                                       │
    │ 方案B: Omni-EPD (原项目，通用驱动)                    │
    │   - 适用于: 多种墨水屏 (Waveshare, Inky 等)          │
    │   - 来源: https://github.com/robweber/omni-epd       │
    │   - 特点: 统一接口，支持多种显示器                     │
    │                                                       │
    └─────────────────────────────────────────────────────┘
```

## 当前项目状态

### Fork 历史
- **原项目**: TomWhitwell/SlowMovie (已不维护)
  - 使用 `omni-epd` 统一驱动
  - 支持多种常规墨水屏

- **当前项目**: TwinsenLiang/SlowMovie
  - Fork 自 TomWhitwell/SlowMovie v0.2
  - **特殊修改**: 添加了 IT8951 高清屏支持
  - 原因: 微雪 6 寸高清屏使用 IT8951 控制器，原项目不支持

### 依赖关系梳理

#### SlowMovie 核心依赖（项目根目录）
```
ffmpeg (系统包)      ← 视频帧提取
ffmpeg-python       ← Python FFmpeg 接口
pillow              ← 图像处理
```

#### IT8951 驱动依赖（IT8951/ 子目录）
```
rpi-lgpio           ← GPIO 控制 (替代 RPi.GPIO)
pillow              ← 图像处理
spidev (系统)       ← SPI 通信
```

**关键发现**:
- ✅ ffmpeg 应该在项目根级别，不应该在 IT8951/requirements.txt
- ✅ IT8951 是墨水屏驱动，与视频处理无关
- ❌ 当前 IT8951/requirements.txt 包含 ffmpeg-python 是错误的

## 正确的依赖结构

### 方案一：当前结构（使用 IT8951）

```
SlowMovie/
├── requirements.txt          # 主程序依赖
│   ├── ffmpeg-python
│   ├── pillow
│   └── (其他核心依赖)
│
├── IT8951/
│   ├── requirements.txt      # IT8951 驱动依赖
│   │   ├── rpi-lgpio
│   │   └── pillow
│   └── setup.py              # IT8951 安装脚本
│
└── venv/                     # 虚拟环境（项目根目录）
```

### 方案二：原项目结构（使用 omni-epd）

```
SlowMovie/
├── requirements.txt          # 所有依赖
│   ├── ffmpeg-python
│   ├── pillow
│   ├── ConfigArgParse
│   └── omni-epd
│
└── venv/                     # 虚拟环境
```

## 远程生产环境分析

### 当前配置
```
SlowMovie/
├── IT8951/
│   └── venv/                # 虚拟环境在这里！
│       └── (所有包都安装在这里)
│
├── run_slowmovie.sh         # 启动脚本
└── run_helloworld.sh        # 测试脚本
```

### 问题
1. ⚠️ 虚拟环境位置在 `IT8951/venv/` 而不是根目录
2. ⚠️ 所有包（包括 ffmpeg-python）都安装在 IT8951 的 venv 中
3. ⚠️ IT8951/requirements.txt 包含了不属于它的依赖

### 原因分析
可能是按照以下流程安装的：
1. `cd IT8951`
2. `python3 -m venv venv`
3. `pip install -r requirements.txt`（当时 requirements.txt 包含所有依赖）
4. `pip install ./`（安装 IT8951）
5. 所有东西都装在这个 venv 里了

## 推荐的目录结构重构

### 目标结构
```
SlowMovie/
├── venv/                        # 主虚拟环境（根目录）
│
├── requirements.txt             # 主程序依赖
│   ├── pillow>=10.0            # 图像处理
│   └── ffmpeg-python           # 视频处理
│
├── slowmovie.py                 # 主程序
├── helloworld.py                # 测试程序
├── functions.py                 # 通用函数
│
├── run_slowmovie.sh             # 启动脚本
├── run_helloworld.sh            # 测试脚本
│
└── IT8951/                      # IT8951 驱动子模块
    ├── requirements.txt         # 仅驱动依赖
    │   ├── rpi-lgpio           # GPIO 库
    │   └── pillow              # 图像处理（驱动层需要）
    └── setup.py                 # 驱动安装脚本
```

### 安装流程
```bash
# 1. 在根目录创建虚拟环境
cd ~/SlowMovie
python3 -m venv venv
source venv/bin/activate

# 2. 安装系统依赖
sudo apt install ffmpeg

# 3. 安装 SlowMovie 依赖
pip install -r requirements.txt

# 4. 安装 IT8951 驱动
cd IT8951
pip install -r requirements.txt
pip install ./
cd ..
```

## 兼容性考虑

### 如果保持当前远程结构（IT8951/venv）
**优点**:
- 不需要迁移远程环境
- 当前能运行

**缺点**:
- 架构不清晰
- 依赖关系混乱
- 不符合最佳实践

### 如果重构为标准结构（根目录 venv）
**优点**:
- 架构清晰
- 依赖分离明确
- 符合 Python 最佳实践
- 方便未来支持 omni-epd

**缺点**:
- 需要重新部署远程环境

## 建议方案

### 短期（立即执行）
1. 修正 `IT8951/requirements.txt`，移除 `ffmpeg-python`
2. 创建根目录的 `requirements.txt`
3. 文档说明当前两种安装方式：
   - 标准方式：根目录 venv
   - 兼容方式：IT8951/venv（远程环境）

### 中期（下次部署）
1. 在远程创建根目录的 venv
2. 迁移包
3. 更新启动脚本

### 长期（考虑）
1. 研究 omni-epd
2. 考虑支持多种墨水屏
3. 合并原项目的改进

## 与原项目的差异

| 特性 | TomWhitwell/SlowMovie | TwinsenLiang/SlowMovie |
|------|----------------------|------------------------|
| 墨水屏驱动 | omni-epd | IT8951 |
| 支持的屏幕 | 多种常规屏 | 微雪高清屏 |
| 配置方式 | ConfigArgParse | argparse |
| 维护状态 | 已停止 | 活跃 |
| Python 版本 | 3.7+ | 3.9+ |

## 下一步行动

1. ✅ 理清架构（本文档）
2. ⏳ 创建正确的 requirements.txt 结构
3. ⏳ 更新 README 说明两种安装方式
4. ⏳ 决定是否迁移远程环境
5. ⏳ 研究是否合并 omni-epd 支持
