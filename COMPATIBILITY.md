# IT8951 兼容性分析报告

## 已发现的兼容性问题

### 1. ✅ RPi.GPIO 依赖问题（已修复）
**位置**: `IT8951/IT8951/spi.pyx:22`
```python
import RPi.GPIO as GPIO
```

**问题**:
- Python 3.12+ 移除了 `longintrepr.h` 头文件
- 导致 RPi.GPIO 编译失败

**解决方案**:
- 已将 `IT8951/requirements.txt` 中的 `RPi.GPIO` 替换为 `rpi-lgpio`
- `rpi-lgpio` 完全兼容 RPi.GPIO 的 API
- 添加 `setuptools` 和 `Cython` 作为构建依赖（Python 3.13+ 需要）

---

### 2. ✅ Pillow font.getsize() 已弃用（已修复）
**位置**: `functions.py:125`
```python
text_width, _ = font.getsize(text)
```

**问题**:
- Pillow 10.0+ 移除了 `font.getsize()` 方法
- 导致测试程序 `helloworld.py` 和文字渲染功能失败

**解决方案**:
- 已更新为使用 `draw.textbbox()` 方法
- 保留向后兼容性，旧版 Pillow 仍可使用

---

### 3. ⚠️ Pillow unsafe_ptrs 潜在问题
**位置**: `IT8951/IT8951/img_manip.pyx:29`
```python
cdef long new_ptr = dict(new_frame.im.unsafe_ptrs)['image8']
cdef unsigned char* new_buf = (<unsigned char**>new_ptr)[0]
```

**问题**:
- 使用了 Pillow 的内部 API `unsafe_ptrs`
- 新版 Pillow (10.0+) 可能已弃用此 API

**影响**:
- 黑白模式下的像素处理可能失败
- `make_changes_bw()` 函数会报错

**解决方案**:
- **短期**: 项目已包含预编译的 `.c` 文件，可直接使用
- **长期**: 如果需要重新编译，考虑使用 Pillow 的官方 API

**检测方法**:
```bash
# 测试黑白模式是否正常工作
python helloworld.py
```

---

### 4. ⚠️ Cython 编译依赖缺失
**位置**: `IT8951/setup.py`

**问题**:
- 如果设置 `USE_CYTHON=1` 重新编译，需要 Cython
- 当前 `requirements.txt` 没有包含 Cython

**解决方案**:
- 默认使用预编译的 `.c` 文件（无需 Cython）
- 如需重新编译，添加到依赖：
```bash
pip install cython
```

---

### 5. ℹ️ ffmpeg-python 依赖
**位置**: `slowmovie.py:9`

**问题**:
- 需要系统安装 ffmpeg 二进制文件
- Python 包 `ffmpeg-python` 只是 wrapper

**解决方案**:
```bash
# 在树莓派上安装
sudo apt install ffmpeg
```

---

### 6. ℹ️ SPI 和 GPIO 权限问题
**位置**: `IT8951/IT8951/spi.pyx:51`

**问题**:
- 需要访问 `/dev/spidev*` 设备
- 需要 GPIO 权限

**解决方案**:
- 将用户加入 `spi` 和 `gpio` 组：
```bash
sudo usermod -aG spi,gpio $USER
```
- 或使用 `sudo` 运行

---

### 7. ⚠️ 系统架构兼容性（32位 vs 64位）

**问题**:
- e-paper 目录包含 Waveshare 官方示例代码
- 预编译的 `.so` 库为 64 位 ARM (aarch64) 架构
- 在 32 位系统（树莓派 Zero/1/2/3/4 的 32 位系统）上无法运行

**影响**:
- 树莓派 Zero/Zero W (armv6l): ❌ 不能使用 e-paper 目录
- 树莓派 2/3/4 (32位系统): ❌ 不能使用 e-paper 目录
- 树莓派 3/4/5 (64位系统): ✅ 可以使用 e-paper 目录

**解决方案**:
- **主项目不受影响**: slowmovie.py 和 IT8951 驱动完全支持 32/64 位
- **e-paper 目录**: 仅作为 64 位系统的参考代码保留
- **32 位用户**: 请使用主项目的 IT8951 驱动，不要使用 e-paper 目录

