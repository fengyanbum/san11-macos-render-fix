# 三国志11 加强版 — macOS + CrossOver 渲染问题排查

macOS 上运行《三国志11 加强版》(San11PK) 时，3D 大地图旗帜恒为白色的排查与解决方案。

## 问题现象

| 现象 | 描述 |
|---|---|
| 旗帜纯白 | 3D 大地图上的势力吊旗失去势力配色，全部渲染为纯白色 |
| UI 顿挫 | 招人等界面操作"一卡一卡"，无法流畅交互 |
| 帧率不足 | 大地图约 95 FPS，招人等界面明显掉帧 |

## 根因

两条**完全不同的渲染链路**，性能特征截然相反：

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

- **白旗原因**：wined3d 的固定管线（FPP）顶点色处理有缺陷 → 3D 大吊旗丢失势力色。
  该缺陷在 Wine 9.0 / 10.0 / 11.21 全部复现，属系统性问题。
- **顿挫原因**：DXVK 走 shader 化的 FPP 模拟，颜色正确；但 6.4MB 的完整 Vulkan 栈
  全程 Rosetta 转译，`dxvk-queue` 线程 62% 时间阻塞在 `vkWaitForFences` 等 GPU fence。
  叠加 DXVK 1.10.1 **无异步管线编译**（1.9.2/1.10.1/1.10.3/2.0/2.4 均无），
  UI 界面新状态组合会触发同步着色器编译 → 顿挫。

实测对比（同一游戏、同一场景 `sample`）：

| 采样对象 | AppleMetalOpenGLRenderer | libMoltenVK | vkWaitForFences |
|---|---|---|---|
| wined3d 路径 | **54 次命中** | 1 | **0** |
| DXVK 路径 | 0 | 45 | **200** |

## 解决方案：两套启动命令，按需切换

关键：`--dll d3d9=b` 会**忽略** `system32/d3d9.dll` 里的 DXVK，
所以两方案零成本来回切换，**不需要替换任何文件**。

### 方案一：旗帜正确

```bash
cd /Users/w.fish/wine_soft/san11pk && \
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle san11 --dll d3d9=n ./san11pk.exe
```

或双击 `启动三国志11.command`（自动校验并部署 DXVK，sha256 精确匹配）。

### 方案二：运行高效

```bash
cd /Users/w.fish/wine_soft/san11pk && \
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle san11 --dll d3d9=b ./san11pk.exe
```

或双击 `启动三国志11-高效模式.command`。

## 文件清单

| 文件 | 说明 |
|---|---|
| `docs/三国志11_macOS_渲染问题排查与解决方案.md` | 完整排查文档（现象 / 原因 / 排除清单 / 方案 / 命令 / 踩坑清单） |
| `启动三国志11.command` | 方案一启动器（DXVK 1.10.1 → 旗帜正常） |
| `启动三国志11-高效模式.command` | 方案二启动器（wined3d → 运行流畅） |
| `dxvk.conf` | DXVK 调优配置（放游戏目录，DXVK 自动读取） |

## 环境

- macOS 27.2.1 / Apple M2 Pro
- CrossOver 24.0.5（x86_64，Rosetta 下运行）
- bottle `san11`（32 位，zh-TW）
- DXVK 1.10.1 (x32) + CrossOver 定制 MoltenVK 1.2.5

> ⚠️ 本仓库仅包含排查文档与启动脚本，不含任何游戏程序或资源文件。
