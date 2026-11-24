# 三国志11 加强版 — macOS + CrossOver 渲染问题排查与解决文档

> 文档日期：2026-11-24
> 游戏版本：三國志11 威力加強版（San11PK，主程序 `san11pk.exe`，32 位 PE）
> 运行环境：macOS 27.2.1（Apple M2 Pro，arm64） + CrossOver 24.0.5（**x86_64 版**）
> Bottle：`san11`（32 位前缀，zh-TW / ACP 950 / Big5）

---

## 一、问题现象

### 1.1 主问题：3D 大地图旗帜恒白

在 CrossOver 下运行游戏时，**大地图上悬挂的 3D 大吊旗颜色错误**：

| 对象 | 期望 | 实际 |
|---|---|---|
| 3D 大吊旗（大地图城池旗帜） | 势力色（濮阳=明黄等） | **纯白** |
| 城墙小旗（2D 贴图） | 势力色 | 正常 ✅ |

关键判别特征：**同一张放大截图里，城墙小旗橙金正常，只有 3D 大吊旗纯白**。
这一条直接把问题精确定位到**顶点色（vertex color）通道**，而不是贴图、势力色数据或调色板。

### 1.2 次问题：修复旗帜后出现界面卡顿

强制走 DXVK 后旗帜颜色恢复正常，但用户反馈：

> 「这么修复好了后只能说勉强运行，在招人界面等很多地方都会一卡一卡的」

具体表现：

- 招人界面（以及大量 2D UI 界面）操作时**一卡一卡**，不是整体掉帧而是**顿挫**
- 大地图 3D 场景相对流畅（约 95 FPS）
- 标题画面 120 FPS，帧时间 min 7.6 ms / **max 23.5 ms**（波动达 3 倍）

### 1.3 早期误判（已推翻，保留备查）

排查过程中曾出现过"改了色号 54 → 旗帜仍白"的弯路。实际原因是：

- **色号 54 = 贼**，正确应为 **41（明黄 160,160,0）**
- 更重要的是：**游戏会按画质档（GraphicsQuality）自动切换简化渲染路径**，
  低画质下根本不传顶点色 → 换任何色号都没用。这是排查干扰项。

---

## 二、根因分析

### 2.1 白旗根因：wined3d 的 D3D9 固定管线顶点色缺陷

**这是本次排查最核心的结论。**

游戏走 D3D9 固定管线（FPP），势力色通过**顶点色**传给显卡。Wine 内置的
`wined3d` 在处理 FPP 顶点色通道时存在缺陷，导致颜色被丢弃 → 旗帜纯白。

**该缺陷与 Wine 版本无关，是长期存在的系统性问题：**

| Wine 版本 | 引擎来源 | 3D 大吊旗 | 城墙小旗 |
|---|---|---|---|
| 9.0（Wine 11 / CrossOver 24.0.5） | builtin wined3d | **纯白 ❌** | 橙金 ✅ |
| 10.0 | Kegworks / Winery | **纯白 ❌** | 橙金 ✅ |
| 11.21 staging | Gcenx osx64 | **纯白 ❌** | 橙金 ✅ |

⇒ **升级 Wine 无法解决白旗问题。**

#### ⚠️ 排查过程中一个致命陷阱（导致早期所有对照实验作废）

CrossOver 的全局 `DllOverrides` 表里有 `d3d10` / `d3d11` / `d3d10core` = `native,builtin`，
**唯独没有 `d3d9`** → Wine 对 `d3d9` **一律走 builtin（wined3d）**。

`lsof` 硬证据：早前所有"DXVK vs wined3d"对照实验中，游戏进程加载的都是
`lib/wine/i386-windows/d3d9.dll`（wined3d），**bottle 里的 DXVK 从未被加载过**。

⇒ 早期"DXVK 1.10.3 和 wined3d 都白旗"的结论**完全无效**，已推翻。
⇒ 修正方法：必须用 `--dll d3d9=n` 强制 native 覆盖。

### 2.2 卡顿根因：DXVK 路径整条链路跑在 Rosetta 2 转译下

这是**「旗帜正确」与「运行流畅」在当前环境下不可兼得**的根本原因。

#### 两条链路的实测对比（`lsof` + `sample` 硬证据）

