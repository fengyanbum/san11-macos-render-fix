# 三国志11加强版 —— 大地图旗帜纯白问题：实测数据记录

> 环境：macOS (Darwin 24.3.0) + CrossOver 24.0.5 / bottle `san11` (Win32 Wow64)
> 游戏：`/Users/w.fish/wine_soft/san11pk/san11pk.exe`（整合版，含 `修改器/San11Editor1211`）
> 记录日期：2026-11-24

---

## 1. 用户提供的两视角对照截图（关键证据）

| 文件 | 来源 | 说明 |
|---|---|---|
| `~/.workbuddy/tmp/san11/user_shots/shot_front.jpg` | 用户截屏 | 濮阳城，**正面视角** |
| `~/.workbuddy/tmp/san11/user_shots/shot_side.jpg` | 用户截屏 | 濮阳城，**侧面视角**（相机已旋转） |

两张均为 1920×1286 JPEG，同一位置（濮阳城）、同一时刻（251年1月1日）、不同相机角度。

### 1.1 画面内容确认（正面视角）
- 濮阳城（张角势力）：城墙小旗 = **橙金色（正常）**；城内大吊旗 = **纯白**；名牌势力小标 = **金黄（正常）**
- 张宝部队方阵旁竖旗 = **纯白**
- 须臾港旁港口旗 = **橙金色（正常）**，有明暗渐变与描边
- 结论：**同一画面内同时存在"正常彩旗"与"纯白旗"**

### 1.2 ⚠️ 对上一轮结论的重要修正
上一轮（基于自动截图 `c_origbase.png`）曾报告「**部队旗（地图上的小燕尾旗）= 橙金色，正常**」。

**该结论错误**。`r_old_unitflag.png` 放大复核显示，那块 28×42 的橙金色竖条**位于须臾港旁，是港口旗**，
不是部队旗（当时场景与本次不同，坐标参照有偏差导致误判）。

用户本次手动截图证实：**部队旗帜同样是纯白**。
→ 修正后的正确分类如下（本次两视角实测）：

| 对象 | 颜色 | 形态 | 渲染路径 |
|---|---|---|---|
| 城池大吊旗 | **纯白 ❌** | 3D 网格体 | 3D 实体（随视角变形） |
| 部队旗（张角/张宝旁） | **纯白 ❌** | 3D 网格体 | 3D 实体（随视角变形） |
| 港口旗（须臾港） | 橙金 ✅ | 燕尾布片 | 2D 贴图（不随视角变形） |
| 城墙小旗 | 橙金 ✅ | — | 2D 贴图 |
| 名牌势力小标 | 金黄 ✅ | — | 2D UI |
| 头像框金边 | 橙金 ✅ | — | 2D UI |

**这条修正把结论从"个别物体异常"升级为"凡走 3D 实体渲染路径的旗帜全白，走 2D 贴图路径的旗帜全正常"**
—— 分界线清晰，与"势力色数据坏掉"（F4）矛盾，更支持"3D 路径的着色环节失效"。

---

## 2. 像素级实测数据

### 2.1 连通域清点（纯白 R,G,B ≥ 235 且饱和度 ≤ 12）

**正面 shot_front.jpg**
| 面积 | x | y | w | h | 判定 |
|---|---|---|---|---|---|
| 1331 | 901 | 610 | 43 | 71 | 濮阳城内大吊旗 |
| 1207 | 1329 | 608 | 44 | 66 | 张角部队旁旗 |
| 842 | 1392 | 715 | 48 | 60 | 张宝部队旁旗 |

**侧面 shot_side.jpg**
| 面积 | x | y | w | h | 判定 |
|---|---|---|---|---|---|
| 1718 | 979 | 615 | 53 | 68 | 同上·濮阳大吊旗 |
| 1160 | 1216 | 547 | 46 | 55 | 部队旗 |

### 2.2 跨视角形态变化（**决定性数据**）

两张截图的相机**缩放不同**（侧面图视野更广，物体更小），因此绝对像素尺寸不可直接比较，
**只有「宽高比」是无量纲可比的**。

| 对象 | 视角 | 轮廓尺寸 | 宽高比 | 旗面最大列高 | 逐列高度剖面特征 |
|---|---|---|---|---|---|
| 城池大吊旗（白） | 正面 | 71×44 | **0.620** | 70 px | 旗面呈「上窄下宽的斜梯形」，顶边 y 从 6 递增到 20 |
| 城池大吊旗（白） | 侧面 | 70×53 | **0.757** | 69 px | 旗面接近矩形，顶边 y 基本持平（6→10） |
| 港口橙金旗（正常） | 正面 | 41×36 | **1.139** | 36 px | 平滑三角形渐变（1→36→6） |
| 港口橙金旗（正常） | 侧面 | 37×33 | **1.121** | 31 px | 平滑三角形渐变（1→31→7） |

**解读**：
- **白旗**：旗杆在 x=4~6（两视角均在同一列位，旗杆高 69~70px 不变），
  旗面横跨 43~53px。宽高比 0.620 → 0.757，**旗面横向被拉宽 22%**，
  顶边从斜坡变为水平 —— 这是**同一 3D 网格体随相机旋转产生的透视形变**。
  → **白旗是真实 3D 网格模型（旗杆 + 旗面），不是 billboard 精灵。**
- **港口橙金旗**：宽高比 1.139 → 1.121（**仅变化 1.6%**），逐列高度剖面在两视角下几乎同形，
  顶边始终平滑递减 —— **它是固定朝向的 2D 贴图布片**，颜色直接来自贴图像素。

**这是本次最有价值的发现**：白旗与彩旗**走的是两条完全不同的渲染路径**，
白旗 = 3D 网格（需顶点色/材质色参与），彩旗 = 2D 贴图（无需）。

### 2.2b 逐列高度剖面原始数据（白旗·城池大吊旗）

正面（总宽 51，列 = 高度(起-止)）：
```
3:3(41-71) 4:69(4-74) 5:70(4-74) 6:68(5-72) | 7:22(6-45) 8:18(6-44) ... 21:40(10-49)
... 26:35(19-53) ... 33:33(20-56) ... 40:15(24-56) 41:9(47-56) 42:7(50-56) ... 47:1(56-56)
```
侧面（总宽 61）：
```
3:1(22-22) 4:66(6-71) 5:68(4-71) 6:69(2-71) | 7:45(4-70) 8:21(5-27) ... 23:39(7-45)
... 30:38(8-45) ... 40:38(7-44) ... 50:19(11-46) 51:19(11-46) 52:19(12-48) 53:11(14-48) 54:7(26-48)
```
- 旗杆列（x=4~6）两视角高度完全一致 → 相机距离/缩放对同一物体一致，可信
- 旗面部分：正面顶边从 y=6 一路降到 y=20（斜），侧面顶边仅从 y=6 降到 y=10（平）
  → **同一网格在两个视角下顶边斜率不同 = 真实透视形变**

### 2.3 白旗 RGB 精确统计
- 主体区域唯一颜色数 1126（几乎全部是 JPEG 压缩噪点围绕 (255,255,255) 的抖动）
- 最高频色：**(255,255,255) × 472 像素**
- 中线扫描过渡：`255,255,255` → (x=36) `240,239,235` → `85,85,75` → `27,25,12`
  → **alpha 边缘只有 1~2 像素过渡，几乎无抗锯齿半透明**；完全无光照渐变、无描边、无织纹
- 面积占比 0.36 / 0.40（轮廓内实心率与背景接近）

### 2.4 港口橙金旗（正常对照组）RGB 统计
- 唯一颜色数 1274，暖色像素占比 71.5%
- 范围 (55,48,0) ~ (221,183,200)
- 中线扫描：暗边 `95,85,50` → 主体 `170,126,21` → 亮 `182,128,28` → 暗 `114,89,23`
  → **有 5 级以上明暗变化、边缘暗描边**

---

## 3. 由此确定的关键事实

| # | 结论 | 依据 |
|---|---|---|
| F1 | **不是 billboard 精灵，是 3D 网格旗模型** | 跨视角宽高比 0.620→0.757（橙金对照旗仅 1.139→1.121） |
| F2 | **贴图/几何/alpha 全部加载成功** | 轮廓、旗杆、燕尾缺口、像素级 alpha 边缘完全正确 |
| F3 | **RGB 恒为 (255,255,255)，零光照、零描边、零纹理** | 唯一色 (255,255,255) 占 472 像素；无灰阶梯度 |
| F4 | **不是"势力色数据坏掉"** | 同屏名牌势力小标、城墙小旗、港口旗（全部张角势力）均为正常橙金/金黄；且**凡走 2D 路径的旗帜全正常** |
| F5 | **不是"资源缺失→默认白"** | 若贴图缺失，旗面应退化为不透明矩形而非精确的燕尾旗轮廓 + 正确 alpha 边缘 |
| F6 | **白旗与彩旗走两条不同渲染路径** | 白旗是 3D 网格（跨视角宽高比 0.620→0.757），彩旗是 2D 贴图（1.139→1.121，基本不变） |
| F7 | **高度疑似 3D 实体着色路径缺了"颜色调制"环节** | 几何完美 + alpha 完美 + 颜色全白 + 无光照 = 顶点色/材质色未乘入 |

