#!/bin/bash
# 三国志11 加强版 (San11PK) — macOS + CrossOver 启动器
#
# 原理：
#   1) bottle san11 已设为 zh-TW(ACP=950/Big5)，游戏主程序已打补丁把
#      D3D 模式查找尺寸从 1024x768 改为 1280x800（Mac 显示模式列表无 1024x768）。
#   2) 旗帜白化根因：CrossOver 默认让 Wine 用 builtin wined3d 渲染 D3D9，
#      而 wined3d 的固定管线顶点色处理有缺陷 → 3D 大吊旗失去势力色变纯白。
#      解决：强制 d3d9=native，交给 DXVK 1.10.1 渲染。
#      注意：全局 DllOverrides 里没有 d3d9 条目，所以必须用 --dll d3d9=n。
#   3) DXVK 需配合 MoltenVK；CrossOver 自带的定制 MoltenVK 1.2.5 是唯一
#      与 DXVK 兼容的版本（上游 1.2.6+ 会误报 geometryShader 并移除
#      robustBufferAccess，导致 vkCreateDevice 失败）。
#   4) dxvk.conf 降低每帧缓冲/同步开销（放在游戏目录，DXVK 自动读取）。
#
# 回滚（旗帜变白 / 想要原样）：
#   cp "$BOTTLE/drive_c/windows/system32/d3d9.dll.orig" \
#      "$BOTTLE/drive_c/windows/system32/d3d9.dll" && 删除启动参数 --dll d3d9=n
#   d3d9.dll.orig 是 CrossOver 自带的原始 DXVK。
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
  echo "[启动器] 注册表已重置为基线"
fi

# ------------------------------------------------------------------
# 确保 bottle 内 system32/d3d9.dll 是 DXVK 1.10.1 (x32)
# ------------------------------------------------------------------
DXVK_DLL="$TMP/dxvk/dxvk-1.10.1/x32/d3d9.dll"
SYS_DLL="$BOTTLE/drive_c/windows/system32/d3d9.dll"
# DXVK 1.10.1 x32 d3d9.dll 的 sha256
DXVK_SHA="bd4e0b3a91f8a45e4c8ff000238b872043fea9afa7a7ba1d82e3cd18f7d65ff7"

cur_sha=""
[ -f "$SYS_DLL" ] && cur_sha=$(shasum -a 256 "$SYS_DLL" 2>/dev/null | awk '{print $1}')

if [ "$cur_sha" = "$DXVK_SHA" ]; then
  : # 已经是正确的 DXVK 1.10.1，无需处理
elif [ -f "$DXVK_DLL" ]; then
  [ -f "$SYS_DLL" ] && cp -p "$SYS_DLL" "$SYS_DLL.prev" 2>/dev/null
  install -m 0755 "$DXVK_DLL" "$SYS_DLL"
  echo "[启动器] 已安装 DXVK 1.10.1 (x32) 到 bottle"
else
  echo "[启动器] 警告：bottle 内 d3d9.dll 不是 DXVK 1.10.1，且找不到安装源"
  echo "          $DXVK_DLL"
  echo "          旗帜可能变白。可用 d3d9.dll.orig 回滚。"
fi

# 可选：设置 DXVK_HUD=fps 打开帧率显示；设为空则关闭
export DXVK_HUD="${DXVK_HUD:-}"
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"

"$CX/bin/wine" --bottle san11 --dll d3d9=n ./san11pk.exe "$@"