```
【白旗链路 · wined3d】
san11pk.exe (i386)
  → lib/wine/i386-windows/d3d9.dll      (wined3d, PE32)
  → lib/wine/i386-windows/opengl32.dll  (wined3d 的 GL 后端)
  → lib/wine/x86_64-unix/opengl32.so    (x86_64, 641 KB)
  → AppleMetalOpenGLRenderer            ★ arm64 原生！
  → Metal → GPU

【当前链路 · DXVK】
san11pk.exe (i386)
  → bottle system32/d3d9.dll            (DXVK 1.10.1 x32, PE32)
  → winevulkan.so                       (x86_64)
  → libMoltenVK.dylib                   (x86_64, 6.4 MB) ★ Rosetta 转译
  → Metal → GPU
```

**`sample` 采样对比（同一游戏、同一场景）：**

| 采样对象 | `AppleMetalOpenGLRenderer`（arm64 原生） | `libMoltenVK`（x86_64/Rosetta） | `vkWaitForFences` |
|---|---|---|---|
| **wined3d 路径** | **54 次命中** | 1 次（仅二进制映射表） | **0 次** |
| **DXVK 路径** | 0 次 | 45 次 | **200 次** |

栈样本证据（DXVK 路径，`dxvk-queue` 线程）：

```
+ 345 NtWaitForAlertByThreadId (in ntdll.so)
+   207 __wine_unix_call_dispatcher (in ntdll.so)
+     200 vkWaitForFences (in libMoltenVK.dylib)
```

⇒ **DXVK 路径下 CPU 有 62% 的时间阻塞在等 GPU fence**，而 wined3d 路径 0 次。

#### 关键差异归纳

| 维度 | wined3d（白旗但流畅） | DXVK（旗帜正确但卡） |
|---|---|---|
| 渲染后端 | OpenGL → **arm64 原生** `AppleMetalOpenGLRenderer` | Vulkan → **x86_64** `libMoltenVK`（Rosetta 转译） |
| 转译层体量 | 641 KB 薄转发层 | **6.4 MB** 完整 Vulkan 实现，逐调用转译 |
| CPU 阻塞 | `vkWaitForFences` **0 次** | **200 次**（等 fence） |
| FPP 顶点色 | ❌ 缺陷 → 旗帜白 | ✅ 正确 |
| 管线编译 | OpenGL 状态机，动态 | 着色器管线，**同步编译** |

#### 补充：DXVK 1.10.1 无异步管线编译

`strings` 扫描本地 5 个 DXVK 版本（1.9.2 / 1.10.1 / 1.10.3 / 2.0 / 2.4），
`async` 关键词**全部 0 命中**。⇒ 遇到新着色器变体时**同步编译**，
在 UI 界面（大量新状态组合）切换时产生顿挫。

### 2.3 为什么招人界面这类 UI 特别卡

招人界面是**纯 2D UI**，每帧大量小 draw call、状态切换频繁：

1. **DXVK 每次 draw call 都要经 x86→arm 转译**（Vulkan → MoltenVK → Metal）
2. **32 位进程 → 64 位 winevulkan 的 wow64 IPC**，每 draw call 一次跨进程调用
3. **UI 界面状态组合多 → 触发着色器管线同步编译**（DXVK 1.10.1 无异步编译）
4. 叠加 `numBackBuffers=1` / `maxFrameLatency=1` 的激进配置 → 流水线深度不足，
   偶发帧间阻塞

而大地图 3D 场景 draw call 数量少、单次负载大，摊薄了这些开销，所以相对流畅。

---

## 三、已排除的假设（避免重复劳动）

| # | 假设 | 状态 | 证据 |
|---|---|---|---|
| A | 势力色数据损坏 | ❌ | 2D 路径颜色跟随正确 |
| B | 改色没生效 | ❌ | 字节级确认已写入 |
| C | 色号 41 接近白 | ❌ | 41 = 黄 (160,160,0) |
| D | DXVK d9vk 兼容缺陷 | ❌ **推翻** | 真实 DXVK 下旗帜正常 |
| E | CrossOver cxaddon patch 问题 | ❌ **推翻** | 真凶是 wined3d |
| F | Wine 9.0 的 wined3d 回归 | ✅ **锁定** | wined3d FPP 顶点色缺陷 |
| G | 游戏资源/顶点色缺失 | ❌ | DXVK 下正常 |
| H | GraphicsQuality 画质档 | ❌ | 非因素 |
| I | 换 Wine 版本能解决 | ❌ | 9.0 / 10.0 / 11.21 全部复现 |
| **J** | **DXVK 在本机从未真正加载** | ✅ **推翻所有旧对照结论** | `lsof` 硬证据 |

---

## 四、解决方法