### F7 的机制推断
KOEI 引擎渲染 3D 网格时，若顶点声明带 `D3DFVF_DIFFUSE`（或顶点着色器 `VertexColor`），
最终像素 = 贴图 × 顶点色 × 光照。白旗这一路的**顶点色/材质色没有被乘进去**，
等价于乘了 (1,1,1)，于是只剩贴图亮度 → 而该贴图本身接近白色 → 呈现纯白。

这条路径在 DXVK / wined3d / DXVK 3.1.1 三种后端下**全部失效**，
说明它不是渲染后端 bug，而是**游戏侧数据问题**（顶点色数据缺失/为 1.0）或**资源被 mod 改过**。

---

## 4. 已排除的假设（全部实测无效）

| 假设 | 实验 | 结果 |
|---|---|---|
| 渲染后端差异 | DXVK ↔ wined3d(OpenGL/Metal) 切换 | 均白旗 |
| DXVK 版本过旧 | 装 DXVK 3.1.1（内置仅 1.10.3）实测 | 仍白旗（测完已按 md5 完整还原） |
| 顶点色/描边色注册表项 | 改 `EditVertexColors00/01/02`、`StageModelSilhouetteColor` | 无效 |
| 画质/远景/ MIP 选项 | 改 `ShowDistantView` 等 | 无效 |
| 整合版剧本数据问题 | 换原版 KOEI `MakeData.s11` + 换场景（张角黄巾剧本） | 仍白旗 |
| 资源容器损坏 | LINK 归档全量校验（39 处"不匹配"均为含多子纹理图集） | 通过 |
| 势力色数据坏掉 | 同屏名牌小标/城墙小旗/港口旗均正常 | 排除 |
| locale / Big5 乱码 | bottle locale 改 zh-TW | 无关（已修复标题栏乱码） |

---

## 5. 待验证（需用户游戏内操作）

### 实验②San11Editor 改势力颜色 —— 最关键
改一个势力的颜色 → 存盘 → 重进大地图 → 看白旗是否跟随变色
- **跟着变** → 着色通路正常，问题在"读到势力色"那一环（顶点色/材质色数据为 1.0）
- **不变** → 3D 场景的旗帜根本不吃势力色，必须往模型顶点色/贴图方向深查

### 实验③ 进一场战斗
战斗画面是另一套渲染路径：
- 战斗旗也白 → 全局性问题
- 战斗旗正常 → 大地图 3D 场景专属问题（权重上升：StageModel 路径）

---

## 6. 下一步（自主可做）
1. 在 WFTX 图集里定位"旗帜形状"贴图，确认其像素是否本身接近白 → 区分"贴图白"vs"顶点色没乘"
2. 解析 KOVS 3D 模型容器的顶点声明与顶点色块
3. 对比原版（KOEI 未 mod）`Media` 资源与整合版差异 —— 整合版极可能改过 K3ST/OBJS

---

## 7. 涉及文件
- 分析脚本：`~/.workbuddy/tmp/san11/`（`peexp.py` PE 导出解析、`click.py` 自动点击、各 `*.sh` 用例脚本）
- 资源归档：`/Users/w.fish/wine_soft/san11pk/Media/san11pkres.bin`（LINK 递归容器）
  - 1049 个 WFTX 纹理图集 / 2027 个 KOVS 3D 模型 / 653 个 WKMD / 717 个 FCVD / 4 个 GCOL(1025²地形) / 1 个 OBJS(917KB)
  - `K3ST0006` @525913191, 16,793,616 B —— 贴图着色器定义
  - `OBJS0004` @568061903, 917,498 B —— 对象索引
- 备份：`~/.workbuddy/tmp/san11/{regbak,dxvk_backup,savedata_backup}/`
- 启动器：`/Users/w.fish/wine_soft/san11pk/启动三国志11.command`（启动前自动恢复注册表原始基线）


---

## 补充：势力色数据结构（2026-11-24 12:00 追加）

### s11 格式完全破解（明文 Big5 + 定长记录）
| 项目 | 结论 |
|---|---|
| 文件头 | `0x0000FEFF` + `KOEI#SAN11`（0x08..0x11）|
| 文本编码 | **明文 Big5**（非加密、非压缩），势力名/武将名/地名均可直读 |
| 势力记录表 | scen000.s11 @ `0x3f4f`，**72 字节/条**（官方 san11-world 文档：`force 47×72`）|
| 势力色字段 | 记录内 **+6** 处（官方 `scenario_build.py:165` → `D[at("force",f) + 4 + F + 2]`）|
| 颜色索引范围 | **0~54（55 色）**，用完循环（官方 `scenario_build.py:181`）|
| 预览地图颜色 | scen_info @ `0x1DB`，42 字节，每城拥有者颜色（官方 `convert_scen.py:148`）|

### scen000.s11 势力颜色索引实测
- 势力记录表 0..21：color = `[11, 30, 28, 28, 29, 3, ff, ff, ...]`
- 城市预览色（0x1DB）非 ff 的索引：**{2, 3, 4, 5, 11, 20, 28, 29}**
- 空闲索引（未被 scen000 占用）：0,1,6~19,21~27,30~54

### 截图实测势力色
- 张角势力（索引 28）在截图中的**纯净色 = (255,136,0) 橙金**
- 其他色阶：(199,124,0) (193,126,0) (196,137,21) → 明暗渐变自同一基色

### 关键结论（本次新增）
- exe 中**不存在** 55 项 RGB 色板表（多种搜索策略均 0 命中）→ 势力色**不是查表得来**，
  索引 28 → (255,136,0) 的映射发生在**代码逻辑**里（很可能是 HSL/色相环算法）。
- 因此**不能靠改 exe 里的色板**来验证；只能靠改 s11 的索引值 → 看画面是否跟随。
- 张角 = 索引 28 = 橙金 (255,136,0)，与「黄巾=土黄色」的历史设定一致，**数据本身没坏**。

### 诊断实验设计（结论）
改色实验的判读表：
| 现象 | 结论 |
|---|---|
| 旗帜跟随变成新颜色 | 着色通路完好，问题在「读势力色」那一环 |
| 旗帜仍是纯白，但**名牌小标/城墙小旗跟着变了** | 2D 通路通、3D 通路断 → 锁定 3D 渲染路径 |
| 旗帜仍是纯白，**所有元素都没变** | 改动没生效（改错文件/没保存/改的不是该势力）|

---

## 补充②：势力色表 —— 保留段与精确偏移（2026-11-24 15:00 追加，修正上文两处错误）

### ⚠️ 对上文「势力记录表 @ 0x3f4f / 势力色 @ +6」的修正
上一条补充里的 base 偏移与字段偏移**是错的**（当时用了硬编码 base，未用官方布局函数）。
用官方 `convert_scen.py` 的 `scen_layout(C=42, N=87, wide=False, R=42)` 重算后：

| 项目 | 正确值 |
|---|---|
| 势力记录表 base | **`0x25454`**（不是 0x3f4f）|
| 每条字节数 | **72** |
| 条数 | **47**（42 常规 + 4 异族 + 1 贼）|
| 国号字段 | 记录内 **+52** |
| **势力色字段** | 记录内 **+53** |
| 预览地图色 | `scen_info` @ **0x1DB**（42 字节，存的是**色号**不是 RGB）|

### ★ 50~54 是 42~46 号特殊势力的专属保留色（用户「54是贼」得到二进制确证）

| 势力号 | 名称 | 固定势力色 |
|---|---|---|
| 42 | 羌族頭目 | **50** |
| 43 | 山越頭目 | **51** |
| 45 | 南蠻頭目 | **52** |
| 44 | 烏丸頭目 | **53** |
| 46 | 賊（鮑信）| **54** |

在 `MakeData.s11` / `scen015.s11` / `Scen001~013.s11` **全部**一致 → 是 KOEI 的固定约定。
→ **50~54 不可用于普通势力**。上一轮 AI 建议「改成 54」是错的，已作废。

### ★ scen000（黃巾之亂）权威占用表
- 势力记录表：`0x25454`，47 条 × 72 B
- 存活势力与色号（与 San11Editor 界面**逐行一致**）：
  `2孫 c2 | 3馬 c3 | 4劉 c4 | 5董 c5 | 11公孫瓚 c11 | 28張(國號5=黃巾) c28 | 29何 c29 | 30丁 c20 | 42羌 c50 | 43山越 c51 | 44烏丸 c53 | 45南蠻 c52 | 46賊 c54`
