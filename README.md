# 三国志11 加强版 — macOS + CrossOver 完整排查与解决方案

macOS 上运行《三国志11 加强版》(San11PK) 的完整排查记录，覆盖**三个独立阶段**的问题：
**能不能跑起来**（脱壳 + 分辨率写死 + 区域设置）→ **旗帜为什么白**（顶点色通道）→
**为什么卡**（渲染后端架构差异）。

---

## 问题现象

### 第一阶段：完全跑不起来

| 环境 | 现象 |
|---|---|
| winxp bottle | `Unhandled illegal instruction`，崩溃地址 `0x00DE164E` |
| win98 bottle | 无任何报错，静默退出无窗口 |
| winedbg 下 | `Exception c0000005`（访问冲突） |

### 第二阶段：能跑了，但 3D 大地图旗帜恒白

| 对象 | 期望 | 实际 |
|---|---|---|
| 3D 大吊旗（大地图城池旗帜） | 势力色 | **纯白** |
| 城墙小旗（2D 贴图） | 势力色 | 正常 ✅ |

### 第三阶段：旗帜对了，但界面卡

- 招人界面等大量 2D UI 操作时"一卡一卡"（顿挫，非整体掉帧）
- 大地图约 95 FPS，标题画面 120 FPS 但帧时间波动达 3 倍（7.6–23.5 ms）

---

## 根因

### 1. SafeDisc 光驱保护壳（导致崩溃）

`san11pk.exe` 带 SafeDisc 壳，检测依赖 `secdrv.sys` **Windows 内核驱动** ——
**Wine/CrossOver 无法加载内核驱动**，所以直接崩或静默退出。

判据（PE 节区）：`.data` 虚拟 148MB / 磁盘仅 280KB + `stxt774`/`stxt371` 壳节区
+ 导入表 `CActiveImage@Sdt@Mvsn`（Mvsn=Macrovision）。

**解决**：换用**脱壳版** `san11pk.exe`（ali213 脱壳补丁，159,920,128 B）。
脱壳后所有节区磁盘大小 == 虚拟大小，运行时不再解压、不再执行 SafeDisc 检测。

### 2. 分辨率写死在代码里（导致 D3D 初始化失败）

winedbg 逆向出过滤条件为 **`Width >= 1024 && Height >= 768`**，
而 macOS 枚举出的 132 个模式**全是 Retina 缩放分辨率，没有 1024x768**（Apple 已移除 4:3）
→ 模式表为空 → 设备创建失败 → 弹「DirectX版本过低」（误导性报错）。

**解决**：改**注册表** `HKCU\Software\KOEI\San11PK Tc\San11Option\DisplayMode 0`
的模式索引 `22 → 35`（命中枚举表里的 1280x800）。

> ⚠️ 常见误解：网上说的「改 1024x768」容易被当成改 exe 常量。
> 实测 exe 中 `(1024,768)` 相邻常量对仍有 10 处、`(1280,800)` 一处都没有 —— **exe 没被改过**。

### 3. 区域设置不对（导致界面乱码）

游戏是繁中版，需 bottle 设 `Locale=00000404` / `sLanguage=CHT` / ACP 950（Big5），
并在启动脚本导出 `zh_TW.UTF-8`。

### 4. 旗帜白：wined3d 的固定管线顶点色缺陷

Wine 内置 `wined3d` 处理 D3D9 固定管线顶点色有缺陷 → 3D 大吊旗丢失势力色。
**与 Wine 版本无关**（9.0 / 10.0 / 11.21 全部复现），升级 Wine 无效。

### 5. 卡顿：Rosetta 转译的是哪一层

```
旗帜纯白（流畅）链路：
  i386-windows/d3d9.dll (builtin wined3d)
  → x86_64-unix/opengl32.so        (x86_64, 641KB 薄转发层)
  → AppleMetalOpenGLRenderer       ★ arm64 原生扩展（真正干活的是它）
  → Metal

旗帜正确（顿挫）链路：
  system32/d3d9.dll (DXVK 1.10.1 x32)
  → winevulkan.so                  (x86_64)
  → libMoltenVK.dylib              (x86_64, 6.4MB 完整 Vulkan 栈) ★ 全程 Rosetta
  → Metal
```

**差异不在「有没有 Rosetta」，而在 Rosetta 转译的是哪一层。**

实测 `sample` 对比（同一游戏、同一场景）：

| 采样对象 | AppleMetalOpenGLRenderer | libMoltenVK | vkWaitForFences |
|---|---|---|---|
| wined3d 路径 | **54 次** | 1 | **0** |
| DXVK 路径 | 0 | 45 | **200** |

DXVK 路径 CPU 有 **62% 时间阻塞在等 GPU fence**。叠加 DXVK 1.10.1
**无异步管线编译**（本地 5 个版本 strings 全查，async 零命中），
UI 界面状态组合多时触发同步着色器编译 → 顿挫。

---

## 解决方案：两套启动命令，按需切换

关键：`--dll d3d9=b` 会**忽略** `system32/d3d9.dll` 里的 DXVK，
所以两方案零成本来回切换，**不需要替换任何文件**。

### 方案一：旗帜正确（DXVK 1.10.1 → Vulkan → MoltenVK）

```bash
cd /Users/w.fish/wine_soft/san11pk && \
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle san11 --dll d3d9=n ./san11pk.exe
```

或双击 `启动三国志11.command`（自动校验并部署 DXVK，sha256 精确匹配）。

### 方案二：运行高效（builtin wined3d → OpenGL）

```bash
cd /Users/w.fish/wine_soft/san11pk && \
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle san11 --dll d3d9=b ./san11pk.exe
```

或双击 `启动三国志11-高效模式.command`。

> ⚠️ 方案二的 3D 大吊旗会显示纯白，这是 wined3d 的固有限制，无法通过配置绕过。

---

## 文件清单

| 文件 | 说明 |
|---|---|
| `docs/三国志11_macOS_渲染问题排查与解决方案.md` | 完整排查文档（三阶段 / 现象 / 根因 / 排除清单 / 方案 / 命令 / 踩坑清单） |
| `启动三国志11.command` | 方案一启动器（DXVK 1.10.1 → 旗帜正常） |
| `启动三国志11-高效模式.command` | 方案二启动器（builtin wined3d → 运行流畅） |
| `dxvk.conf` | DXVK 调优配置（放游戏目录，DXVK 自动读取） |

---

## 环境

- macOS 27.2.1 / Apple M2 Pro
- CrossOver 24.0.5（x86_64，Rosetta 下运行）
- bottle `san11`（32 位，zh-TW / ACP 950）
- DXVK 1.10.1 (x32) + CrossOver 定制 MoltenVK 1.2.5

> ⚠️ 本仓库仅包含排查文档与启动脚本，**不含任何游戏程序或资源文件**。
