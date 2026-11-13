#!/usr/bin/env bash
# ============================================================================
# 维护者脚本：构建 Windows 版「离线开箱即用」发布包
#
# 在 Linux / WSL / Git Bash 上运行；需要网络下载 Windows 版二进制（会缓存到 .cache/）。
#
# 用法:
#   ./package.sh                       # 打 dist/nvim-config-offline-<VERSION>-windows-x64.zip
#   VERSION=1.0.1 ./package.sh         # 指定版本号
#   LIVE_LAZY=/path/to/lazy ./package.sh   # 指定插件目录（默认 ~/.local/share/nvim/lazy）
#
# 说明:
#   - 插件目录复制自本机 Linux 版 Neovim 的 lazy 目录（去掉 .git 与 Linux 编译产物），
#     与 Linux 离线包共用同一套 lazy-lock.json 版本。
#   - Neovim / clangd / lua-language-server / stylua / ripgrep / fd 的 Windows 版
#     从 GitHub Releases 下载（经 gh-proxy 镜像）并缓存。
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${VERSION:-1.0.0}"
NVIM_VERSION="${NVIM_VERSION:-v0.11.6}"
CLANGD_VERSION="${CLANGD_VERSION:-23.1.0}"
LUALS_VERSION="${LUALS_VERSION:-3.19.2}"
STYLUA_VERSION="${STYLUA_VERSION:-v2.6.0}"
RG_VERSION="${RG_VERSION:-15.2.0}"
FD_VERSION="${FD_VERSION:-v10.5.2}"
CACHE="${CACHE:-$REPO_DIR/.cache}"
DIST="$REPO_DIR/dist"
LIVE_LAZY="${LIVE_LAZY:-$HOME/.local/share/nvim/lazy}"
GH_PROXY="${GH_PROXY:-https://gh-proxy.com/}"

STAGE_ROOT="$(mktemp -d /tmp/nvim-config-win-pkg.XXXXXX)"
TMP="$(mktemp -d /tmp/nvim-config-win-unzip.XXXXXX)"
STAGE="$STAGE_ROOT/nvim-config-offline-$VERSION-windows-x64"
trap 'rm -rf "$STAGE_ROOT" "$TMP"' EXIT