- **已占用色号**：`{2,3,4,5,11,20,28,29,50,51,52,53,54}`
- **空闲色号**：`{0,1,6~19,21~27,30~49}`
- **张角势力色字节偏移 = `scen000.s11` @ `0x25c69`**（= 0x25454 + 28×72 + 53），当前值 `28`

### ★ 加载路径确证：游戏读散装 .s11，不读 LINK 归档
`Media/san11pkres.bin`（910 MB，LINK 递归容器，4876 个 chunk）全量扫描结果：
- **搜不到** `scen000` / `.s11` / `scenario` 任何一处字符串
- chunk 类型分布：WFTX 1049、KOVS 2027、FCVD 717、WKMD 653、KSEF 246、TOD2 38、PAC0 16、AIMG 10、NUNO 8、**GCOL 4**、SHEX 2、SEFF 1、K3ST 1、DIST 1、SENV 1、OBJS 1、LINK 1

→ 归档里**没有剧本数据**，游戏必然读 `Media/scenario/*.s11` 散装文件。
→ **San11Editor 改散装文件 = 改游戏真正加载的文件，实验路径成立。**

### ★ GCOL 不是势力色表
4 个 GCOL chunk（`0x1e91ac8b` 等）各 3.15 MB，内容是 3 字节 RGB 的**地形/地面贴图**
（127,058 种颜色、灰绿苔藓色阶为主），与势力色无关。
（`0x4D15F8` 处那张 256 项 16-bit 表是 x86 数据，也不是色板。）

### ★ 55 项「索引→RGB」对照表在二进制中不存在
- 资源包内搜 RGB888 `FF 88 00`：61 处全在 `KSEF0131`（特效块）的 `FF FF FF FF` 掩码流里，**非色板**
- exe 内搜 RGB888 `FF 88 00`：18 处全是 x86 立即数尾部（`mov eax, 0x0088FExx`），**误报**
- RGB565 编码 `F8 40`：命中均为随机数据
- 结论：色号→RGB 映射**由代码算法生成**（HSL/色相环），静态不可提取。
  → 唯一办法是**让游戏渲染出来读色**，即实验②顺带标定调色板。

### ★ 编辑器不显示色块
San11Editor 势力列表的「势力色」列**只有数字**，没有颜色预览控件
→ 选色必须靠「合法 + 空闲 + 游戏内 2D 参照物读色」两条腿走。

### 实验② 修正后的执行方案
1. 在 San11Editor 里把**序号 28（張角/張寶，國號=黃巾）** 的势力色由 `28` 改为 **`36`**
   （36 合法、空闲、远离保留段 50~54、远离低位基础色 0~5；若与橙金太接近可换 33/41 等同段空闲号）
2. 保存 → 运行 `./exp2_color.sh after` → 应看到 `scen000.s11` 在 **offset 0x25c69** 由 `28`(oct 34) 变为 `36`(oct 44)
3. 进游戏看濮阳城，**同时看 2D 参照物**：
   - 城墙小旗 / 须臾港港口旗 / 名牌势力小标 = 2D 路径，应显示新色的**真实 RGB**（顺便标定调色板）
   - 城内大吊旗 + 张宝部队旗 = 3D 路径，观察是否跟随

| 观察 | 结论 |
|---|---|
| 2D 参照物变新色，3D 旗也变新色 | 3D 通路完好 → 白旗是**实例数据/材质**问题（回查模型顶点色）|
| 2D 参照物变新色，3D 旗**仍纯白** | 锁定 3D 渲染路径着色失效（加权：顶点色/材质色未乘入）|
| 2D 参照物也是白的/没变 | 该色号本身接近白 → 换一个色号重试（用空闲表里的其它号）|
| 所有元素都没变 | 改动没生效（没保存/改错势力/改错文件）|

### 新增脚本
- `show_forces.py` —— 解析任意 s11 的势力表，打印国号/势力色/占用与空闲色号 + 目标字节偏移
- `link.py` —— LINK 归档解析器（目录表、chunk 类型统计、GCOL 定位）

---

## ★★ 实验② 判定完成（2026-11-24 15:00）—— 结论锁定 3D 路径

### 实验操作
- San11Editor 把序号 28（張角/張寶，國號=黃巾）势力色 `28` → **`41`**
- 字节级确认：`scen000.s11` @ **0x25C69** 由 `28`(0x1C) → `41`(0x29)
- 编辑器同时同步更新了预览地图色表（文件 0x1DB 起 42 字节）：6 处 `0x1C` → `0x29`
  （值=29/何进 的位置未被误改 → 编辑器只替换等于旧值的项）
- 存档检查：CrossOver bottle 注册表 `Software\KOEI\San11PK Tc\{...}` **无 UserData 存档键**
  → 不存在误读旧档的可能

### 实测结果（截图 `user_shots/shot_after41.jpg`，1824×1221）
| 观察对象 | 渲染路径 | 改色前 | 改色后 | 判定 |
|---|---|---|---|---|
| 须臾港港口旗 | 2D 贴图 | 橙金 (255,136,0) | **黄 (160,160,0)** | ✅ 跟随 |
| 濮阳城墙小旗 | 2D 贴图 | 橙金 | **黄 (128~160,128~160,0)** | ✅ 跟随 |
| 城内大吊旗 | 3D 网格 | 纯白 | **纯白**（白占比 45%） | ❌ 未跟随 |
| 张宝部队旗 | 3D 网格 | 纯白 | **纯白**（白占比 46%） | ❌ 未跟随 |

### 结论（本项目最关键的一条）
> **凡走 3D 网格渲染路径的旗帜恒为纯白；走 2D 贴图路径的旗帜完全正常并正确跟随势力色。**
> 问题**精确定位在 3D 渲染路径的着色环节**，而非势力色数据本身。

排除的替代解释：
- ✗ 势力色数据坏掉 → 2D 路径用得好好的
- ✗ 改色没生效 → 2D 参照物确实变了
- ✗ 色号 41 本身接近白 → 41 渲染为**黄色**，不是白
- ✗ 改错文件 → 0x25C69 字节级已确认，且 2D 已跟随

### 附带收获：色表标定
- 色号 **28 → (255,136,0)** 橙金
- 色号 **41 → ≈(160,160,0)** 黄（基色可能更亮，R=G、B=0 的橄榄黄系）
- ⇒ 印证「色号→RGB 由代码算法生成」（HSL/色相环），非静态查表

### 下一步：实验③ 进一场战斗
战斗画面是另一套 3D 场景：
- 战斗旗也白 → 渲染器/着色器层面的全局问题
- 战斗旗正常 → 大地图 3D 场景专属问题（回查大地图场景的 3D 对象构建代码）

---

## ★★ 实验② 前提修正 + 渲染层定位（2026-11-24 15:20）

### ⚠️ 用户纠正：战斗与大地图是同一场景
三国志11 的野战**在��张大地图上直接进行**（镜头拉近、单位就位），不切独立战场场景。
→ 原定的「实验③ 进战斗做全局/专属二分法」**逻辑不成立**，撤回，不需执行。
→ 战斗画面里的旗帜必然与大地图旗走同一套 3D 管线。

### 排除项 1：EditVertexColors（曾高度怀疑，实为正常默认值）
- exe 内有格式化串 `EditVertexColors%02d`，注册表节 `Software\KOEI\San11PK Tc\San11Option`
- 反汇编（0x43ee8c~0x43ef74）证实：循环 3 次读 `EditVertexColors00/01/02` 存入设置结构体 `[esi+0x1dc..0x1e4]`
- **当前值 = `0x00ffffff`（纯白）**
- **官方攻略文档（fxxz.com 三国志11 操作教程）给出的默认注册表也是 `0x00ffffff`** → 与官方一致，非异常，排除

### 排除项 2：DrvMgt.dll
- 导出 `Remove`/`Setup`/`_DllMain@12`，含 `SECDRV.SYS` 内核驱动、`CdaC15BA.SYS`
- 属第三方驱动管理/安全组件，与渲染无关，排除

### ★ 决定性结构事实：当前 d3d9 是 DXVK 的 d9vk
| 项 | 值 |
|---|---|
| bottle `system32/d3d9.dll` | MD5 `10cb5e466352b1049908de7e48ca9b25` = CrossOver 内置 DXVK d9vk（`cxaddon-1.10.3`）|
| 全局 DllOverrides | 有 `d3d10/d3d10_1/d3d10core/d3d11 = native,builtin`，**唯独没有 `d3d9`** |
| 游戏 exe 导入 | `d3d9.dll` → 仅 `Direct3DCreate9`（其余走 COM 虚表）|
| 交叉验证 | `d3d9.dll` / `d3d9.dll.orig` / `d3d9.dll.dxvk.bak` 三者 MD5 **完全相同** → 全是 DXVK |
| ⇒ 结论 | **你 14:58 的白旗截图是在 DXVK 下拍的**。DXVK 是最忠实的 D3D9 实现，仍渲染不出颜色 → 要么 d9vk 兼容缺陷，要么游戏/资源侧问题 |

