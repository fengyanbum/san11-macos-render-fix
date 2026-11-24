# 《三国志11 加强版》在 macOS + CrossOver 下的完整排查与解决方案

> 文档日期：2026-11-24
> 游戏版本：三國志11 威力加強版（San11PK，主程序 `san11pk.exe`，32 位 PE）
> 运行环境：macOS 27.2.1（Apple M2 Pro，arm64） + CrossOver 24.0.5（**x86_64 版**）
> Bottle：`san11`（32 位前缀，zh-TW / ACP 950 / Big5）
>
> 本文档覆盖**三个独立阶段**的问题：
> 第一阶段「能不能跑起来」（脱壳 + 分辨率写死 + 区域设置）、
> 第二阶段「旗帜为什么白」（顶点色通道）、
> 第三阶段「为什么卡」（渲染后端架构差异）。

---

## 目录

- [第一阶段：让游戏能跑起来](#第一阶段让游戏能跑起来)
  - [1.1 现象：直接运行即崩溃](#11-现象直接运行即崩溃)
  - [1.2 根因一：SafeDisc 光驱保护壳](#12-根因一safedisc-光驱保护壳)
  - [1.3 根因二：分辨率写死在代码里](#13-根因二分辨率写死在代码里)
  - [1.4 根因三：区域设置（中文显示）](#14-根因三区域设置中文显示)
  - [1.5 第一阶段的三项修复](#15-第一阶段的三项修复)
- [第二阶段：3D 大地图旗帜恒白](#第二阶段3d-大地图旗帜恒白)
  - [2.1 现象](#21-现象)
  - [2.2 根因：wined3d 的固定管线顶点色缺陷](#22-根因wined3d-的固定管线顶点色缺陷)
  - [2.3 一个致命陷阱：DXVK 从未被真正加载](#23-一个致命陷阱dxvk-从未被真正加载)
- [第三阶段：旗帜对了但界面卡](#第三阶段旗帜对了但界面卡)
  - [3.1 现象](#31-现象)
  - [3.2 两条链路的架构对比](#32-两条链路的架构对比)
  - [3.3 决定性证据：sample 对比](#33-决定性证据sample-对比)
  - [3.4 为什么招人界面这类 UI 特别卡](#34-为什么招人界面这类-ui-特别卡)
- [已排除的假设](#已排除的假设)
- [最终解决方案](#最终解决方案)
- [启动命令](#启动命令)
- [文件清单](#文件清单)
- [后续可选方向](#后续可选方向)
- [附：踩坑清单](#附踩坑清单)

---

# 第一阶段：让游戏能跑起来

## 1.1 现象：直接运行即崩溃

最初的整合包**完全无法在 macOS 上运行**，表现为三种不同的失败：

| 运行环境 | 现象 | 退出码 |
|---|---|---|
| winxp bottle | `Unhandled illegal instruction`，崩溃地址 `0x00DE164E` | 非 0 |
| win98 bottle | **无任何报错**，静默退出无窗口 | 0 |
| winedbg 下 | `Exception c0000005`（访问冲突） | — |
| `S11PKLauncher.exe` | 正常运行 16 秒后正常退出 | 0 |

初判是「显卡/DirectX 问题」，实测后确认是**三个彼此独立的前置问题**。

## 1.2 根因一：SafeDisc 光驱保护壳

### PE 节区实测

`san11pk.exe`（6.6 MB）的节区表：

```
PE magic=010b  sections=6
  .text      VS=0034CF19 RS=0034D000 ptr=00001000
  .rdata     VS=0014E12D RS=0014F000 ptr=0034E000
  .data      VS=093C47E0 RS=00046000 ptr=0049D000   ← 虚拟 148MB / 磁盘仅 280KB
  .rsrc      VS=00019ECE RS=001A000 ptr=004E3000
  stxt774    VS=0000208F RS=00003000 ptr=004FE000    ← 壳
  stxt371    VS=00003580 RS=00004000 ptr=00501000    ← 壳
```

三个决定性特征：

1. **`.data` 虚拟大小 148MB 但磁盘只有 280KB** → 典型运行时自解压壳
2. **`stxt774` / `stxt371` 壳节区** → SafeDisc（SdtCore）特征节名
3. **导入表含 `CActiveImage@Sdt@Mvsn`** → `Mvsn` = Macrovision，`Sdt` = SafeDisc
   同时含 `FAILED_VIRTUAL_PROTECT`、`VirtualProtect` 反复调用

配套文件也证实了这点：

| 文件 | 大小 | 作用 |
|---|---|---|
| `Secdrv.sys` | 46,592 B | SafeDisc 光驱保护**内核驱动** |
| `DrvMgt.dll` | 163,644 B | SafeDisc 驱动管理器 |
| `00000000.256` | 121,078 B | 光盘签名（实为 400×300 8bpp BMP） |
| `Media/san11pkres.bin` | 954 MB | Koei LINK 格式资源包（**资源已免 CD**） |

### 为什么在 macOS 上无解

SafeDisc 的检测机制依赖 `secdrv.sys` **内核驱动**：

- 社区标准解法是注册驱动 + 加载服务（`sc config secdrv start= auto`）
- **Wine / CrossOver 无法加载 Windows 内核驱动** → 这条路彻底堵死
- 所以 `win98 bottle` 的静默退出 = SafeDisc 检测失败后主动 `ExitProcess`
- `winxp bottle` 的非法指令 = SafeDisc 反调试/反模拟陷阱（`ud2` 类指令）

### 破局：脱壳补丁

社区（巴哈姆特、ali213、downxia）一致的做法是**使用「脱壳补丁」**——
把带壳的 `san11pk.exe` 替换成脱壳后的版本，直接跳过 SafeDisc 检测。

本机获取的脱壳补丁来自 **ali213**（`patch.ali213.net/showpatch/65061.html`），
落盘在 `~/.workbuddy/tmp/san11/unpack/`，内含 `ALI213.txt` 说明。

### 脱壳前后的硬证据

| 项目 | 带壳版（1.1/1.2 版） | 脱壳版（当前使用） |
|---|---|---|
| 文件大小 | 6,614,497 B | **159,920,128 B** |
| `.text` 磁盘/虚拟 | 0x34D000 / 0x34CF19 | **0x34CF19 / 0x34CF19（相等）** |
| `.data` 磁盘/虚拟 | **0x46000 / 0x93C47E0** | **0x93C47E0 / 0x93C47E0（相等）** |
| 运行时解压 | 需要 | **不需要** |

判据：**所有节区的磁盘大小 == 虚拟大小**，说明 `.data` 里那 148MB 的代码/数据已完全落盘，
运行时不再需要解压，也不会再执行 SafeDisc 检测逻辑。

> 包内 `修改器/SAN11PKME/1.1版执行档/san11pk.exe` **不是**脱壳版——
> 它与主 exe 节区完全一致（仅 17 字节差异，在 `.rdata +0x441FC` 附近，
> 是修改器的 hook 字符串），只是降级到 1.1 版以配合修改器。

### 脱壳版来源风险提示

非官方脱壳版存在被植入恶意代码的案例（社区有「网上盛传的那个脱壳版 san11pk 有毒」的反馈）。
本机使用的脱壳版来自 ali213 补丁包，**请自行确认来源可信**。

## 1.3 根因二：分辨率写死在代码里

### 现象

脱壳后游戏能启动了，但**窗口尺寸/模式选择出问题**，
且在 `win98 bottle`（Windows 98 显示模式列表）下 D3D 初始化直接失败。

### 逆向定位

用 winedbg 在 `0x44A137`（模式枚举循环）下断点，抓到过滤用的 graphics 对象 `0x6ed6eb0`：

| 偏移 | 值 | 含义 |
|---|---|---|
| `+0x1C` | `0x00000400` = **1024** | min width |
| `+0x20` | `0xFFFFFFFF` | max width（**不限**） |
| `+0x24` | `0x00000300` = **768** | min height |
| `+0x28` | `0xFFFFFFFF` | max height（**不限**） |
| `+0x2C` | `0x00000000` | min format（任意） |
| `+0x30` | `0x0000FFFF` | max format（任意） |

过滤条件反汇编（`0x44A137`–`0x44A154`）：

```asm
cmp eax, [edi+0x1c]   ; Width  vs 1024
jb  skip              ; Width < 1024 → 丢弃
cmp ecx, [edi+0x24]   ; Height vs 768
jb  skip              ; Height < 768 → 丢弃
cmp eax, [edi+0x20]   ; Width  vs -1 (不限)
ja  skip
```

⇒ 过滤规则就是 **`Width >= 1024 && Height >= 768`**，无上限。

### 致命的枚举结果

D3D9 枚举到 **132 个模式**，全部是 macOS 的 Retina 缩放分辨率：

```
960x600, 1024x640, 1024x665, 1147x716, 1147x745,
1280x800, 1352x845, 1352x878, 1512x945, ... 最大 3024x1964
```

**其中没有 1024x768** —— Apple 早已在 macOS 中移除 4:3 显示模式。

于是：
- 游戏的显示模式过滤表初始为空 → 选不出可用模式
- D3D 设备创建失败 → 走 `0x43DE10` 分支，弹「DirectX版本过低」
- 这也是 `win98 bottle` 静默退出的第二个原因

### 修复方式：改注册表，不改 exe

**关键事实**：分辨率**不是**写死在 exe 里的常量，而是存在**注册表**中。

```
HKEY_CURRENT_USER\Software\KOEI\San11PK Tc\San11Option
  "DisplayMode 0" = hex:...
```

该二进制结构（48 字节）中与分辨率相关的字段（基线 vs 修改后实测对比）：

| 偏移 | 基线值 | 修改后 | 含义 |
|---|---|---|---|
| `+0x18` | 22 | **35** | 模式索引（枚举表中的序号） |
| `+0x1C` | 22 | **35** | 同上 |
| `+0x20` | 77 | 77 | format / refresh（不变） |
| `+0x28` | 1280 | 1280 | Width |
| `+0x2C` | 800 | 800 | Height |

修改方式（注册表 hex 覆盖）：

```
基线：  00,01,00,00,00,16,00,00,00,16,00,00,00,4d,...
修改后：00,01,00,00,00,23,00,00,00,23,00,00,00,4d,...
                    ↑0x16=22      ↑0x23=35
```

> ⚠️ **重要澄清**：网上流传的「把 1024x768 改成 1280x800」说法，容易被误解为
> 在 exe 里改常量。**实测当前 exe 中 (1024,768) 相邻常量对仍有 10 处、
> (1280,800) 一处都没有** —— exe **没有**被改过。
> 真正生效的是**注册表** `DisplayMode` 的模式索引（22 → 35）。

### 顺带确认：为什么 1280x800 能被识别

过滤器只要求 `>= 1024 && >= 768`，而枚举表里 **1280x800 存在**（第 35 号），
所以把索引改到 35 即可命中，无需任何 exe 补丁。

## 1.4 根因三：区域设置（中文显示）

脱壳 + 修好分辨率后，游戏能跑但**界面是乱码/英文**。

| 项 | 错误值 | 正确值 |
|---|---|---|
| `Locale` | `00000409`（en-US） | **`00000404`（zh-TW）** |
| `sLanguage` | en-US | **CHT** |
| ACP | 1252 | **950（Big5）** |

游戏本身是繁中版（`Koei\San11PK Tc`），必须在 bottle 里设成 zh-TW/ACP 950，
否则字符串按 ANSI 解释会乱码。

启动脚本里的对应处理：

```bash
export LANG=zh_TW.UTF-8
export LC_ALL=zh_TW.UTF-8
```

## 1.5 第一阶段的三项修复

| # | 问题 | 解决方式 | 状态 |
|---|---|---|---|
| 1 | SafeDisc 壳导致 illegal instruction / 静默退出 | **替换为脱壳版 `san11pk.exe`**（159MB，节区磁盘=虚拟） | ✅ 已解决 |
| 2 | 显示模式列表无 1024x768，D3D 初始化失败 | **改注册表 `DisplayMode` 索引 22 → 35（1280x800）** | ✅ 已解决 |
| 3 | 界面乱码（en-US vs zh-TW） | **bottle 设 ACP 950 / `Locale=00000404`，启动脚本导出 zh_TW** | ✅ 已解决 |

三项修复完成后，游戏**能正常启动并进入大地图**——
此时才轮到第二阶段（旗帜白化）的问题浮出水面。

---

# 第二阶段：3D 大地图旗帜恒白

## 2.1 现象

| 对象 | 期望 | 实际 |
|---|---|---|
| 3D 大吊旗（大地图城池旗帜） | 势力色（濮阳=明黄等） | **纯白** |
| 城墙小旗（2D 贴图） | 势力色 | 正常 ✅ |

关键判别特征：**同一张放大截图里，城墙小旗橙金正常，只有 3D 大吊旗纯白**。
这一条直接把问题精确定位到**顶点色（vertex color）通道**。

像素级实测（纯白判定：R,G,B ≥ 235 且饱和度 ≤ 12）：旗帜区域全部命中纯白阈值。

## 2.2 根因：wined3d 的固定管线顶点色缺陷

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

### 早期误判（已推翻，保留备查）

排查中曾出现「改了色号 54 → 旗帜仍白」的弯路。实际原因：

- **色号 54 = 贼**，正确应为 **41（明黄 160,160,0）**
- 更重要的是：**游戏会按画质档（GraphicsQuality）自动切换简化渲染路径**，
  低画质下根本不传顶点色 → 换任何色号都没用。这是排查干扰项。

## 2.3 一个致命陷阱：DXVK 从未被真正加载

CrossOver 的全局 `DllOverrides` 表里有 `d3d10` / `d3d11` / `d3d10core` = `native,builtin`，
**唯独没有 `d3d9`** → Wine 对 `d3d9` **一律走 builtin（wined3d）**。

`lsof` 硬证据：早前所有「DXVK vs wined3d」对照实验中，游戏进程加载的都是
`lib/wine/i386-windows/d3d9.dll`（wined3d），**bottle 里的 DXVK 从未被加载过**。

⇒ 早期「DXVK 1.10.3 和 wined3d 都白旗」的结论**完全无效**，已推翻。
⇒ 修正方法：必须用 `--dll d3d9=n` 强制 native 覆盖。

### 为什么必须是 CrossOver 定制 MoltenVK 1.2.5

**MoltenVK 兼容矩阵（已实测）：**

| MoltenVK 版本 | DXVK 1.9.2 / 1.10.1 | DXVK 1.10.3 / 2.0 / 2.4 |
|---|---|---|
| **CrossOver 定制 1.2.5 (0.2.2013)** | ✅ 可用 | ❌ UBO slot 冲突 |
| 上游 1.2.6 / 1.2.9 / 1.3.0 / 1.4.2 | ❌ feature 错误 | ❌ feature 错误 |

上游 MoltenVK 两个硬伤（精确错误）：

```
[mvk-warn] VK_ERROR_FEATURE_NOT_PRESENT: Metal does not support buffer robustness.
[mvk-error] vkCreateDevice(): Requested physical device feature specified by the
            5th flag in VkPhysicalDeviceFeatures is not available on this device.
```

- 第 5 个 flag = **geometryShader**：MoltenVK 1.2.6+ 把 Metal 3 mesh shader
  误报为传统 geometry shader，DXVK 读到 true→请求→创建时拒绝
- **robustBufferAccess**：DXVK 强制要求；上游 MoltenVK 1.3/1.4 明确不支持

⇒ **只有 CodeWeavers 的定制 fork 同时满足两个条件，不可替换为上游版。**

---

# 第三阶段：旗帜对了但界面卡

## 3.1 现象

强制走 DXVK 后旗帜颜色恢复正常，但用户反馈：

> 「这么修复好了后只能说勉强运行，在招人界面等很多地方都会一卡一卡的」

具体表现：

- 招人界面（以及大量 2D UI 界面）操作时**一卡一卡**，不是整体掉帧而是**顿挫**
- 大地图 3D 场景相对流畅（约 95 FPS）
- 标题画面 120 FPS，帧时间 min 7.6 ms / **max 23.5 ms**（波动达 3 倍）

## 3.2 两条链路的架构对比

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

**关键不在「有没有 Rosetta」，而在 Rosetta 转译的是哪一层：**

- `opengl32.so` 是 **641 KB 薄转发层**，真正的 GL→Metal 编译在
  arm64 原生扩展 `AppleMetalOpenGLRenderer` 里完成
- `libMoltenVK.dylib` 是 **6.4 MB 完整 Vulkan 栈**，
  **每一次 Vulkan 调用都要 x86→arm 转译**

> macOS 27 上 `/System/Library/Frameworks/OpenGL.framework/OpenGL` 是
> broken symbolic link，实际渲染由 arm64 原生扩展承担。

## 3.3 决定性证据：sample 对比

同一游戏、同一场景的 `sample` 采样：

| 采样对象 | `AppleMetalOpenGLRenderer`（arm64 原生） | `libMoltenVK`（x86_64/Rosetta） | `vkWaitForFences` |
|---|---|---|---|
| **wined3d 路径** | **54 次命中** | 1 次（仅二进制映射表） | **0 次** |
| **DXVK 路径** | 0 次 | 45 次 | **200 次** |

DXVK 路径 `dxvk-queue` 线程栈样本：

```
+ 345 NtWaitForAlertByThreadId (in ntdll.so)
+   207 __wine_unix_call_dispatcher (in ntdll.so)
+     200 vkWaitForFences (in libMoltenVK.dylib)
```

⇒ **DXVK 路径下 CPU 有 62% 的时间阻塞在等 GPU fence**，而 wined3d 路径 0 次。

### 关键差异归纳

| 维度 | wined3d（白旗但流畅） | DXVK（旗帜正确但卡） |
|---|---|---|
| 渲染后端 | OpenGL → **arm64 原生** `AppleMetalOpenGLRenderer` | Vulkan → **x86_64** `libMoltenVK`（Rosetta 转译） |
| 转译层体量 | 641 KB 薄转发层 | **6.4 MB** 完整 Vulkan 实现，逐调用转译 |
| CPU 阻塞 | `vkWaitForFences` **0 次** | **200 次**（等 fence） |
| FPP 顶点色 | ❌ 缺陷 → 旗帜白 | ✅ 正确 |
| 管线编译 | OpenGL 状态机，动态 | 着色器管线，**同步编译** |

### 补充：DXVK 1.10.1 无异步管线编译

`strings` 扫描本地 5 个 DXVK 版本（1.9.2 / 1.10.1 / 1.10.3 / 2.0 / 2.4），
`async` 关键词**全部 0 命中**。⇒ 遇到新着色器变体时**同步编译**，
在 UI 界面（大量新状态组合）切换时产生顿挫。

## 3.4 为什么招人界面这类 UI 特别卡

招人界面是**纯 2D UI**，每帧大量小 draw call、状态切换频繁：

1. **DXVK 每次 draw call 都要经 x86→arm 转译**（Vulkan → MoltenVK → Metal）
2. **32 位进程 → 64 位 winevulkan 的 wow64 IPC**，每 draw call 一次跨进程调用
3. **UI 界面状态组合多 → 触发着色器管线同步编译**（DXVK 1.10.1 无异步编译）
4. 叠加 `numBackBuffers=1` / `maxFrameLatency=1` 的激进配置 → 流水线深度不足，
   偶发帧间阻塞

而大地图 3D 场景 draw call 数量少、单次负载大，摊薄了这些开销，所以相对流畅。

---

# 已排除的假设

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
| **K** | **分辨率需改 exe 常量** | ❌ **推翻** | exe 中 (1024,768) 仍有 10 处、(1280,800) 为 0；实际改的是注册表 |
| **L** | **修改器目录的 1.1 版是脱壳版** | ❌ | 节区完全一致，仅 17 字节差异 |
| **M** | **显卡/DirectX 版本过低导致崩溃** | ❌ | 实为 SafeDisc 检测失败后的通用错误分支 |

---

# 最终解决方案

## 架构总览

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

## 方案一：DXVK 1.10.1（旗帜正确）★ 推荐

**技术栈**：CrossOver 24.0.5 + DXVK 1.10.1 (x32) + CrossOver 定制 MoltenVK 1.2.5 + `dxvk.conf`

| 指标 | 结果 |
|---|---|
| 3D 大吊旗颜色 | ✅ 正常（濮阳明黄 = 势力色 41） |
| 大地图 | ✅ **95 FPS**，帧时间 9.8 ms |
| 标题画面 | ✅ 120 FPS |
| 招人等 UI 界面 | ⚠️ 仍有顿挫（Rosetta 转译固有开销） |

### `dxvk.conf` 说明

位于游戏目录，DXVK 自动读取（路径：`/Users/w.fish/wine_soft/san11pk/dxvk.conf`）。
目标是降低每帧缓冲/同步开销，缓解 wow64 + Rosetta 下的低帧率。

⚠️ **已验证无效的键**（DXVK 1.10.1 中不存在，被静默忽略，但日志仍会回显，
容易造成「已优化」的错觉）：

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

## 方案二：wined3d（运行效率高）★ 流畅优先时选

**技术栈**：CrossOver 24.0.5 + builtin wined3d（`--dll d3d9=b`）

| 指标 | 结果 |
|---|---|
| 3D 大吊旗颜色 | ❌ **纯白**（wined3d FPP 顶点色缺陷） |
| 运行流畅度 | ✅ **最优** — 走 arm64 原生 `AppleMetalOpenGLRenderer`，无 `vkWaitForFences` 阻塞 |
| 招人等 UI 界面 | ✅ 不卡 |

**关键点**：`--dll d3d9=b` 让 Wine 强制用 builtin wined3d，**完全忽略**
bottle `system32/d3d9.dll` 里的 DXVK。因此**两个方案可以随时来回切换，无需替换任何文件**。

## 第一阶段修复的落地位置

| 修复项 | 落地位置 | 说明 |
|---|---|---|
| 脱壳 | `~/wine_soft/san11pk/san11pk.exe` | 159,920,128 B，ali213 脱壳版 |
| 分辨率 | bottle `user.reg` → `Software\KOEI\San11PK Tc\San11Option\DisplayMode 0` | 索引 22 → 35（1280x800） |
| 区域设置 | bottle `user.reg` → `Locale=00000404` / `sLanguage=CHT`，ACP 950 | + 启动脚本导出 `zh_TW.UTF-8` |

---

# 启动命令

## 方案一：旗帜颜色正确版（DXVK 1.10.1）

**一行命令：**

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

## 方案二：运行效率高版（wined3d）

**一行命令：**

```bash
cd /Users/w.fish/wine_soft/san11pk && \
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle san11 --dll d3d9=b ./san11pk.exe
```

> ⚠️ **此方案下 3D 大吊旗会显示纯白**，这是 wined3d 的固有限制，无法通过配置绕过。
> 其余功能（内政、外交、战斗）完全正常。

## 两条命令对比速查

| | 方案一（旗帜正确） | 方案二（效率高） |
|---|---|---|
| 启动参数 | `--dll d3d9=n` | `--dll d3d9=b` |
| 实际渲染器 | DXVK 1.10.1 → Vulkan → MoltenVK | builtin wined3d → OpenGL |
| 旗帜颜色 | ✅ 正常势力色 | ❌ 纯白 |
| 大地图 | 95 FPS | 更流畅 |
| 招人等 UI | ⚠️ 顿挫 | ✅ 顺畅 |
| 需要换文件 | 否（DXVK 常驻 system32） | 否（`d3d9=b` 直接忽略） |

## 回滚到 CrossOver 默认渲染

```bash
cp "$HOME/Library/Application Support/CrossOver/Bottles/san11/drive_c/windows/system32/d3d9.dll.orig" \
   "$HOME/Library/Application Support/CrossOver/Bottles/san11/drive_c/windows/system32/d3d9.dll"
# 并去掉启动参数 --dll d3d9=n
```

`d3d9.dll.orig` = CrossOver 自带原始 DXVK
（sha256 `93d3591aba10999b5f53a123566d193b8c153eff520818f91a7f3642be8d739d`）

---

# 文件清单

| 路径 | 说明 |
|---|---|
| `~/wine_soft/san11pk/san11pk.exe` | **脱壳版主程序**（159MB，ali213 脱壳补丁） |
| `~/wine_soft/san11pk/启动三国志11.command` | 主启动器（方案一） |
| `~/wine_soft/san11pk/启动三国志11-高效模式.command` | 高效模式启动器（方案二） |
| `~/wine_soft/san11pk/dxvk.conf` | DXVK 调优配置 |
| `~/wine_soft/san11pk/Secdrv.sys` | SafeDisc 驱动（Wine 无法加载，仅存档） |
| `~/wine_soft/san11pk/DrvMgt.dll` | SafeDisc 驱动管理器（同上） |
| `~/wine_soft/san11pk/Media/san11pkres.bin` | Koei LINK 资源包（954MB） |
| `~/Library/Application Support/CrossOver/Bottles/san11/user.reg` | **含分辨率与区域设置修复** |
| `~/Library/Application Support/CrossOver/Bottles/san11/drive_c/windows/system32/d3d9.dll` | 当前 = DXVK 1.10.1 x32 |
| `~/.workbuddy/tmp/san11/unpack/` | 脱壳补丁原始包 + `ALI213.txt` |
| `~/.workbuddy/tmp/san11/FINDINGS.md` | 完整排查过程记录（978 行） |
| `~/.workbuddy/tmp/san11/regbak/user.reg` | 注册表基线（zh-TW + 1280x800） |
| `~/.workbuddy/tmp/san11/shots_final/` | 验证截图（60 张） |

---

# 后续可选方向

1. **arm64 原生 CrossOver 26.3.0** —— 唯一能同时摆脱 Rosetta + 拿到新 MoltenVK 的路
   （用户已取消下载，状态待确认）
2. **升级 MoltenVK 到 1.4.2（Vulkan 1.3）+ DXVK 2.x** —— 但仍是 x86_64，
   只能缓解不能根治
3. **A/B/C 三组 `dxvk.conf` 实测**（`numBackBuffers` / `maxFrameLatency` 放开 vs 默认）
   —— 已备好配置，待实测取数
4. **DXVK state cache 命中优化** —— 减少 UI 界面的同步管线编译顿挫
5. **为 wined3d 路径补一个顶点色修正** —— 若能在 wined3d 侧修好 FPP 顶点色，
   可同时拿到「旗帜正确 + 流畅」，是最理想结局

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

# 附：踩坑清单

## 第一阶段相关

### 坑 1：`--dll d3d9=n` 缺一不可
全局 `DllOverrides` 无 `d3d9` 条目 → 不加参数则 DXVK 永不加载，
所有对照实验结论作废（详见 §2.3）。

### 坑 2：修改器目录的 exe 不是脱壳版
`修改器/SAN11PKME/1.1版执行档/san11pk.exe` 与主 exe 节区完全一致（仅 17 字节差异），
都是带壳版。

### 坑 3：分辨率改的是注册表，不是 exe
网上教程说「改 1024x768」，容易误解为改 exe 常量。
实测 exe 中 (1024,768) 相邻对仍有 10 处、(1280,800) 为 0 —— **exe 没被改过**，
真正生效的是注册表 `San11Option\DisplayMode 0` 的模式索引。

### 坑 4：SafeDisc 的报错具有误导性
D3D 初始化失败走的是 `0x43DE10` 分支，弹「**DirectX版本过低**」。
实际是 SafeDisc 检测失败后的通用错误分支，与 DirectX 版本无关。

### 坑 5：SafeDisc 的 `00000000.256` 不是光盘镜像
它是 400×300 8bpp 的合法 BMP，尾部是 `0x3f` 填充，
只是 SafeDisc 用来标识光盘的签名文件。

## 通用排查相关

### 坑 6：色号搞错
54 = 贼；正确的是 **41 = 明黄 (160,160,0)**。

### 坑 7：游戏会按画质档切简化渲染路径
低画质下不传顶点色，改色号无效。

### 坑 8：MoltenVK 不能换成上游版
上游 1.2.6+ 会误报 geometryShader 并移除 robustBufferAccess → `vkCreateDevice` 失败。
只能保留 CrossOver 定制 1.2.5。

### 坑 9：DXVK 配置键会「静默忽略」
`d3d9.cachedDynamicBuffers` / `d3d9.samplerLodBias` 在 1.10.1 中不存在，
但日志的 "Effective configuration" 段仍会回显 → 极易误判为「已生效」。

### 坑 10：Python 的 Quartz 模块不可用
系统 python3 与 anaconda python3 均无 Quartz → 改用纯 ctypes 调 CoreGraphics。

### 坑 11：`CFStringGetCString` 成功时返回 0
不是 true。用 `== 0` 判断成功，否则字符串全取空。

### 坑 12：`CFStringCreateWithCString` 第 3 参是 encoding
→ 传 0（系统默认），UTF8 只在 `CFStringGetCString` 第 4 参指定 `0x08000100`。

### 坑 13：macOS 27 上 OpenGL.framework 符号链接断裂
`/System/Library/Frameworks/OpenGL.framework/OpenGL` → broken symbolic link，
但实际渲染由 `AppleMetalOpenGLRenderer`（arm64 原生扩展）承担。

### 坑 14：git remote URL 写错引发的误判
`https://fengyanbum/repo.git`（漏 `github.com`）会让 git 把 `fengyanbum`
当主机名 → `Could not resolve host: fengyanbum`。
排查时容易被误判成「代理问题」，**先核对 remote URL 再怀疑网络**。

### 坑 15：本机代理对 git 协议端点不友好
ClashX 7890 对 `api.github.com` 正常，但对 `github.com` 的 git smart-http 端点
CONNECT 隧道会 502 / `SSL_ERROR_SYSCALL`；**反而直连可用**。
⇒ git 操作 GitHub 优先清空代理变量直连。