### 4.1 方案一：DXVK 1.10.1（旗帜正确）★ 推荐

**技术栈**：CrossOver 24.0.5 + DXVK 1.10.1 (x32) + CrossOver 定制 MoltenVK 1.2.5 + `dxvk.conf`

| 指标 | 结果 |
|---|---|
| 3D 大吊旗颜色 | ✅ 正常（濮阳明黄 = 势力色 41） |
| 大地图 | ✅ **95 FPS**，帧时间 9.8 ms |
| 标题画面 | ✅ 120 FPS |
| 招人等 UI 界面 | ⚠️ 仍有顿挫（Rosetta 转译固有开销） |

#### 为什么必须用 CrossOver 定制 MoltenVK 1.2.5

**MoltenVK 兼容矩阵（已实测）：**

| MoltenVK 版本 | DXVK 1.9.2 / 1.10.1 | DXVK 1.10.3 / 2.0 / 2.4 |
|---|---|---|
| **CrossOver 定制 1.2.5 (0.2.2013)** | ✅ 可用 | ❌ UBO slot 冲突 |
| 上游 1.2.6 / 1.2.9 / 1.3.0 / 1.4.2 | ❌ feature 错误 | ❌ feature 错误 |

**上游 MoltenVK 两个硬伤（精确错误）：**

```
[mvk-warn] VK_ERROR_FEATURE_NOT_PRESENT: Metal does not support buffer robustness.
[mvk-error] vkCreateDevice(): Requested physical device feature specified by the
            5th flag in VkPhysicalDeviceFeatures is not available on this device.
```

- 第 5 个 flag = **geometryShader**：MoltenVK 1.2.6+ 把 Metal 3 mesh shader
  误报为传统 geometry shader，DXVK 读到 true→请求→创建时拒绝
- **robustBufferAccess**：DXVK 强制要求；上游 MoltenVK 1.3/1.4 明确不支持

⇒ **只有 CodeWeavers 的定制 fork 同时满足两个条件，不可替换为上游版。**

#### 关键：必须用 `--dll d3d9=n`

全局 `DllOverrides` 里没有 `d3d9` 条目 → 不加这个参数，Wine 一律走 builtin wined3d，
**DXVK 根本不会加载**。

#### `dxvk.conf` 说明

位于游戏目录，DXVK 自动读取（路径：`/Users/w.fish/wine_soft/san11pk/dxvk.conf`）。
目标是降低每帧缓冲/同步开销，缓解 wow64 + Rosetta 下的低帧率。

⚠️ **已验证无效的键**（DXVK 1.10.1 中不存在，被静默忽略，但日志仍会回显，
容易造成"已优化"的错觉）：

- `d3d9.cachedDynamicBuffers`
- `d3d9.samplerLodBias`

DXVK 1.10.1 实际支持的 `d3d9.*` 键全集（`strings` 提取核对）：

```
allowDirectBufferMapping  allowDiscard  allowDoNotWait  alphaTestWiggleRoom
apitraceMode  customDeviceDesc  customDeviceId  customVendorId
deferSurfaceCreation  deviceLocalConstantBuffers  dpiAware  enableDialogMode
enumerateByDisplays  evictManagedOnUnlock  floatEmulation  forceAspectRatio
forceSamplerTypeSpecConstants  forceSwapchainMSAA  generalHazards
invariantPosition  lenientClear  longMad  maxAvailableMemory  maxFrameLatency
maxFrameRate  memoryTrackTest  noExplicitFrontBuffer  numBackBuffers
presentInterval  samplerAnisotropy  shaderModel  strictConstantCopies
strictPow  supportDFFormats  supportVCache  supportX4R4G4B4  tearFree
```

> **注意**：DXVK 1.10+ 统一使用 `d3d9.` 前缀；`dxvk.` / 无前缀为 1.6- 旧式写法。

### 4.2 方案二：wined3d（运行效率高）★ 流畅优先时选

**技术栈**：CrossOver 24.0.5 + builtin wined3d（`--dll d3d9=b`）

| 指标 | 结果 |
|---|---|
| 3D 大吊旗颜色 | ❌ **纯白**（wined3d FPP 顶点色缺陷） |
| 运行流畅度 | ✅ **最优** — 走 arm64 原生 `AppleMetalOpenGLRenderer`，无 `vkWaitForFences` 阻塞 |
| 招人等 UI 界面 | ✅ 不卡 |

**关键点**：`--dll d3d9=b` 让 Wine 强制用 builtin wined3d，**完全忽略**
bottle `system32/d3d9.dll` 里的 DXVK。因此**两个方案可以随时来回切换，无需替换任何文件**。

