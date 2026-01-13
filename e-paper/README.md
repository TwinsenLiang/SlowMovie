# Waveshare e-Paper 官方示例代码

⚠️ **重要架构兼容性说明**

## 架构兼容性

此目录包含 Waveshare 官方的 e-Paper 示例代码，但**预编译的 .so 库文件为 64 位 ARM (aarch64) 架构**。

### 兼容性矩阵

| 树莓派型号 | 系统架构 | 此目录是否可用 | 推荐使用 |
|-----------|---------|--------------|---------|
| 树莓派 Zero / Zero W | 32位 (armv6l) | ❌ 不兼容 | IT8951 驱动 |
| 树莓派 1 | 32位 (armv6l) | ❌ 不兼容 | IT8951 驱动 |
| 树莓派 2/3/4 (32位系统) | 32位 (armv7l/armhf) | ❌ 不兼容 | IT8951 驱动 |
| 树莓派 3/4/5 (64位系统) | 64位 (aarch64) | ✅ 兼容 | 两者皆可 |
| Jetson Nano | 64位 (aarch64) | ✅ 兼容 | 两者皆可 |

### 检查你的系统架构

```bash
uname -m
```

- `armv6l` 或 `armv7l` 或 `armhf` = 32位系统 → **不能使用此目录**
- `aarch64` = 64位系统 → 可以使用此目录

## 32位系统用户请使用 IT8951 驱动

SlowMovie 项目的核心驱动 **IT8951** 完全兼容 32位和 64位系统。

### 使用方法

```python
from IT8951.display import AutoEPDDisplay

# 初始化墨水屏
display = AutoEPDDisplay(vcom=-2.36)

# 显示图片
display.frame_buf.paste(image)
display.draw_full(constants.DisplayModes.GC16)
```

详见主项目的 `helloworld.py` 和 `slowmovie.py` 示例。

## 为什么保留此目录？

此目录作为参考代码保留，供 64 位系统用户使用 Waveshare 官方驱动。但 SlowMovie 项目推荐统一使用 IT8951 驱动以确保跨架构兼容性。

## 在 32 位系统上的错误示例

如果在 32 位系统上尝试运行此目录的代码，会看到类似错误：

```
OSError: .../sysfs_software_spi.so: wrong ELF class: ELFCLASS64
```

这是正常的，说明你的系统是 32 位，不支持此目录的预编译库。请使用主项目的 IT8951 驱动。

## 相关资源

- Waveshare 官方仓库: https://github.com/waveshare/IT8951-ePaper
- IT8951 驱动文档: ../IT8951/README.md
- 主项目使用说明: ../README.md