### ★ 可用渲染后端盘点
| 后端 | 位置 | 结论 |
|---|---|---|
| DXVK d9vk | `lib/wine/dxvk/d3d9.dll` | 当前使用 |
| **wined3d** | `lib/wine/i386-windows/d3d9.dll`（PE32 ✓）| **可立即 A/B 对照** |
| D3DMetal | `lib64/apple_gptk/external/D3DMetal.framework` | **仅 64 位**，本 bottle `WineArch=win32` → 不可用 |

### ★ CrossOver 不会把 wined3d 换回去
`CXBT_winxp.pm::upgrade_dxvk` 仅当文件 MD5 匹配已知 DXVK 哈希或 `dxvkfiles.conf` 记录值时才覆盖。
替换成 wined3d 后 MD5 不匹配 → **不会被还原**。

### 新增脚本
- `ab_d3d9.sh` — d3d9 实现 A/B 切换（`status` / `dxvk` / `wined3d` / `restore`）

### 判读表（实验④：wined3d vs DXVK）
| 结果 | 结论 |
|---|---|
| wined3d 下旗帜**有颜色** | **DXVK d9vk 兼容缺陷** → 保持 wined3d，问题解决 |
| wined3d 下旗帜**仍纯白** | 游戏/资源侧问题（D3D9 语义本身不被正确执行）→ 回到游戏内部查顶点色写入逻辑 |
| wined3d 下游戏**无法启动/花屏** | wined3d 对本游戏不兼容 → 回滚 DXVK，改查游戏侧 |

---

## CrossOver 版本确认与「升级能否解决白旗」的关键推论（2026-11-24 15:40）

### 本机实际版本
| 项 | 值 |
|---|---|
| CrossOver | **24.0.5**（build **37094**）|
| 安装时间 | 2024-09-10 |
| 内置 Wine | **9.0**（CX24 系列）|
| macOS | **27.2.1**（Build 26B131）|
| 硬件 | Apple **M2 Pro**（arm64）|
| bottle 架构 | **`WineArch = win32`（32 位）**|
| DXVK 版本 | 1.10.3（`cxaddon-1.10.3`）|

### ★ 文章作者是 23.6 → 25.1，升级后白旗依旧
原文（Enzo Lu, 2025-09-22）：
> 「想来当前的CrossOver版本，还停留在2年前发布23.6……便立即更新至最新的25.1。照旧打开古董级游戏《三国志11PK》……但当看到城池和队伍的旗帜那块儿成了一块白色时，我愣住了」

→ **升级到 25.1 后白旗依然存在** ⇒ 从 24.0.5 升到 25.1/26 **大概率修不好白旗**。
→ 升级不是解法；`ab_d3d9.sh` 的 wined3d/DXVK A/B 才是。

### ★ CX24 与 CX25+ 的图形后端开关差异（影响实验方式）
| | CrossOver 23.7~24（本机）| CrossOver 25+ |
|---|---|---|
| Advanced Settings → Graphics | 只有 **D3DMetal**、**DXVK** 两个勾选 | **Auto / DXMT / D3DMetal / DXVK / Wine** 下拉 |
| wined3d | 默认底座（DXVK 为勾选启用）| Auto 对未收录游戏 → wined3d |
| 说明 | 切到 wined3d 需手工换 DLL（本机用 `ab_d3d9.sh`）| GUI 一键可切 |

### ★ 佐证：CX25 的 DXVK 仍覆盖 D3D9
CodeWeavers 论坛（LOTRO, 2025-03）：CX 25.0.0 的 DXVK 与 D3D9 实现不兼容导致黑屏，
官方建议「Advanced Settings → Graphics 从 DXVK 改成 **WINE (wined3d)**」
⇒ CX25 的 DXVK 仍会接管 D3D9，不是「DXVK 只管 D3D10/11」。

### ⚠️ 升级红线：绝不要升到 CrossOver 27
CodeWeavers 官方博客（2026-06-11）：
> 「32-bit bottles will no longer run, full stop.」

- CX 27 仅支持 Apple Silicon + macOS Sonoma+，且**完全移除 32 位 bottle**
- 本机 bottle 是 `WineArch = win32` ⇒ 升 CX27 = 游戏直接起不来
- CX 26 仍可（保留 64 位 bottle 默认 + 「Enable deprecated 32-bit bottles」开关）
- 若要长期用 CX27，须**新建 64 位 bottle 重装游戏**（CodeWeavers 称「几乎所有 32 位程序在 64 位 bottle 里都能跑」）

### 版本时间线
| 版本 | 发布 | 引擎 / 图形 |
|---|---|---|
| 23.6 | 2024 | Wine 8.x |
| **24.0.5（本机）** | **2024-09-10** | Wine 9.0、DXVK 1.10.3 |
| 25.0.0 | 2025-03-11 | Wine 10.0、新增 DXMT、D3DMetal 2.1、per-game 数据库 |
| 25.1.0 / 25.1.1 | 2025-08-12 / 2025-09-15 | macOS Tahoe 修复（25.1.1 要求 macOS 26+）|
| 26.0.0 | 2026-02-10 | Wine 11.0、D3DMetal 3.0、DXMT v0.72、vkd3d 1.18 |
| 26.3 | 2026-07 | 当前最新 |
| 27 | 2027 初 | **移除 32 位 bottle**、ARM64 原生、仅 Apple Silicon |

### 一个值得注意的旁证
2026-11-23 有人动过 CrossOver 自带的 DXVK d3d9.dll：
`lib/wine/dxvk/d3d9.dll` 现为原版 `10cb5e46…`（2024-09-10），
同目录 `d3d9.dll.bak2`（2026-11-23 17:04）为另一版本 `faff641a…`（大小同为 3316048）。
⇒ **历史上已经试过换 DXVK d3d9.dll 版本**，结果是白旗依旧 —— 又一条「DXVK 换版本无用」的证据。

---

## ★★★ 23.6 vs 24 vs 25 的版本考古（2026-11-24 16:00）—— 白旗回归点定位

### 一、CodeWeavers 官方 changelog 原文（关键条目）

| 项 | CX 23.0.0 / 23.6.0 | CX 24.0.0 | CX 25.0.0 |
|---|---|---|---|
| 发布日期 | 2023-08-16 / **2023-10-18** | **2024-02-22** | 2025-03-11 |
| **Wine** | **8.0.1** | **9.0**（7000+ 更新） | **10.0**（5000+ 更新） |
| **DXVK** | **1.10.3** ← 23.0.0 原文 "Update to DXVK 1.10.3" | 未提及 → **沿用 1.10.3** | 未提及 |
| vkd3d | 1.8 | 1.10 | 1.14 |
| MoltenVK | 1.2.3 | 1.2.5 | 1.2.10 |
| Wine Mono | 7.4 | 8.1 | 9.4.0 |
| 32 位 bottle | — | 中文官方代理站：**CX24 首次支持运行 32 位程序** | — |
| 其他 | 23.5 新增 D3DMetal 开关、game porting toolkit 翻译层 | UI 改进 | **DXMT**（Metal 版 D3D11）、按游戏自动配置数据库、D3DMetal 2.1 |

### 二、★ 决定性推论
> **CrossOver 23.6 与 24.0.5 内置的是【完全相同】的 DXVK 1.10.3。**
> （本机实测 `system32/d3d9.dll` = `cxaddon-1.10.3` ↔ changelog 23.0.0 "Update to DXVK 1.10.3" 完全对上）
>
> ⇒ **23→24 的唯一实质变化是 Wine 8.0.1 → 9.0**，不是 DXVK 版本跳跃。
> ⇒ DXVK 的 1.10.3 → 2.x 跳跃发生在 **24→25**，与 23→24 无关。

### 三、★ 结合本机实测，反推白旗回归点
| 版本 | Wine | DXVK | 白旗？ |
|---|---|---|---|
| 23.6 | 8.0.1 | 1.10.3 | **文章作者称正常（未经证实）** |
| **24.0.5（本机）** | **9.0** | **1.10.3** | **白旗（已实测，截图 1824×1221）** |
| 25.1 | 10.0 | 2.x | 白旗（文章） |

⇒ **白旗在本机 24.0.5 已经存在**，说明它出现在 **23.6 与 24.0 之间**。
⇒ 若「23.6 正常」成立，回归点 = **Wine 8.0.1 → 9.0**。
⇒ **降级 CrossOver 到 23.6 是候选解法**（但 macOS 27 上能否运行存疑；CX27 会移除 32 位 bottle）。