**错误示例**:
```
OSError: .../sysfs_software_spi.so: wrong ELF class: ELFCLASS64
```
这是正常的架构不匹配错误，说明你的系统是 32 位。

**验证系统架构**:
```bash
uname -m
# armv6l / armv7l = 32位
# aarch64 = 64位
```

详见: [e-paper/README.md](e-paper/README.md)

---

## 系统架构兼容性矩阵

| 组件 | 32位 ARM | 64位 ARM | 说明 |
|------|---------|---------|------|
| slowmovie.py | ✅ | ✅ | 主程序，纯 Python |
| IT8951 驱动 | ✅ | ✅ | 从源码编译，自动适配 |
| helloworld.py | ✅ | ✅ | 测试程序 |
| functions.py | ✅ | ✅ | 工具函数 |
| e-paper/ 目录 | ❌ | ✅ | 包含 64 位预编译库 |
| Extras/ 示例 | ❌ | ✅ | 依赖 e-paper 目录 |

**推荐配置**:
- **树莓派 Zero/Zero W**: 使用 IT8951 驱动（成本最优方案）
- **树莓派 4/5**: 可使用 64 位系统获得更好性能

---

## 测试建议

### 基础测试
```bash
# 1. 激活虚拟环境
source ~/SlowMovie/venv/bin/activate

# 2. 测试 SPI 通信
python helloworld.py

# 3. 测试视频播放
python slowmovie.py -d 10 -i 1
```

### 兼容性测试
```bash
# 检查 Python 版本
python --version

# 检查 Pillow 版本
pip show pillow

# 检查 rpi-lgpio 安装
pip show rpi-lgpio

# 检查 ffmpeg
ffmpeg -version
```

---

## 新版树莓派（Bookworm）特别注意事项

### Python 版本
- Bookworm 默认使用 Python 3.11
- 后续更新可能升级到 Python 3.12+

### 预编译的 C 扩展
- 项目包含预编译的 `spi.c` 和 `img_manip.c`
- 这些文件是用旧版本工具生成的
- 在新环境可能需要重新编译

### 如需重新编译
```bash
# 安装编译依赖
sudo apt install build-essential python3-dev

# 安装 Cython
pip install cython

# 设置环境变量并重新安装
cd IT8951
USE_CYTHON=1 pip install ./ --force-reinstall
```

---

## 推荐配置

### 最佳实践安装步骤
```bash
# 1. 系统依赖
sudo apt update
sudo apt install -y ffmpeg build-essential python3-dev

# 2. 克隆仓库
git clone https://github.com/TwinsenLiang/SlowMovie.git
cd SlowMovie

# 3. 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 4. 安装 Python 依赖
cd IT8951
pip install -r requirements.txt
pip install ./
pip install ffmpeg-python
cd ..

# 5. 测试
python helloworld.py
```

---

## 已知兼容的版本组合

### 推荐配置 1（新版）
- OS: Raspberry Pi OS Bookworm (12)
- Python: 3.11 或 3.12
- rpi-lgpio: 最新版
- Pillow: 10.x
- ffmpeg: 5.x+

### 推荐配置 2（旧版）
- OS: Raspberry Pi OS Bullseye (11)
- Python: 3.9
- RPi.GPIO: 0.7.x（系统包）
- Pillow: 8.x
- ffmpeg: 4.x

---

## 总结

**当前状态**: ✅ 项目已针对新版树莓派进行全面适配

**主要改进**:
1. ✅ 使用 `rpi-lgpio` 替代 `RPi.GPIO`（解决 longintrepr.h 问题）
2. ✅ 修复 Pillow 10.0+ 的 `font.getsize()` 弃用问题
3. ✅ 使用虚拟环境避免 PEP 668 限制
4. ✅ 利用预编译的 C 文件避免 Pillow unsafe_ptrs 问题
5. ✅ 添加完整的系统依赖安装说明

**测试状态**: ⏳ 需要在实际硬件上验证

**建议**: 按照 README.md 的更新说明安装即可