### 4.3 两条链路的架构对比总结

```
┌─ 方案一 · DXVK ────────────────────────────────────────────┐
│ san11pk.exe (i386)                                          │
│   └→ system32/d3d9.dll  [DXVK 1.10.1 x32]                   │
│        └→ Vulkan ─→ winevulkan.so (x86_64)                  │
│             └→ libMoltenVK.dylib (x86_64, 6.4MB) ★Rosetta  │
│                  └→ Metal → GPU                             │
│  ✅ 顶点色正确   ⚠️ 每 draw call 转译 + 同步管线编译 + 等 fence│
└─────────────────────────────────────────────────────────────┘

┌─ 方案二 · wined3d ─────────────────────────────────────────┐
│ san11pk.exe (i386)                                          │
│   └→ i386-windows/d3d9.dll [builtin wined3d]                │
│        └→ i386-windows/opengl32.dll                        │
│             └→ opengl32.so (x86_64, 641KB 薄转发)          │
│                  └→ AppleMetalOpenGLRenderer ★arm64 原生   │
│                       └→ Metal → GPU                       │
│  ❌ 顶点色丢失   ✅ 无转译开销、无 fence 阻塞                │
└─────────────────────────────────────────────────────────────┘
```

---

## 五、启动命令

### 5.1 方案一：旗帜颜色正确版（DXVK 1.10.1）

**一行命令（等价于双击 `启动三国志11.command`）：**

```bash
cd /Users/w.fish/wine_soft/san11pk && \
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle san11 --dll d3d9=n ./san11pk.exe
```

**启动脚本**：`/Users/w.fish/wine_soft/san11pk/启动三国志11.command`
（已加固：sha256 精确校验自动部署 DXVK 1.10.1、可选注册表重置、
`DXVK_HUD` 环境变量透传）

**前置条件**（启动脚本会自动完成）：
- bottle `system32/d3d9.dll` = DXVK 1.10.1 x32
  （sha256 `bd4e0b3a91f8a45e4c8ff000238b872043fea9afa7a7ba1d82e3cd18f7d65ff7`）
- `dxvk.conf` 位于游戏目录

**可选环境变量：**

```bash
DXVK_HUD=fps,frametimes,devinfo   # 开启帧率显示
DXVK_LOG_LEVEL=info                # 开启 DXVK 日志
SAN11_RESET_REG=1                  # 启动时重置注册表为基线
```

### 5.2 方案二：运行效率高版（wined3d）

**一行命令：**

```bash
cd /Users/w.fish/wine_soft/san11pk && \
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle san11 --dll d3d9=b ./san11pk.exe
```

> ⚠️ **此方案下 3D 大吊旗会显示纯白**，这是 wined3d 的固有限制，无法通过配置绕过。
> 其余功能（内政、外交、战斗）完全正常。

### 5.3 两条命令对比速查

| | 方案一（旗帜正确） | 方案二（效率高） |
|---|---|---|
| 启动参数 | `--dll d3d9=n` | `--dll d3d9=b` |
| 实际渲染器 | DXVK 1.10.1 → Vulkan → MoltenVK | builtin wined3d → OpenGL |
| 旗帜颜色 | ✅ 正常势力色 | ❌ 纯白 |
| 大地图 | 95 FPS | 更流畅 |
| 招人等 UI | ⚠️ 顿挫 | ✅ 顺畅 |
| 需要换文件 | 否（DXVK 常驻 system32） | 否（`d3d9=b` 直接忽略） |

### 5.4 回滚到 CrossOver 默认渲染

```bash
cp "$HOME/Library/Application Support/CrossOver/Bottles/san11/drive_c/windows/system32/d3d9.dll.orig" \
   "$HOME/Library/Application Support/CrossOver/Bottles/san11/drive_c/windows/system32/d3d9.dll"
# 并去掉启动参数 --dll d3d9=n
```

`d3d9.dll.orig` = CrossOver 自带原始 DXVK
（sha256 `93d3591aba10999b5f53a123566d193b8c153eff520818f91a7f3642be8d739d`）

---

## 六、文件清单