### 四、文章原文核对（阅读理解判定）
原文（Enzo Lu, 2025-09-22）逐字：
> 「想来当前的CrossOver版本，还停留在2年前发布23.6，可能兼容性差了不少，便立即更新至最新的25.1。」
> 「照旧打开古董级游戏《三国志11PK》，看上去似乎一切正常，但当看到城池和队伍的旗帜那块儿成了一块白色时，我愣住了」

- ❌ 文章**从未陈述**「23.6 时期旗帜是正常的」——「我愣住了」只表示**第一次注意到**，不等于**第一次发生**
- ⚠️ 「照旧打开」暗示作者此前就玩过该游戏 → 「之前没有白旗」缺乏文本支撑
- ✅ 但作者的**时间相关性观察方向合理**，且被本机实测（24.0.5 已是白旗）部分佐证：白旗确实在 23.6 之后的某个点引入

### 五、CrossOver 的 DXVK 是【定制重编译版】
| 文件 | md5 | 说明 |
|---|---|---|
| CX 内置 `lib/wine/dxvk/d3d9.dll` | `10cb5e46…` | `cxaddon-1.10.3`，CrossOver 打过 patch |
| 上游 DXVK 1.9.2 x32/d3d9.dll | `2c0c6c2f…` | 与 CX 版**不同** |
| 上游 DXVK 1.10.3 x32/d3d9.dll | `d1b890a1…` | 与 CX 版**不同** |
| 上游 DXVK 2.0 x32/d3d9.dll | `2b296cd5…` | — |
| 上游 DXVK 2.4 x32/d3d9.dll | `675f0e99…` | — |
| `lib/wine/dxvk/d3d9.dll.bak2` | `faff641a…` | 2026-11-23 17:04 被换入的另一版本（非任何上游版）|
| wined3d `lib/wine/i386-windows/d3d9.dll` | `58a84642…` | Wine 9.0 自带 |

### 六、★ DXVK 官方确认接管 D3D9
bottle 内 `dxvkfiles.conf`（**CrossOver 官方生成**）：
```
"C:\\windows\\system32\\d3d9.dll" = "10cb5e466352b1049908de7e48ca9b25"
```
→ **CrossOver 24.0.5 默认就用 DXVK d9vk 覆盖 system32/d3d9.dll**（官方行为，非手工）。
→ 时间戳佐证：`d3d9.dll.orig` / `.dxvk.bak` = **2026-11-23 16:13**，`d3d9.dll` = **2026-11-24 11:34**（今天上午重装过一次）
→ ⇒ **用户 14:58 的白旗截图确实在 DXVK 下拍摄**。

### 七、实验④ 判读表（升级为矩阵）
| 切换到 | 结果 | 结论 | 行动 |
|---|---|---|---|
| **wined3d**（Wine 9.0 自带） | 旗帜**有颜色** | **DXVK d9vk 缺陷**，Wine 9.0 本身正常 | **保持 wined3d → 问题解决**（无需降级）|
| **wined3d** | 旗帜**仍白** | **Wine 9.0 层面回归** | 降级 CX 23.6（Wine 8.0.1）或升级 CX26 + 64 位 bottle |
| 上游 DXVK 1.10.3 原版 | 与 CX 定制版**表现不同** | CrossOver 的 patch 引入问题 | 用上游版 |
| 上游 DXVK 2.4 | 也白 | 与 25.1 一致，佐证文章 | — |

### 八、脚本
`ab_d3d9.sh` 已扩展为矩阵：`status | wined3d | dxvk110up | dxvk119 | dxvk24 | restore`
（自带 `d3d9.dll.orig.ab` 备份；已通过 `bash -n` 语法检查与 `status` 实测）

---

## 实验④-A：wined3d 对照（2026-11-24 16:10）—— ★ DXVK 嫌疑排除

### 操作
`./ab_d3d9.sh wined3d` → `system32/d3d9.dll` md5 `58a84642…`（CrossOver 自带，Wine 9.0 的 OpenGL 后端）
截图 `user_shots/shot_wined3d.jpg`（1920×1286，与基线同分辨率）

### 实测
| 对象 | 路径 | DXVK(d9vk) | **wined3d** | 判定 |
|---|---|---|---|---|
| 城内大吊旗 | 3D 网格 | 纯白(45%) | **纯白(48%)** | ❌ 仍白 |
| 张宝部队旗 | 3D 网格 | 纯白 | **纯白(32%)** | ❌ 仍白 |
| 濮阳城墙小旗 | 2D 贴图 | 黄 | **黄 (128,128,0)** | ✅ 正常 |

白色连通域（wined3d 截图，全图扫描）：`1820px @ (688,656) 59×65`（濮阳城内大吊旗）
+ `739px @ (1091,484) 31×74`（张宝部队旗）—— 与肉眼一致。

### ★★ 结论修正：不是 DXVK 的问题
> **DXVK d9vk（Vulkan）与 wined3d（OpenGL）两个完全不同的后端都渲染出白旗。**
> ⇒ 排除「DXVK 兼容缺陷」；罪魁在两者共用的层面（D3D9 语义实现 / 游戏侧 / 资源侧）。

### ★★ 更重要的发现：3D 渲染路径本身是好的
放大 `out/wd_3D城池大吊旗.png`：**同一画面内，3D 城墙的瓦片纹理、明暗立体感、旗杆金属灰全部正常着色**，
唯独**旗面是纯白**（连一点色调都没有）。
⇒ 不是「3D 路径整体坏掉」，而是「**旗帜这一个对象的势力色没被应用**」。

### 当前候选解释（收敛后）
| # | 假设 | 验证手段 |
|---|---|---|
| A | **CrossOver 的 `cxaddon-1.10.3` patch 有 bug** | 换**上游 DXVK 1.10.3 原版**（已下载，md5 d1b890a1…）|
| B | **d9vk 1.10.3 本身有回归** | 换**上游 DXVK 1.9.2**（md5 2c0c6c2f…）|
| C | **Wine 9.0 层面 / 游戏侧语义** | 上游 1.9.2 也白 → 转 DXVK API log / 降级 CX 23.6 |
| D | 旗帜靠「材质色 / 顶点色 / 顶点雾」传色，两个后端都漏 | WINEDEBUG=+d3d9 抓调用 |

### 下一步
第 1 轮优先测 **上游 DXVK 1.10.3**（一次实验同时区分 A 与 B/C）：
- 若**有色** → 是 CrossOver 的 patch 问题，**上游版即最终解**（无需降级 CrossOver）
- 若**仍白** → 测上游 1.9.2；仍白则锁定 C，转 API log / 降级 CX 23.6

---

## ★★★ 关键突破：注册表画质档与官方默认值不符（2026-11-24 16:20）

### 做法
把本机 `HKCU\Software\KOEI\San11PK Tc\San11Option`（**83 项**）与 fxxz 攻略文档给出的
**官方推荐注册表**逐项做二进制对比。

### ★ 结果：6 项不一致，其中 3 项直接关系到渲染
| 键 | 本机 | 官方默认 | 含义/风险 |
|---|---|---|---|
| **`GraphicsQuality`** | **0** | **2** | ★ **画质档：0=最低，2=最高。低档很可能走「简化/剪影渲染路径」，不传顶点色** |
| **`TextureDepth`** | **0** | **1** | ★ **纹理位深 0=16bit / 1=32bit。16bit 纹理在 Vulkan/GL 后端支持受限** |
| **`ScreenEffect`** | 0 | 1 | 屏幕特效开关 |
| `MipDistanceObj` | 0x96 (150) | 0x1f4 (500) | mip 距离（性能）|
| `ShowHexFrame` | 1 | 0 | 六角格框显示（纯显示）|
| `WindowMode` | 1 | 0 | 窗口/全屏（无关）|

**已改：`GraphicsQuality` 0 → 2**（其余保持不变，保持变量唯一）
备份：`~/.workbuddy/tmp/san11/user.reg.bak.20261124-1615`（104,614 bytes）
`d3d9.dll` 已 `./ab_d3d9.sh restore` 回 CrossOver 内置 DXVK（md5 `10cb5e46…`）
→ **本轮唯一变量 = 画质档**

### ★ 为什么这个假设能解释全部现象
| 现象 | 解释 |
|---|---|
| DXVK 与 wined3d **都**白 | 不是后端问题 —— 游戏自己按画质档选了简化渲染路径，根本没传颜色 |
| 2D 贴图旗正常 | 2D 路径不依赖 3D 顶点色/光照 |
| 3D 城墙/瓦片正常 | 剪影/简化路径下贴图仍正常，只有**顶点色**丢失 |
| 与 `StageModelSilhouetteSize/Color`（剪影）同区 | ★ 「StageModel 剪影」正是 3D 模型的简化渲染通道 |
| `EditVertexColors00/01/02` = 0x00ffffff | 官方默认也是纯白 → 是「不干预顶点色」而非「把顶点色刷白」，仍排除 |

