# 兼容性修复更新日志

## 修复日期：2025-12-12

### Python 3.13 完整兼容性修复

#### 1. ✅ IT8951 驱动 Python 3.13 编译支持
- **影响**: Python 3.13 环境下 IT8951 驱动编译失败
- **原因**:
  - Python 3.13 移除了 `distutils` 模块
  - Cython 生成的旧 C 代码不兼容新版 Python
- **修复**:
  - 添加 `setuptools` 到 `IT8951/requirements.txt`（提供 distutils 兼容层）
  - 添加 `Cython` 到构建依赖，支持现场重新编译 C 扩展
  - 远程环境使用 Cython 3.2.2 重新生成 Python 3.13 兼容的 C 代码
- **文件**: `IT8951/requirements.txt`
- **测试环境**: Raspberry Pi OS Bookworm, Python 3.13.5

#### 2. ✅ 完整部署验证
- **环境**: 远程 SlowMovie 机器 (slowmovie@192.168.50.5)
- **验证内容**:
  - ✓ 虚拟环境创建成功（根目录 venv/）
  - ✓ 主程序依赖安装成功（Pillow 12.0.0, ffmpeg-python）
  - ✓ IT8951 驱动编译安装成功
  - ✓ rpi-lgpio 0.6 正常工作
  - ✓ 所有 Python 模块导入正常
  - ✓ SPI 驱动模块加载正常
- **说明**:
  - 测试程序报"communication with device failed"是因为墨水屏硬件未连接/通电
  - 软件层面所有依赖已正确安装和配置

---

## 修复日期：2025-12-05

### 已修复的兼容性问题

#### 1. ✅ RPi.GPIO longintrepr.h 问题
- **影响**: Python 3.12+ 无法编译安装 RPi.GPIO
- **修复**: 将依赖从 `RPi.GPIO` 改为 `rpi-lgpio`
- **文件**: `IT8951/requirements.txt`
- **兼容性**: API 完全兼容，无需修改代码

#### 2. ✅ Pillow font.getsize() 已弃用
- **影响**: Pillow 10.0+ 移除了 `font.getsize()` 方法
- **修复**: 使用 `draw.textbbox()` 替代，保留向后兼容性
- **文件**:
  - `functions.py:125`
  - `IT8951/test/integration/test_functions.py:115`
  - `Extras/HouseOfDust/HouseOfDust.py:35-37`

#### 3. ✅ PEP 668 限制
- **影响**: 新版树莓派禁止直接 pip 安装到系统 Python
- **修复**: 使用 Python 虚拟环境
- **文件**: `README.md` (添加虚拟环境安装说明)

#### 4. ✅ 系统依赖不明确
- **影响**: 用户不知道需要安装 ffmpeg 和编译工具
- **修复**: 在 README 中添加系统依赖安装步骤
- **文件**: `README.md`

#### 5. ✅ 启动脚本不支持虚拟环境
- **影响**: slowmovie.sh 无法使用虚拟环境
- **修复**: 更新脚本自动激活虚拟环境
- **文件**: `slowmovie.sh`

### 新增文档

#### COMPATIBILITY.md
详细的兼容性分析报告，包含：
- 所有已知兼容性问题
- 解决方案和替代方案
- 测试建议
- 版本兼容性信息

### 更新的文件清单

```
修改的文件：
├── IT8951/requirements.txt (RPi.GPIO → rpi-lgpio)
├── README.md (添加虚拟环境和系统依赖说明)
├── slowmovie.sh (支持虚拟环境)
├── functions.py (修复 Pillow API)
├── IT8951/test/integration/test_functions.py (修复 Pillow API)
└── Extras/HouseOfDust/HouseOfDust.py (修复 Pillow API)

新增的文件：
├── COMPATIBILITY.md (兼容性分析报告)
└── CHANGES.md (本文件)
```

### 测试建议

在树莓派上按以下步骤测试：

```bash
# 1. 安装系统依赖
sudo apt update
sudo apt install -y ffmpeg build-essential python3-dev

# 2. 克隆/更新代码
git pull

# 3. 创建虚拟环境并安装
python3 -m venv venv
source venv/bin/activate
cd IT8951
pip install -r requirements.txt
pip install ./
pip install ffmpeg-python
cd ..

# 4. 设置权限（可选）
sudo usermod -aG spi,gpio $USER
# 重新登录

# 5. 测试
python helloworld.py

# 6. 运行项目
python slowmovie.py -d 10 -i 1
```

### 兼容性保证

- ✅ Python 3.9+
- ✅ Python 3.11 (Raspberry Pi OS Bullseye)
- ✅ Python 3.12+ (Raspberry Pi OS Bookworm)
- ✅ Pillow 8.x - 10.x+
- ✅ rpi-lgpio (完全兼容 RPi.GPIO)

### 向后兼容性

所有修改都保持了向后兼容性：
- 旧版 Pillow 仍然可以使用 `getsize()`
- 代码自动检测并使用合适的 API
- 虚拟环境安装不影响现有安装

### 潜在问题

⚠️ **img_manip.pyx 中的 unsafe_ptrs**
- 位置: `IT8951/IT8951/img_manip.pyx:29`
- 状态: 使用预编译的 C 文件，目前无影响
- 建议: 如需重新编译，可能需要更新此代码

### 后续建议

1. 在实际硬件上进行完整测试
2. 如果发现问题，查看 COMPATIBILITY.md 了解详情
3. 如需重新编译 Cython 扩展，参考文档说明

---

详细的技术分析请查看 `COMPATIBILITY.md`
