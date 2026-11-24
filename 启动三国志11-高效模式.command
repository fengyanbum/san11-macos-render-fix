#!/bin/bash
# 三国志11 加强版 — 高效模式（wined3d / OpenGL 后端）
#
# 与「启动三国志11.command」的区别：
#   启动三国志11.command  → --dll d3d9=n → DXVK 1.10.1 → Vulkan → MoltenVK
#                              ✅ 3D 大吊旗势力色正常   ⚠️ UI 界面偶有顿挫
#   本脚本                  → --dll d3d9=b → builtin wined3d → OpenGL
#                              ❌ 3D 大吊旗纯白         ✅ 运行最流畅
#
# 原理：--dll d3d9=b 让 Wine 强制使用 builtin wined3d，
#       完全忽略 bottle system32/d3d9.dll 里的 DXVK。
#       ⇒ 与方案一可随时来回切换，无需替换任何文件。
#
# 白旗原因：wined3d 的 D3D9 固定管线（FPP）顶点色处理缺陷，
#           势力色通过顶点色传递 → 被丢弃 → 3D 大吊旗纯白。
#           该缺陷与 Wine 版本无关（9.0 / 10.0 / 11.21 全部复现），无法配置绕过。
#
# 切换回旗帜正确版：直接双击「启动三国志11.command」即可。
cd "$(dirname "$0")" || exit 1

CX="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
TMP="$HOME/.workbuddy/tmp/san11"
BOTTLE="$HOME/Library/Application Support/CrossOver/Bottles/san11"
export CX_BOTTLE=san11
export LANG=zh_TW.UTF-8
export LC_ALL=zh_TW.UTF-8

# 关掉可能残留的旧实例
pkill -f "san11pk.exe" 2>/dev/null
sleep 1

# ------------------------------------------------------------------
# 注册表：默认不动（保留你游戏里改过的设置）。
# 需要回到出厂基线时，用 SAN11_RESET_REG=1 启动一次即可。
# ------------------------------------------------------------------
REG="$BOTTLE/user.reg"
PRISTINE="$TMP/regbak/user.reg"
if [ "${SAN11_RESET_REG:-0}" = "1" ] && [ -f "$PRISTINE" ]; then
  cp -p "$PRISTINE" "$REG" 2>/dev/null
  echo "[高效模式] 注册表已重置为基线"
fi

# ------------------------------------------------------------------
# 注意：这里不安装/不修改 system32/d3d9.dll。
# --dll d3d9=b 会让 Wine 直接使用 builtin wined3d，
# system32 里放的是 DXVK 还是别的，都不会在本模式下被加载。
# 因此本模式与「旗帜正确模式」可以随时来回切换，互不影响。
# ------------------------------------------------------------------

echo "[高效模式] 使用 wined3d (OpenGL → arm64 原生 AppleMetalOpenGLRenderer)"
echo "[高效模式] 3D 大吊旗会显示纯白（wined3d 固有缺陷），其余功能正常"

"$CX/bin/wine" --bottle san11 --dll d3d9=b ./san11pk.exe "$@"