| 路径 | 说明 |
|---|---|
| `/Users/w.fish/wine_soft/san11pk/启动三国志11.command` | 主启动器（方案一） |
| `/Users/w.fish/wine_soft/san11pk/dxvk.conf` | DXVK 调优配置 |
| `/Users/w.fish/wine_soft/san11pk/san11pk.dxvk-cache` | DXVK state cache（自动生成，62 条有效条目） |
| `~/Library/Application Support/CrossOver/Bottles/san11/drive_c/windows/system32/d3d9.dll` | 当前 = DXVK 1.10.1 x32 |
| `~/Library/Application Support/CrossOver/Bottles/san11/drive_c/windows/system32/d3d9.dll.orig` | 回滚用：CrossOver 自带 DXVK |
| `~/.workbuddy/tmp/san11/dxvk/dxvk-1.10.1/x32/d3d9.dll` | DXVK 安装源（5 个版本备查） |
| `~/.workbuddy/tmp/san11/FINDINGS.md` | 完整排查过程记录（50KB+） |
| `~/.workbuddy/tmp/san11/regbak/user.reg` | 注册表基线（zh-TW 正常状态） |
| `~/.workbuddy/tmp/san11/shots_final/` | 验证截图（60 张） |
| `~/.workbuddy/tmp/san11/bottle_d3d9_backups/` | 冗余 d3d9 备份归档 |

---

## 七、后续可选方向（尚未实施）

1. **arm64 原生 CrossOver 26.3.0** —— 唯一能同时摆脱 Rosetta + 拿到新 MoltenVK 的路
   （用户已取消下载，状态待确认）
2. **升级 MoltenVK 到 1.4.2（Vulkan 1.3）+ DXVK 2.x** —— 但仍是 x86_64，
   只能缓解不能根治
3. **A/B/C 三组 `dxvk.conf` 实测**（`numBackBuffers` / `maxFrameLatency` 放开 vs 默认）
   —— 已备好配置，待实测取数
4. **DXVK state cache 命中优化** —— 减少 UI 界面的同步管线编译顿挫

### 本机图形栈架构普查（全部无 arm64 原生）

| 组件 | 路径 | 架构 |
|---|---|---|
| CrossOver 主程序 | `/Applications/CrossOver.app/Contents/MacOS/CrossOver` | **x86_64** |
| CrossOver MoltenVK | `lib64/libMoltenVK.dylib` | **x86_64** |
| CrossOver winevulkan | `lib/wine/x86_64-unix/winevulkan.so` | **x86_64** |
| CrossOver opengl32 | `lib/wine/x86_64-unix/opengl32.so` | **x86_64**（薄转发 → arm64 原生 GL） |
| Kegworks Winery 2.0.4 | — | x86_64 |
| Whisky 2.3.5 主程序 | — | arm64（但引擎 CDN 404） |
| Homebrew `molten-vk` | — | arm64 ✅（但 x86_64 进程无法 dlopen） |

⇒ 想彻底摆脱 Rosetta，需要 arm64 原生 Wine 引擎。

---

## 八、附：排查过程中踩过的坑

### 坑 1：`--dll d3d9=n` 缺一不可
全局 `DllOverrides` 无 `d3d9` 条目 → 不加参数则 DXVK 永不加载，
所有对照实验结论作废（详见 §2.1）。

### 坑 2：色号搞错
54 = 贼；正确的是 **41 = 明黄 (160,160,0)**。

### 坑 3：游戏会按画质档切简化渲染路径
低画质下不传顶点色，改色号无效。

### 坑 4：MoltenVK 不能换成上游版
上游 1.2.6+ 会误报 geometryShader 并移除 robustBufferAccess → `vkCreateDevice` 失败。
只能保留 CrossOver 定制 1.2.5。

### 坑 5：DXVK 配置键会"静默忽略"
`d3d9.cachedDynamicBuffers` / `d3d9.samplerLodBias` 在 1.10.1 中不存在，
但日志的 "Effective configuration" 段仍会回显 → 极易误判为"已生效"。

### 坑 6：Python 的 Quartz 模块不可用
系统 python3 与 anaconda python3 均无 Quartz → 改用纯 ctypes 调 CoreGraphics。

### 坑 7：`CFStringGetCString` 成功时返回 0
不是 true。用 `== 0` 判断成功，否则字符串全取空。

### 坑 8：`CFStringCreateWithCString` 第 3 参是 encoding
传 0（系统默认），UTF8 只在 `CFStringGetCString` 第 4 参指定 `0x08000100`。

### 坑 9：macOS 27 上 OpenGL.framework 符号链接断裂
`/System/Library/Frameworks/OpenGL.framework/OpenGL` → broken symbolic link，
但实际渲染由 `AppleMetalOpenGLRenderer`（arm64 原生扩展）承担。