### 下一轮候选（若画质档无效）
| # | 假设 | 手段 |
|---|---|---|
| E | `TextureDepth=0`（16bit 纹理） | 改 `TextureDepth` = 1 |
| F | 旗帜靠**顶点雾(FOGCOORD)**传色 —— DXVK issue #5470 证实原生 D3D9 与 DXVK 在「FVF 带 DIFFUSE 但无 SPECULAR + 开雾」时行为不同；MSDN 亦称启用照明时无顶点色的顶点颜色会被丢弃 | WINEDEBUG=+d3d9 抓调用 |
| G | 游戏侧按能力检测降级（每次启动覆盖 GraphicsQuality） | 游戏内选项菜单改画质（若存在）|
| H | 资源侧模型顶点色缺失 | KOVS/OBJS 模型块解析 |

### ★ 关键外部证据（DXVK issue #5470 / MSDN D3D9 排查文档）
> 「The affected draw call has: DrawPrimitiveUP, a line list. **FVF: XYZRHW | DIFFUSE, Fog enabled**」
> 「In the original game, this artifact did not surface, because their FVF also had a **SPECULAR color**」
> → 证实 **原生 D3D9 与开源后端在固定管线的 diffuse/specular/雾 组合上存在真实行为差异**。
MSDN：「默认情况下启用照明时，系统会将不包含法向量的任何顶点的颜色设置为 0（黑色）……渲染期间传递给 D3D 的任何颜色信息都将丢失」

---

## 实验④-B：画质档实验被启动脚本抵消（2026-11-24 16:20）

### ⚠️ 重要发现：启动脚本会还原注册表
`/Users/w.fish/wine_soft/san11pk/启动三国志11.command` 里有：
```bash
PRISTINE="$HOME/.workbuddy/tmp/san11/regbak/user.reg"
REG=".../Bottles/san11/user.reg"
[ -f "$PRISTINE" ] && cp -p "$PRISTINE" "$REG"
```
→ **每次启动前把注册表恢复成 `regbak/user.reg`（2026-11-23 17:29 的原始基线）**。
⇒ 上一轮直接改 `user.reg` 的 `GraphicsQuality=2` **在游戏启动瞬间就被覆盖**。
⇒ 16:14 那张截图跑的**仍是 GQ=0**（画面细节与基线一致，六角格来自 `ShowHexFrame=1`）。
⇒ **画质档假设尚未被真正测试过。**

**修正**：任何注册表实验必须同时改 `user.reg` **和** `regbak/user.reg`。
（已把两处都改成 GQ=2 试过一次，但为保持变量唯一又复位回 0；两处现已同步。）

### 本次截图（`user_shots/shot_gq2.jpg`，1924×1286）判定
| 对象 | 路径 | 结果 |
|---|---|---|
| 城内大吊旗 @(673,599) 60×68 | 3D | **白占比 47%** ❌ |
| 张宝部队旗 @(1111,454) 28×54 | 3D | **白占比 41%** ❌ |
| 须臾港港口旗 | 2D | 黄 (160,160,0) ✅ |

**注意**：这张图的 2D 旗区域仍能检出 6 个黄色块（826/278/276/238/220/210 px），
其中 x=1022..1060 y=220..251 是港口旗，其余是城墙小旗 → **2D 路径确实在跟随色号 41（黄）**。

### 新增能力：DXVK 原生 debug 日志
- 上游 DXVK 1.10.3 与 CrossOver 内置版**都支持** `DXVK_LOG_LEVEL` / `DXVK_LOG_PATH`
- ⇒ 可抓 `d3d9.log`（含 `SetVertexDeclaration` / `DrawIndexedPrimitive` / 顶点格式 / 渲染状态）
- 这是**直接回答「旗帜的顶点色到底有没有被写入」**的唯一硬证据

### 新增脚本
- `run_trace.sh upstream|wined3d|cxdxvk` —— 切换 d3d9 实现 + 开 DXVK 日志 + 启动游戏

### 下一步（一次运行拿三个答案）
```bash
cd ~/.workbuddy/tmp/san11
./run_trace.sh upstream      # 上游 DXVK 1.10.3 + 日志
```
游戏里走到濮阳城 → 关掉游戏 → 日志在 `dxvklog/upstream-*/d3d9.log`
1. 上游版旗帜**有颜色** → CrossOver 的 `cxaddon-1.10.3` patch 是元凶 → 保持上游版即解决
2. 上游版**仍白** → 彻底排除 DXVK → 进日志找顶点色写入点
3. 日志里若旗帜绘制用 `D3DFVF_DIFFUSE` 而缓冲区里顶点色是白 → 游戏侧问题

### ★ 关键时序修正（DXVK 安装时间线）
| 时间 | 事件 | 当时生效的 d3d9 |
|---|---|---|
| 11-23 16:13 | 有人把 DXVK 装进 system32（生成 `.orig`/`.dxvk.bak`）| — |
| **11-24 11:18** | **基线白旗截图 `shot_front.jpg` / `shot_side.jpg`** | **CrossOver 内置 DXVK**（`d3d9.dll.orig.ab` 时间戳 11:34 是我备份的，但内容同 md5）|
| 11-24 16:06 | wined3d 对照截图 `shot_wined3d.jpg` | wined3d |
| 11-24 16:10 | 恢复 DXVK（`d3d9.dll` 时间戳）| CrossOver 内置 DXVK |
| 11-24 16:14 | 最新截图 `shot_gq2.jpg` | CrossOver 内置 DXVK，**且 GQ 仍=0**（启动脚本还原了注册表）|

⇒ **基线与最新截图的 DXVK 完全同一版本、同一 md5** → 对照有效。

### ★ 全图彩色扫描（找是否存在「有颜色的 3D 旗」）
对 5 张截图做连通域扫描（sat>70 强彩色，剔除色号41 的黄）：
- 每张图的非黄彩色块 **全部**落在 UI/地名/桃花/部队纹理区域
- **没有任何一个彩色块落在 3D 旗帜位置**
- ⇒ 全图范围内，**3D 路径的旗帜从未呈现过任何颜色**（不只张角，是所有势力）
- ⇒ 这是**系统性的 3D 着色失效**，与具体势力/色号无关

### 已排除清单（累计）
| # | 假设 | 状态 |
|---|---|---|
| A | 势力色数据坏 | ❌ 2D 路径跟随正确 |
| B | 改色没生效 | ❌ 字节级确认 + 2D 已变 |
| C | 色号 41 本身接近白 | ❌ 41 = 黄色 (160,160,0) |
| D | DXVK d9vk 缺陷 | ❌ wined3d（完全不同的 OpenGL 后端）同样白 |
| E | CrossOver 的 cxaddon-1.10.3 patch | ❓ **待测**（上游原版已就位）|
| F | Wine 9.0 层面回归 | ❓ 待测（可降级 CX 23.6 验证）|
| G | 游戏资源/顶点色数据缺失 | ❓ 待测（DXVK 日志可见）|
| H | GraphicsQuality 画质档 | ❓ **实验被启动脚本抵消，尚未真正测过**（基线已修好）|

### 下一步：一次运行拿三个答案
```bash
cd ~/.workbuddy/tmp/san11
./run_trace.sh upstream     # 上游 DXVK 1.10.3 原版 + DXVK debug 日志
```
- 若旗帜**有颜色** → 锁定 E（CrossOver 的 patch），保持上游版即修复
- 若仍白 → 日志里看旗帜的 `SetVertexDeclaration` 是否含 `D3DFVF_DIFFUSE`、
  顶点缓冲区里的颜色值是不是白 → 锁定 G（游戏/资源侧）

---

## ★★★ 第 6 轮：根因彻底定位（2026-11-24 17:00-17:30）

### 决定性发现 1：此前所有「DXVK vs wined3d 对照」实验从未真正跑过 DXVK

- 全局 `DllOverrides` 表里有 `d3d10/d3d11/d3d10core = native,builtin`，
  **唯独没有 `d3d9`** → Wine 对 d3d9 一律走 builtin（wined3d）
- lsof 硬证据：游戏进程加载的是 `lib/wine/i386-windows/d3d9.dll`（wined3d），
  bottle system32 里的上游 DXVK **从未被加载过**
- ⇒ 之前"DXVK 1.10.3 vs wined3d 都白"的结论**无效**，已推翻
- ⇒ 修正方法：`wine --bottle san11 --dll d3d9=n` 强制 native 覆盖

### 决定性发现 2：真正的 DXVK 跑起来后，旗帜颜色正常

| 后端 | 是否真正加载 | 3D 旗帜颜色 | 结论 |
|---|---|---|---|
| wined3d (Wine 9.0 builtin) | ✅ | **纯白 ❌** | **真凶：wined3d 的 D3D9 固定管线顶点色处理缺陷** |
| 上游 DXVK 1.9.2 | ✅（强制 d3d9=n） | **正常 ✅** | 顶点色/光照链路本身没问题 |