log()  { printf '\033[1;34m[package]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

for cmd in curl unzip zip python3 rsync; do
    command -v "$cmd" >/dev/null 2>&1 || die "缺少命令: $cmd"
done
[ -d "$LIVE_LAZY" ] || die "本机没有 $LIVE_LAZY；请先在本机安装好插件（Linux 版 nvim 启动一次或 :Lazy sync）"

mkdir -p "$CACHE" "$DIST" "$STAGE/deps"

download() { # download <url> <dest>
    local url="$1" dest="$2"
    if [ -s "$dest" ]; then
        log "使用缓存: $(basename "$dest")"
        return 0
    fi
    log "下载: $(basename "$dest")"
    mkdir -p "$(dirname "$dest")"
    curl -fL --retry 3 -m 3600 "$url" -o "$dest"
}

ghurl() { echo "${GH_PROXY}https://github.com/$1"; }

# ---------------------------------------------------------------------------
# 1) 仓库内容
# ---------------------------------------------------------------------------
log "复制仓库内容..."
cp -a "$REPO_DIR/nvim" "$STAGE/nvim"
cp -a "$REPO_DIR/env" "$STAGE/env"
[ -d "$REPO_DIR/THIRD_PARTY" ] && cp -a "$REPO_DIR/THIRD_PARTY" "$STAGE/THIRD_PARTY"
for f in install.ps1 install.bat uninstall.ps1 check.ps1 README.md LICENSE THIRD_PARTY.md; do
    [ -e "$REPO_DIR/$f" ] && cp -a "$REPO_DIR/$f" "$STAGE/$f"
done

# ---------------------------------------------------------------------------
# 2) 便携版 Neovim（Windows x64）
# ---------------------------------------------------------------------------
NVIM_ZIP="$CACHE/nvim-win64-$NVIM_VERSION.zip"
download "$(ghurl "neovim/neovim/releases/download/$NVIM_VERSION/nvim-win64.zip")" "$NVIM_ZIP"
log "解压 Neovim $NVIM_VERSION..."
unzip -q "$NVIM_ZIP" -d "$TMP/nvim"
[ -d "$TMP/nvim/nvim-win64" ] || die "nvim-win64.zip 结构异常"
mv "$TMP/nvim/nvim-win64" "$STAGE/deps/nvim"
[ -f "$STAGE/deps/nvim/bin/nvim.exe" ] || die "deps/nvim/bin/nvim.exe 不存在"

# ---------------------------------------------------------------------------
# 3) 插件（复用 Linux 版已安装插件，去掉平台相关产物）
# ---------------------------------------------------------------------------
log "复制插件（$(ls "$LIVE_LAZY" | wc -l) 个）..."
rsync -a --exclude='.git' "$LIVE_LAZY/" "$STAGE/deps/lazy/"

# Linux 平台编译产物：Windows 上用不到（blink 走 Lua 实现，fzf 原生扩展回退）
rm -rf "$STAGE/deps/lazy/blink.cmp/target"
rm -rf "$STAGE/deps/lazy/telescope-fzf-native.nvim/build"
# 个别插件目录里可能残留的 git 元数据
find "$STAGE/deps/lazy" -maxdepth 2 -name '.git' -type d -exec rm -rf {} + 2>/dev/null || true

# ---------------------------------------------------------------------------
# 4) LSP / 格式化 / 搜索工具（Windows 版）
# ---------------------------------------------------------------------------
TOOLS="$STAGE/deps/tools"
mkdir -p "$TOOLS"

# clangd
CLANGD_ZIP="$CACHE/clangd-windows-$CLANGD_VERSION.zip"
download "$(ghurl "clangd/clangd/releases/download/$CLANGD_VERSION/clangd-windows-$CLANGD_VERSION.zip")" "$CLANGD_ZIP"
log "解压 clangd $CLANGD_VERSION..."
unzip -q "$CLANGD_ZIP" -d "$TMP/clangd"
clangd_top="$(find "$TMP/clangd" -mindepth 1 -maxdepth 1 -type d | head -1)"
[ -n "$clangd_top" ] || die "clangd zip 结构异常"
mv "$clangd_top" "$TOOLS/clangd"
[ -f "$TOOLS/clangd/bin/clangd.exe" ] || die "clangd/bin/clangd.exe 不存在"

# lua-language-server
LUALS_ZIP="$CACHE/lua-language-server-$LUALS_VERSION-win32-x64.zip"
download "$(ghurl "LuaLS/lua-language-server/releases/download/$LUALS_VERSION/lua-language-server-$LUALS_VERSION-win32-x64.zip")" "$LUALS_ZIP"
log "解压 lua-language-server $LUALS_VERSION..."
mkdir -p "$TOOLS/lua-language-server"
unzip -q "$LUALS_ZIP" -d "$TOOLS/lua-language-server"
[ -f "$TOOLS/lua-language-server/bin/lua-language-server.exe" ] || die "lua-language-server/bin/lua-language-server.exe 不存在"

# stylua
STYLUA_ZIP="$CACHE/stylua-windows-x86_64-$STYLUA_VERSION.zip"
download "$(ghurl "JohnnyMorganz/StyLua/releases/download/$STYLUA_VERSION/stylua-windows-x86_64.zip")" "$STYLUA_ZIP"
log "解压 stylua $STYLUA_VERSION..."
unzip -q "$STYLUA_ZIP" -d "$TMP/stylua"
stylua_exe="$(find "$TMP/stylua" -type f -name 'stylua.exe' | head -1)"
[ -n "$stylua_exe" ] || die "stylua.exe 不存在"
mkdir -p "$TOOLS/stylua"
cp -a "$stylua_exe" "$TOOLS/stylua/stylua.exe"

# ripgrep
RG_ZIP="$CACHE/ripgrep-$RG_VERSION-x86_64-pc-windows-msvc.zip"
download "$(ghurl "BurntSushi/ripgrep/releases/download/$RG_VERSION/ripgrep-$RG_VERSION-x86_64-pc-windows-msvc.zip")" "$RG_ZIP"
log "解压 ripgrep $RG_VERSION..."
unzip -q "$RG_ZIP" -d "$TMP/rg"
rg_exe="$(find "$TMP/rg" -type f -name 'rg.exe' | head -1)"
[ -n "$rg_exe" ] || die "rg.exe 不存在"
mkdir -p "$TOOLS/rg"
cp -a "$rg_exe" "$TOOLS/rg/rg.exe"
find "$TMP/rg" -iname 'LICENSE*' -type f -exec cp -a {} "$TOOLS/rg/" \; 2>/dev/null || true

# fd
FD_ZIP="$CACHE/fd-$FD_VERSION-x86_64-pc-windows-msvc.zip"
download "$(ghurl "sharkdp/fd/releases/download/$FD_VERSION/fd-$FD_VERSION-x86_64-pc-windows-msvc.zip")" "$FD_ZIP"
log "解压 fd $FD_VERSION..."
unzip -q "$FD_ZIP" -d "$TMP/fd"
fd_exe="$(find "$TMP/fd" -type f -name 'fd.exe' | head -1)"
[ -n "$fd_exe" ] || die "fd.exe 不存在"
mkdir -p "$TOOLS/fd"
cp -a "$fd_exe" "$TOOLS/fd/fd.exe"
find "$TMP/fd" -iname 'LICENSE*' -type f -exec cp -a {} "$TOOLS/fd/" \; 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5) MANIFEST（版本 / 提交清单）
# ---------------------------------------------------------------------------
log "生成 MANIFEST.txt..."
{
    echo "nvim-config Windows 离线开箱即用包"
    echo "version:        $VERSION"
    echo "built:          $(date -Iseconds)"
    echo "target:         windows-x64 (Windows 10 1809+ / Windows 11)"
    echo "neovim:         $NVIM_VERSION (portable)"
    echo "clangd:         $CLANGD_VERSION (windows)"
    echo "lua-language-server: $LUALS_VERSION (win32-x64)"
    echo "stylua:         $STYLUA_VERSION (windows-x86_64)"
    echo "ripgrep:        $RG_VERSION (x86_64-pc-windows-msvc)"
    echo "fd:             $FD_VERSION (x86_64-pc-windows-msvc)"
    echo
    echo "===== plugins（来自 lazy-lock.json）====="
    python3 - "$STAGE/nvim/lazy-lock.json" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    data = {}
for name in sorted(data):
    info = data[name] or {}
    print(f"{name:32s} {info.get('branch','?'):8s} {info.get('commit','?')}")
PY
    echo
    echo "===== fonts ====="
    for f in "$STAGE"/env/fonts/*.ttf; do
        [ -f "$f" ] || continue
        printf '%-40s %s\n' "$(basename "$f")" "$(sha256sum "$f" | cut -d' ' -f1)"
    done
    echo
    echo "===== tools ====="
    for exe in "$TOOLS/clangd/bin/clangd.exe" "$TOOLS/lua-language-server/bin/lua-language-server.exe" \
               "$TOOLS/stylua/stylua.exe" "$TOOLS/rg/rg.exe" "$TOOLS/fd/fd.exe" "$STAGE/deps/nvim/bin/nvim.exe"; do
        if [ -f "$exe" ]; then
            printf '%-70s %10s bytes\n' "${exe#"$STAGE/"}" "$(stat -c%s "$exe")"
        else
            printf '%-70s MISSING\n' "${exe#"$STAGE/"}"
        fi
    done
} > "$STAGE/MANIFEST.txt"

# ---------------------------------------------------------------------------
# 6) 打 zip
# ---------------------------------------------------------------------------
OUT="$DIST/nvim-config-offline-$VERSION-windows-x64.zip"
log "压缩 -> $OUT"
rm -f "$OUT"
( cd "$STAGE_ROOT" && zip -r -9 -q "$OUT" "$(basename "$STAGE")" )
( cd "$DIST" && sha256sum "$(basename "$OUT")" > SHA256SUMS )

log "完成: $OUT（$(du -h "$OUT" | cut -f1)）"
log "校验: $DIST/SHA256SUMS"
log "上传: 把 zip 和 SHA256SUMS 上传到 GitHub Releases 即可"