**用户实测确认**（DXVK 1.9.2 下）：「旗帜颜色显示正常了」。

⇒ **白旗根因 = wined3d 的 D3D9 固定管线（FPP）顶点色处理缺陷**，与游戏数据、
   势力色号、CrossOver 的 cxaddon patch **全都无关**。

### 决定性发现 3：DXVK 1.10.3 / 2.x 在本机失败的原因 = MoltenVK 太旧

- 上游 DXVK 1.10.3：
  ```
  [mvk-error] Shader library compile failed:
  error: cannot reserve 'buffer' resource location at index 0
  fragment main0(... constant render_state_t& [[buffer(0)]],
                  constant D3D9FixedFunctionPS& consts [[buffer(0)]] ...)
  ```
  → d9vk 的 FPP 把 render_state 和 consts 放在**同一个 UBO slot**，MoltenVK 1.2.5 拒绝
- 上游 DXVK 2.4：设备创建即失败（**日志 0 行**），弹「DirectX初始化失败」
- 上游 DXVK 1.9.2：**0 个 mvk-error / 0 个 err**，完全正常

### 决定性发现 4：性能瓶颈 = 整条链路跑在 Rosetta 2 转译下

lsof 硬证据（DXVK 1.9.2 运行中）：
```
san11pk.exe → /Applications/CrossOver.app/.../lib64/libMoltenVK.dylib
            → /private/var/db/oah/.../libMoltenVK.dylib.aot   ← Rosetta AOT 缓存
```
- 本机 `uname -m` = **arm64**（M2 Pro），但
  `/Applications/CrossOver.app/Contents/MacOS/CrossOver` = **Non-fat x86_64**
- `libMoltenVK.dylib` 架构 = **x86_64**，`lipo -archs` 只有 x86_64
- ⇒ **整个 CrossOver（含 MoltenVK）都是 Intel 版，靠 Rosetta 2 转译运行**
- ⇒ 每个 draw call 都要 x86→arm 转译 → **这就是"非常卡"的根本原因**

DXVK 日志同时确认 MoltenVK 能力上限：
```
Apple M2 Pro:  Driver: 0.2.2013   Vulkan: 1.2.261   ← 只有 Vulkan 1.2
```

### 决定性发现 5：wined3d 为什么反而流畅

wined3d 走 **OpenGL/ANGLE → Metal** 路径，且 CrossOver 内置的 OpenGL 实现是
**arm64 原生**（不走 Rosetta），所以快；DXVK 走 **Vulkan → MoltenVK(x86_64) → Rosetta**，
所以慢。⇒ **旗帜正确与流畅，在当前 CrossOver 24.0.5 x86_64 下无法同时满足**。

### 已排除清单更新
| # | 假设 | 状态 |
|---|---|---|
| A | 势力色数据坏 | ❌ 2D 路径跟随正确 |
| B | 改色没生效 | ❌ 字节级确认 |
| C | 色号 41 接近白 | ❌ 41 = 黄 (160,160,0) |
| D | DXVK d9vk 缺陷 | ❌ **推翻**：真实 DXVK 下旗帜正常 |
| E | CrossOver cxaddon patch | ❌ **推翻**：真凶是 wined3d，非 DXVK |
| F | Wine 9.0 wined3d 回归 | ✅ **锁定**（wined3d 侧 FPP 顶点色缺陷） |
| G | 游戏资源/顶点色缺失 | ❌ DXVK 下正常 |
| H | GraphicsQuality 画质档 | ❌ 非因素 |
| **I** | **DXVK 在本机从未真正加载** | ✅ **推翻所有旧对照结论** |

### 解决路线（按可行性排序）
1. **装 arm64 原生版 CrossOver（26.3.0）** —— 唯一能同时摆脱 Rosetta + 拿到新 MoltenVK(Vulkan 1.3) 的路
2. 保持 CrossOver 24.0.5 + DXVK 1.9.2：旗帜正常但卡（当前状态）
3. 升级 MoltenVK 到 1.4.2（Vulkan 1.3）+ DXVK 2.x：**但仍是 x86_64 → 仍走 Rosetta，只能缓解不能根治**

---

## ★★★ 第 7 轮：Winery / Whisky 路线评估（2026-11-24 17:35-17:50）

### 架构普查结论（本机全部图形栈）
| 组件 | 路径 | 架构 |
|---|---|---|
| CrossOver 主程序 | `/Applications/CrossOver.app/Contents/MacOS/CrossOver` | **x86_64（非 fat）** |
| CrossOver MoltenVK | `lib64/libMoltenVK.dylib` | **x86_64** |
| CrossOver winevulkan.so | `lib/wine/x86_64-unix/winevulkan.so` | **x86_64** |
| CrossOver i386-unix/winelib.so | `lib/wine/i386-unix/winelib.so` | **x86_64** |
| CrossOver 全库扫描 arm64 | — | **0 个 arm64** |
| **Winery 2.0.4 主程序** | `/Applications/Kegworks Winery.app/Contents/MacOS/Winery` | **x86_64** |
| **Whisky 2.3.5 主程序** | `Whisky.app/Contents/MacOS/Whisky` | **arm64（纯原生）** |
| WhiskyCmd | `Whisky.app/Contents/Resources/WhiskyCmd` | **arm64** |

⇒ **本机 CrossOver 与 Winery 都是 Intel 版，全部跑在 Rosetta 2 下**；只有 Whisky 是 arm64 原生。

### Winery 已下载引擎清单
`~/Library/Application Support/Kegworks/Engines/`
- `WS12WineCX24.0.7.tar.7z`（CodeWeavers Wine 24.0.7）
- `WS12WineGPTK1.1_1.tar.7z`（Apple GPTK 1.1）— 内含 `d3dmetal_force` 标志
- `WS12WineKegworks10.0-battle.net.tar.7z`（Wine 10.0）

`IgnoredEngines.txt` 另列：`WS12WhiskyWine2.5.0_2`、`WS11Wine10.0_1`、`WS12WineCX23.7.1_3`、`WS11WineCX21.2.0`
⇒ **Winery 支持 Whisky 引擎**（`WS12WhiskyWine2.5.0_2`），但该引擎本地未下载。

### 三个引擎全部排除的原因（关键约束）
| 引擎 | unix 层架构 | 32 位 PE 支持 | 排除理由 |
|---|---|---|---|
| CX 24.0.7 | x86_64 | 有 | Rosetta，无性能收益；wined3d 顶点色 bug 依旧 |
| GPTK 1.1 | x86_64 | **无 `x86_32on64-windows` 目录** | **跑不了 32 位游戏**（游戏是 PE32） |
| Kegworks Wine 10.0 | x86_64 | 有 | Wine 10.0 的 wined3d 可能修好顶点色 bug，但仍 Rosetta |

### Whisky 路线现状
- Whisky 2.3.5 = **arm64 原生**（WhiskyCmd 也是 arm64），内置完整 DXVK 支持
  （`dxvkAsync` / `dxvk.conf` / `dxvkHud.fps` / `BottleDXVKConfig`）
- 引擎下载源 `https://data.getwhisky.app/Wine/Libraries.tar.gz` → **404（CDN 已下线）**
- `WhiskyWineVersion.plist` 同样 404
- GitHub 上无 `Whisky-App/Whisky-Wine` 仓库
- ⇒ **Whisky 引擎目前拿不到**，Whisky 2.3.5 是 GitHub 上的最新二进制版

### Gcenx macOS_Wine_builds
- 最新 tag `11.21`，资产**只有 `osx64`**（无 arm64）
- ⇒ Homebrew `wine-stable` cask 同样是 osx64，**不解决 Rosetta 问题**
- 但 Homebrew `formula` 有 **`molten-vk` 1.4.2（arm64 原生 bottle）** ← 唯一确认存在的 arm64 图形栈组件

### 游戏架构（硬约束）
- `san11pk.exe` = **PE32 (i386)**，32 位程序
- ⇒ 需要带 `i386-windows` + `i386-unix` 的 64 位 Wine（CrossOver/Winery 都有）
- ⇒ **无法使用纯 arm64 单架构 Wine**（Whisky 若只有 arm64 单切片也不够，除非它含 x86_32on64 PE 层）

### 结论：可行路线收敛为
1. **CrossOver 26.3.0**（下载中，387MB，官方支持 Apple Silicon + macOS 26）
   —— 需验证其 zip 内是否含 arm64 slice + 32 位 PE 层
2. **Homebrew arm64 molten-vk 1.4.2 + Wine 11（osx64）**
   —— 至少让 Vulkan→Metal 走 arm64 原生，减少转译层
3. **当前 CrossOver 24.0.5 + 上游 DXVK 1.9.2**（已可用，旗帜正常但卡）= 现状兜底

---

## ★★★ 第 8 轮：DXVK 组合穷举 + 终局方案确定（2026-11-24 18:00-18:40）

### 一、DXVK × MoltenVK 全组合实测矩阵

| DXVK | MoltenVK | 设备创建 | pipeline 编译 | 结论 |
|---|---|---|---|---|
| 1.9.2 | 定制 1.2.5 | ✅ | ✅ 0 失败 | 可用（但很卡） |
| **1.10.1** | **定制 1.2.5** | ✅ | ✅ 0 失败 | **✅ 最佳：旗帜正确 + 大地图 95 FPS** |
| 1.10.3 | 定制 1.2.5 | ✅ | ❌ 9 失败 | UBO 冲突 |
| 1.10.3 | 定制(cxaddon) | ✅ | ❌ 9 失败 | UBO 冲突 |
| 2.0 / 2.4 | 定制 1.2.5 | ❌ | — | Vulkan 版本不足 |
| 1.9.2 | 上游 1.2.6 / 1.2.9 / 1.3.0 / 1.4.2 | ❌ | — | feature 错误 |
| 1.10.1 / 1.10.3 / 2.0 / 2.4 | 上游 1.2.6 / 1.2.9 / 1.3.0 / 1.4.2 | ❌ | — | feature 错误 |

### 二、上游 MoltenVK 为什么一律不可用（精确错误）

```
[mvk-warn] VK_ERROR_FEATURE_NOT_PRESENT: Metal does not support buffer robustness.
[mvk-error] vkCreateDevice(): Requested physical device feature specified by the
            5th flag in VkPhysicalDeviceFeatures is not available on this device.
```
- 第 5 个 flag = **geometryShader**：MoltenVK 1.2.6+ 起把 Metal 3 mesh shader
  误报为传统 geometry shader；DXVK 读到 true→请求→创建时拒绝。
- **robustBufferAccess**：DXVK 强制要求；上游 MoltenVK 1.3/1.4 明确不支持
  （Apple Silicon 的 Metal 无 buffer robustness）。
- ⇒ **只有 CodeWeavers 定制 fork（1.2.5, 0.2.2013）同时满足两个条件**。

### 三、wined3d 顶点色 bug 与 Wine 版本无关（新增排除）

| Wine 版本 | 引擎来源 | 3D 大吊旗 | 城墙小旗 |
|---|---|---|---|
| 9.0 (Wine 11) | CrossOver 24.0.5 | **纯白 ❌** | 橙金 ✅ |
| 10.0 | Kegworks/Winery | **纯白 ❌** | 橙金 ✅ |
| 11.21 staging | Gcenx osx64 | **纯白 ❌** | 橙金 ✅ |

⇒ wined3d 的 FPP 顶点色缺陷是**长期存在的系统性问题**，升级 Wine 无法解决。
   （同一张放大截图里：城墙小旗橙金正常，只有 3D 大吊旗纯白 → 精确定位到
   顶点色通道，非贴图/势力色数据问题。）

### 四、最终可行方案（已落地）

**CrossOver 24.0.5 + DXVK 1.10.1 + CrossOver 定制 MoltenVK 1.2.5 + dxvk.conf**

- 旗帜颜色：✅ 正常（3D 大吊旗恢复势力色）
- 性能：✅ 大地图 **95 FPS**（标题画面 120 FPS），帧时间 9.8ms
- 关键：DXVK 1.10.1 比 1.9.2 快得多；`dxvk.conf`（numBackBuffers=1、
  presentInterval=1、maxFrameLatency=1、cachedDynamicBuffers=0）进一步降低开销
- 启动方式：`--dll d3d9=n`（全局 DllOverrides 无 d3d9 条目，必须命令行强制）

### 五、为什么曾经"非常卡"（完整因果链）

1. CrossOver 24.0.5 是 **x86_64 版** → 整个 Wine + MoltenVK 跑在 **Rosetta 2** 下
2. 32 位游戏 → 64 位 winevulkan → **wow64 Vulkan IPC** 每 draw call 一次跨进程调用
3. MoltenVK 1.2.5 是 2024-09 的老 Swift 实现，转译开销放大
4. ⇒ DXVK 1.9.2 + 无 dxvk.conf → 大地图 FPS 极低（用户体感"非常卡"）

### 六、本机所有可用 Wine 引擎的架构普查（无 arm64 原生）

| 引擎 | 架构 | 备注 |
|---|---|---|
| CrossOver 24.0.5 | x86_64 | Rosetta |
| Kegworks Wine 10.0 / CX 24.0.7 / GPTK 1.1 | x86_64 | Rosetta |
| WhiskyWine 2.5.0 | x86_64 | 且是 wine-7.7（很老） |
| Gcenx Wine Staging 11.21 | x86_64 | Rosetta |
| **Whisky 2.3.5 主程序** | **arm64** | 但引擎 CDN(data.getwhisky.app) 已 404 |
| Whisky 2.4.0 | — | 空 tag，只有源码 |
| Homebrew wine-stable cask | osx64 | Rosetta |
| Homebrew **molten-vk** formula | **arm64** ✅ | 但 x86_64 Wine 进程无法 dlopen arm64 dylib |

⇒ 要彻底摆脱 Rosetta 需要 arm64 原生 Wine，**本机可获取资源中暂缺**（唯一希望是
   CrossOver 26.3.0 若为 universal/arm64 包 —— 已启动下载待验证）。

---

## ★★★ 第 9 轮：卡顿根因定位 + 文档交付（2026-11-24 19:00-19:35）

### ★ 修正第 7 轮结论 5 的表述（原说法不够准确）

原文：「wined3d 走 OpenGL/ANGLE → Metal 路径，且 CrossOver 内置的 OpenGL 实现是
**arm64 原生**（不走 Rosetta），所以快」

**修正为**：wined3d 的 OpenGL **后端确实是 arm64 原生**，但**中间转发层仍是 x86_64**：

```
wined3d 路径：
  i386-windows/d3d9.dll
  → i386-windows/opengl32.dll
  → x86_64-unix/opengl32.so        (x86_64, 641KB 薄转发层)
  → AppleMetalOpenGLRenderer       ★ arm64 原生扩展（真干活的是它）
  → Metal

DXVK 路径：
  system32/d3d9.dll (DXVK)
  → winevulkan.so                  (x86_64)
  → libMoltenVK.dylib              (x86_64, 6.4MB 完整 Vulkan 实现) ★ 全程 Rosetta
  → Metal
```

关键差异不在「有没有 Rosetta」，而在 **Rosetta 转译的是哪一层**：
- opengl32.so 是 641KB 薄壳，真正的 GL→Metal 编译在 arm64 原生扩展里完成
- libMoltenVK 是 6.4MB 完整 Vulkan 栈，**每一次 Vulkan 调用都要 x86→arm 转译**

### ★ 决定性证据：同一游戏、同一场景的 sample 对比

| 采样对象 | AppleMetalOpenGLRenderer | libMoltenVK | vkWaitForFences |
|---|---|---|---|
| **wined3d 路径** | **54 次命中** | 1（仅映射表） | **0** |
| **DXVK 路径** | 0 | 45 | **200** |

DXVK 路径 `dxvk-queue` 线程栈：
```
+ 345 NtWaitForAlertByThreadId (in ntdll.so)
+   207 __wine_unix_call_dispatcher (in ntdll.so)
+     200 vkWaitForFences (in libMoltenVK.dylib)
```
⇒ CPU 有 **62% 时间阻塞在等 GPU fence**；wined3d 路径 **0 次**。

### ★ DXVK 1.10.1 无异步管线编译（5 版本全查）
`strings` 扫 async：1.9.2 / 1.10.1 / 1.10.3 / 2.0 / 2.4 **全部 0 命中**
⇒ UI 界面新状态组合会**同步编译着色器管线** → 顿挫。

### ★ dxvk.conf 两条键确认无效
`d3d9.cachedDynamicBuffers` / `d3d9.samplerLodBias` 在 1.10.1 的 `d3d9.*` 键全集中
**不存在**（但日志 "Effective configuration" 仍回显 → 极易误判）。

### ★ macOS 27 上 OpenGL.framework 符号链接断裂
`/System/Library/Frameworks/OpenGL.framework/OpenGL` → broken symbolic link，
实际渲染由 arm64 原生扩展 `AppleMetalOpenGLRenderer` 承担。

### ★ 本轮新工具
- `clickc.py` —— 纯 ctypes 点击工具（不依赖 Quartz）。坑：
  `CFStringGetCString` **成功时返回 0**；`CFStringCreateWithCString` 第3参是 encoding 传 0。
- `启动三国志11-高效模式.command` —— wined3d 高效模式启动器（`--dll d3d9=b`）

### 交付物
- 文档：`/Users/w.fish/wine_soft/san11pk/docs/三国志11_macOS_渲染问题排查与解决方案.md`
- 两个启动命令均已实测通过（lsof 确认加载正确的 d3d9 + 后端，DXVK 路径 0 错误）
