# nvim-config-windows 调试与维护手册

> 这份文档面向**维护者 / 后续排障者（包括 AI 助手）**：讲清楚这个仓库怎么运作、出问题怎么查、
> 改完怎么验证、怎么重新打包发布。
> 普通安装使用请看 [README.md](README.md)。

---

## 0. 当前状态速览

| 项目 | 值 |
| --- | --- |
| 仓库 | https://github.com/jianghao629/nvim-config-windows |
| 发布版 | `v1.0.0`（2026-11-14） |
| 离线包 | `nvim-config-offline-1.0.0-windows-x64.zip` · 78,516,151 B · SHA-256 `0ac35396f86b6fcdf0a0b8a2bb43e88321515b426e456a533b85b91a21f96b18` |
| 配套 Linux 仓库 | https://github.com/jianghao629/nvim-config（定位问题时可对照，很多逻辑同源） |
| 验证程度 | 二进制/脚本/配置逻辑已充分验证；**尚未在真实 Windows 机器上跑过 `nvim.exe` 端到端**（见 §9） |

---

## 1. 关键路径速查（安装后）

| 内容 | 路径 |
| --- | --- |
| Neovim 配置 | `%LOCALAPPDATA%\nvim` |
| 数据目录 | `%LOCALAPPDATA%\nvim-data` |
| 插件 | `%LOCALAPPDATA%\nvim-data\lazy`（22 个） |
| 离线路径清单 | `%LOCALAPPDATA%\nvim-data\offline_paths.txt` |
| LSP / 工具 | `%LOCALAPPDATA%\nvim-data\bin\tools\{clangd,lua-language-server,stylua,rg,fd}` |
| 便携版 Neovim | `%LOCALAPPDATA%\nvim-config\nvim\bin\nvim.exe` |
| `nvim` 命令 shim | `%LOCALAPPDATA%\nvim-config\bin\nvim.cmd` |
| 字体 | `%LOCALAPPDATA%\Microsoft\Windows\Fonts\MapleMono-NF-CN-*.ttf` + `HKCU\...\CurrentVersion\Fonts` |
| Windows Terminal 片段 | `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\nvim-config\settings.json` |
| PowerShell 片段（可选） | `$PROFILE.CurrentUserAllHosts` 里的 `# >>> nvim-config >>>` 块 |
| DeepSeek key | `%USERPROFILE%\.config\deepseek\api_key`（或环境变量 `DEEPSEEK_API_KEY`） |
| 安装备份 | 上述目录的 `.bak-<yyyyMMdd-HHmmss>` / `.removed-<...>` 兄弟目录 |

本机（打包机）仓库位置：`/home/jianghao/deepseek harness/nvim-config-windows`（Linux 上构建 Windows 包）。

---

## 2. 工作原理

### 2.1 启动链

```
%LOCALAPPDATA%\nvim\init.lua
  └─ require("core.offline")   -- 读 offline_paths.txt，把工具目录加进 vim.env.PATH，并置 vim.g.nvim_config_offline = true
  └─ require("core.basic")     -- 基础选项
  └─ require("core.lazy")      -- lazy.nvim 引导 + 插件加载（启动时禁止联网检查）
       └─ lua/plugins/*.lua    -- 每个插件一个 spec
```

### 2.2 离线机制（改这些地方前先读）

| 机制 | 位置 | 说明 |
| --- | --- | --- |
| 离线标记 + PATH 注入 | `nvim/lua/core/offline.lua` | 只认 `<stdpath("data")>/offline_paths.txt`；文件不存在 = 在线模式（git clone 安装） |
| 生成离线清单 | `install.ps1` §3 | 把 `tools\{clangd\bin, lua-language-server\bin, stylua, rg, fd}` 写进 `offline_paths.txt`（UTF-8 无 BOM） |
| 禁止启动联网 | `nvim/lua/core/lazy.lua` | `checker.enabled=false`、`install.missing=false`、`change_detection.enabled=false` |
| 跳过 mason 联网安装 | `nvim/lua/plugins/mason.lua` | `vim.g.nvim_config_offline == true` 时不 require `mason-registry`，只用 `vim.lsp.config/enable` |
| 跳过 stylua 联网安装 | `nvim/lua/plugins/none-ls.lua` | 同上；stylua 走 PATH（离线清单注入） |
| 无 key 不加载补全 | `nvim/lua/plugins/copilot.lua` | `enabled = api_key ~= nil`，key 从 `DEEPSEEK_API_KEY` 或 `~/.config/deepseek/api_key` 读 |
| blink 模糊匹配 | `nvim/lua/plugins/blink.lua` | Windows 用 `fuzzy.implementation = "lua"`，不下载 Rust 库 |
| fzf 扩展缺失回退 | `nvim/lua/plugins/telescope.lua` | `pcall(load_extension("fzf"))`，Windows 没有 `libfzf.dll` 也能用 |

> **坑（已踩过）**：Neovim 的 `stdpath("data")` 在 Linux 上是 `$XDG_DATA_HOME/nvim`，
> 在 Windows 上是 `%LOCALAPPDATA%\nvim-data`。做隔离测试时路径拼错会让 lazy 找不到插件、
> 进而触发 `git clone` 联网卡住（看起来像“启动卡死”）。

### 2.3 install.ps1 执行顺序

0. 基础检查（LOCALAPPDATA、nvim/init.lua、curl.exe 提示、解除脚本 MOTW）
1. 复制配置 → `%LOCALAPPDATA%\nvim`（先备份旧的）
2. 复制插件 `deps\lazy` → `%LOCALAPPDATA%\nvim-data\lazy`（先备份）
3. 复制工具 `deps\tools` → `%LOCALAPPDATA%\nvim-data\bin\tools`，写 `offline_paths.txt`
4. 复制便携版 Neovim → `%LOCALAPPDATA%\nvim-config\nvim`；生成 `nvim.cmd`；加用户 PATH
5. 字体：先复制文件，再写 `HKCU` 注册表 + `AddFontResourceW` + 广播 `WM_FONTCHANGE`
6. 复制 Windows Terminal 片段
7. （可选 `-ShellProfile`）写 PowerShell profile 片段
8. 创建 `%USERPROFILE%\.config\deepseek`（只放示例，不写真实 key）
9. 验证：`nvim.exe --headless` 打印插件数；`require('lazy').load(...)` 验证 LSP 配置；检查 LSP 工具版本
10. 输出摘要

### 2.4 离线包布局（zip 解压后）

```
nvim-config-offline-<ver>-windows-x64/
├─ install.ps1 / install.bat / uninstall.ps1 / check.ps1
├─ README.md / DEBUG.md / LICENSE / THIRD_PARTY.md / THIRD_PARTY/
├─ MANIFEST.txt                  # 版本、22 个插件 commit、字体哈希、工具大小
├─ nvim/                         # 配置源码（= 安装后的 %LOCALAPPDATA%\nvim）
├─ env/                          # fonts / windows-terminal / powershell / deepseek 示例
└─ deps/
   ├─ nvim/                      # nvim-win64（bin/nvim.exe ...）
   ├─ lazy/                      # 22 个插件（无 .git、无 Linux 编译产物）
   └─ tools/{clangd,lua-language-server,stylua,rg,fd}
```

> 注：`v1.0.0` 的 Release 资产构建时还没有本文档；下次重新打包会把它一起放进包内。

---

## 3. 构建（在 Linux / WSL 上）

```bash
cd nvim-config-windows
./package.sh                       # 产物 dist/nvim-config-offline-<VERSION>-windows-x64.zip + SHA256SUMS
VERSION=1.0.1 ./package.sh         # 新版本
CACHE=/path/to/cache ./package.sh  # 自定义下载缓存（默认 .cache/）
```

构建机需要：`curl unzip zip python3 rsync`，以及**本机已安装的 Linux 版插件目录**
（默认 `~/.local/share/nvim/lazy`，可用 `LIVE_LAZY=` 覆盖）。

### 3.1 版本变量 ↔ 下载缓存文件

| 变量（package.sh 顶部） | 默认值 | 缓存文件名（`.cache/`） |
| --- | --- | --- |
| `NVIM_VERSION` | `v0.11.6` | `nvim-win64-$NVIM_VERSION.zip` |
| `CLANGD_VERSION` | `23.1.0` | `clangd-windows-$CLANGD_VERSION.zip` |
| `LUALS_VERSION` | `3.19.2` | `lua-language-server-$LUALS_VERSION-win32-x64.zip` |
| `STYLUA_VERSION` | `v2.6.0` | `stylua-windows-x86_64-$STYLUA_VERSION.zip` |
| `RG_VERSION` | `15.2.0` | `ripgrep-$RG_VERSION-x86_64-pc-windows-msvc.zip` |
| `FD_VERSION` | `v10.5.2` | `fd-$FD_VERSION-x86_64-pc-windows-msvc.zip` |

下载走 `GH_PROXY`（默认 `https://gh-proxy.com/`，可覆盖）。改版本号后旧缓存文件名不匹配会自动重新下载。

### 3.2 构建时对插件做的处理

- 从 Linux 版 `lazy/` 复制，排除 `.git`
- 删掉 `blink.cmp/target`（Linux 的 `.so` / version 文件）
- 删掉 `telescope-fzf-native.nvim/build`（Linux 的 `libfzf.so`）

### 3.3 构建产物自检（改完 package.sh 必跑）

```bash
cd dist
sha256sum -c SHA256SUMS
ZIP=nvim-config-offline-1.0.0-windows-x64.zip
unzip -l "$ZIP" | head; unzip -l "$ZIP" | tail -2
for f in deps/nvim/bin/nvim.exe deps/tools/clangd/bin/clangd.exe \
         deps/tools/lua-language-server/bin/lua-language-server.exe \
         deps/tools/stylua/stylua.exe deps/tools/rg/rg.exe deps/tools/fd/fd.exe \
         install.ps1 install.bat check.ps1 MANIFEST.txt; do
  unzip -l "$ZIP" "nvim-config-offline-1.0.0-windows-x64/$f" >/dev/null && echo "OK $f" || echo "MISS $f"
done
```

---

## 4. 发布流程

1. 构建并自检（§3），记录 `SHA256SUMS`；
2. 推仓库：`git push origin main`（本机已配置 SSH 凭据，不要提交任何私钥）；
3. 发布临时用 GitHub OAuth Device Flow 获取一个有 `repo` 权限的 token（GitHub CLI 的公开 client id，
   `POST https://github.com/login/device/code` 拿 code → 浏览器授权 → 换 token），
   **用完立刻撤销**（`DELETE /applications/{client_id}/grant`），不要写进仓库或日志；
4. 创建 Release 并上传资产（API）：
   - `POST https://api.github.com/repos/<owner>/<repo>/releases`
     `{"tag_name":"v1.0.0","target_commitish":"main","name":"...","body":"...","draft":false}`
   - `POST https://uploads.github.com/repos/<owner>/<repo>/releases/<id>/assets?name=<file>`，
     `Content-Type: application/octet-stream`，`--data-binary @file`（zip 与 SHA256SUMS 各传一次）；
5. 校验：`GET .../releases/<id>` 里每个 asset 的 `state=uploaded`、`size`、
   `digest == "sha256:<本地 sha256>"`；
6. 版本号约定：资产文件名带 `<VERSION>`，tag `v<VERSION>`，`MANIFEST.txt` 里也记录版本。

> 上传速度参考：本机到 `uploads.github.com` 约 **2 MB/s**（75 MB 约 40 s）。
> 下载（`objects.githubusercontent.com`）在部分网络下很慢，README 里已给出 gh-proxy 镜像写法。

---

## 5. 本地快速迭代（不重新打包）

### 5.1 改 Neovim 配置（最快）

直接改目标机 `%LOCALAPPDATA%\nvim` 下的文件，或临时用隔离目录：

```powershell
$env:XDG_CONFIG_HOME = "D:\test\config"   # 配置会写到 D:\test\config\nvim
$env:XDG_DATA_HOME   = "D:\test\data"     # 数据会写到 D:\test\data\nvim
nvim
```

### 5.2 在 Linux 上验证 Windows 版配置（无需 Windows）

```bash
export XDG_CONFIG_HOME=/tmp/wintest/config
export XDG_DATA_HOME=/tmp/wintest/data
export XDG_STATE_HOME="${XDG_STATE_HOME:-/tmp/wintest/state}"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME/nvim" "$XDG_STATE_HOME/nvim"
cp -a nvim "$XDG_CONFIG_HOME/nvim"
ln -s "$HOME/.local/share/nvim/lazy" "$XDG_DATA_HOME/nvim/lazy"   # 注意：data 下是 nvim/lazy
mkdir -p /tmp/wintest/toolsbin && printf '#!/bin/sh\necho fake-stylua\n' > /tmp/wintest/toolsbin/stylua && chmod +x /tmp/wintest/toolsbin/stylua
echo /tmp/wintest/toolsbin > "$XDG_DATA_HOME/nvim/offline_paths.txt"
nvim --headless \
  "+lua print('OFFLINE='..tostring(vim.g.nvim_config_offline))" \
  "+lua print('PATH_HAS='..tostring((vim.env.PATH or ''):find('/tmp/wintest/toolsbin',1,true)~=nil))" \
  "+lua print('PLUGINS='..#vim.fn.readdir(vim.fn.stdpath('data')..'/lazy'))" "+qa"
```

预期：`OFFLINE=true`、`PATH_HAS=true`、`PLUGINS=22`。

强制加载插件并检查报错（headless 下 `VeryLazy` 不会自动触发，要手动触发）：

```bash
nvim --headless \
  "+lua require('lazy').load({plugins={'mason.nvim','none-ls.nvim','blink.cmp','telescope.nvim','copilot-deepseek.nvim'}})" \
  "+lua vim.defer_fn(function() print('MESSAGES:'); print(vim.fn.execute('messages')); print('LSP='..#vim.lsp.get_clients()); vim.cmd('qa!') end, 3000)"
```

### 5.3 验证 install.ps1 / check.ps1（Linux + PowerShell 7 模拟）

把 PowerShell 7 的 linux tar.gz 解压到 `/tmp/pwsh` 后：

```bash
# 语法解析
/tmp/pwsh/pwsh -NoProfile -Command '$e=$null; [System.Management.Automation.Language.Parser]::ParseFile("install.ps1",[ref]$null,[ref]$e) | Out-Null; if ($e.Count) { $e; exit 1 } else { "OK" }'

# 模拟安装（假 LOCALAPPDATA/USERPROFILE；字体注册表/Windows 专属步骤会失败并被脚本容错）
# 在解压后的 nvim-config-offline-* 目录里执行
HOME=/tmp/fakewin/home LOCALAPPDATA=/tmp/fakewin/home/AppData/Local \
USERPROFILE=/tmp/fakewin/home SystemRoot=/tmp/fakewin/home/Windows \
  /tmp/pwsh/pwsh -NoProfile -File install.ps1 -NoVerify -ShellProfile
```

期望生成：`nvim/`、`nvim-data/lazy`（22 个）、`nvim-data/bin/tools/*`、`offline_paths.txt`（5 行）、
`nvim-config/bin/nvim.cmd`、字体 ttf 复制、Windows Terminal 片段、PS profile 片段。
> Linux 上会报 “字体注册失败：Cannot find drive HKCU…”，这是**预期**（Windows 才有 HKCU）。

---

## 6. 调试命令

### Windows / Neovim

```powershell
nvim --version
nvim --headless "+lua print(vim.inspect(vim.version()))" +qa
nvim --headless "+lua print('PLUGINS=' .. #vim.fn.readdir(vim.fn.stdpath('data') .. '/lazy'))" +qa
nvim -V16D:\nvim-debug.log          # 详细启动日志，退出后看日志
```

Neovim 里：

```vim
:messages            " 启动/插件报错都这里
:checkhealth          " LSP、剪贴板、provider 体检
:Lazy                 " 插件状态；:Lazy profile 看加载耗时
:scriptnames          " 加载了哪些脚本
:lua vim.print(vim.lsp.get_clients())
:lua print(vim.g.nvim_config_offline)
:lua print(vim.fn.readfile(vim.fn.stdpath('data') .. '/offline_paths.txt'))
:lua print(vim.env.PATH)
```

### PowerShell / 安装

```powershell
.\check.ps1                       # 一键体检（版本/路径/插件/LSP/字体/WT/ key）
Start-Transcript D:\install.log   # 记录安装输出
.\install.bat 2>&1 | Tee-Object -FilePath D:\install.log
$env:PATH                         # 确认 nvim-config\bin 在
Get-Command nvim
(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts').PSObject.Properties.Name -like 'Maple Mono NF CN*'
Get-ChildItem "$env:LOCALAPPDATA\nvim-data\bin\tools" -Recurse -Filter *.exe | Select-Object FullName
```

---

## 7. 故障排查矩阵

| 症状 | 优先检查 | 处理 |
| --- | --- | --- |
| `nvim` 命令找不到 | `$env:PATH`、`%LOCALAPPDATA%\nvim-config\bin\nvim.cmd` 是否存在 | 重开终端；重跑 `install.ps1`（默认会写 PATH，不要加 `-NoPath`）；或直接用完整路径 |
| 启动报 `lazy.nvim 未安装且无法联网下载` | `%LOCALAPPDATA%\nvim-data\lazy\lazy.nvim` 是否存在 | 重新解压安装包并 `install.bat`；或联网 + git 后 `:Lazy sync` |
| 启动卡很久/卡死 | 是否误把 `lazy` 放错层级（`stdpath('data')` 是 `nvim-data`）→ 触发 git clone | 核对 §2.2 的“坑”；断网时 lazy 无插件目录会尝试 clone 并失败 |
| 插件列表少/报错 `E5108` | `:messages`；插件目录是否 22 个 | 重装；检查 `lazy-lock.json` 与 `deps/lazy` 是否一致 |
| AI 补全不出现 | key 文件/环境变量、`curl.exe`、网络 | 见 README §三；`<M-CR>` 手动开面板；`:messages` 看 copilot 报错 |
| LSP 不启动 | `offline_paths.txt` 是否存在且指向存在的目录；`tools` 下 exe 是否存在 | 重跑 `install.ps1`；`:checkhealth`；`.\check.ps1` |
| clangd 能启动但 C 头文件报错 | clangd 的 `lib\clang` 是否随包保留 | 不要只拷 `clangd.exe`，保留 `tools\clangd\{bin,lib}` 结构 |
| 字体列表没有 Maple Mono NF CN | 注册表项、`%LOCALAPPDATA%\Microsoft\Windows\Fonts` | 注销/重启；或右键 ttf 安装；`install.ps1` 的字体段是否报错 |
| Windows Terminal 外观没变 | 片段路径、WT 版本（需支持 Fragments）、是否重启 | 删 `Fragments\nvim-config` 可恢复；确认 JSON 合法 |
| 中文乱码 | 终端编码/字体 | `chcp 65001`；字体是否生效 |
| 复制粘贴不可用 | Windows 原生剪贴板，一般无需配置 | 确认不是 SSH/远程会话；`win32yank.exe` 在 nvim.exe 同目录 |
| 安装脚本被策略拦截 | ExecutionPolicy | 用 `install.bat`（已带 `-ExecutionPolicy Bypass`）或同参数手动执行 |
| 字体/PATH 写入失败 | 受限用户环境 | 脚本已做容错：字体文件仍会复制，按提示手动注册；PATH 失败可手动加 |
| `package.sh` 某个下载失败 | 网络/镜像 | 重跑（缓存续传）；或手动下载放到 `.cache/` 对应文件名 |
| 解压后缺东西 | zip 完整性 | `certutil -hashfile ... SHA256` 对比 `SHA256SUMS` |

---

## 8. 已知限制

1. **未在真实 Windows 上端到端验证**（构建/验证都在 Linux 完成）。首次上机请按 §9 清单跑一遍。
2. blink.cmp 用 Lua 模糊匹配：功能一致、大项目补全略慢；想要 Rust 版需在 Windows 上装 Rust 工具链后 `cargo build --release`。
3. Telescope 没有 fzf 原生扩展：排序弱一些；要启用需装 cmake + MSVC（或 MSYS2 gcc）后 `:Lazy build telescope-fzf-native.nvim`。
4. mason.nvim 离线时不访问 registry：`:Mason` UI 在离线机器上不可用（不影响 LSP 本身）。
5. 更新插件需要网络 + git（`git` 不在离线包内）。
6. 包内二进制是 x64 的；ARM64 Windows 需要另选 arm64 资产重建（package.sh 需加 ARM 分支）。

---

## 9. 回归测试清单（每次改配置/脚本/构建后）

**本地（Linux）**

- [ ] `bash -n package.sh`
- [ ] 配置 Lua 语法：`cd nvim && nvim --headless -u NONE "+lua for _,f in ipairs(vim.fn.glob('**/*.lua',false,true)) do assert(loadfile(f)) end print('LUA_OK')" +qa`
- [ ] Windows 配置代理测试（§5.2）：OFFLINE/PATH/PLUGINS 与强制加载插件无报错
- [ ] `./package.sh` 成功，`sha256sum -c SHA256SUMS`
- [ ] zip 内容断言（§3.3）
- [ ] PowerShell 语法：install/uninstall/check + profile snippet 四个文件
- [ ] 模拟安装（§5.3）退出码 0，且 `offline_paths.txt` 5 行、`nvim.cmd` 内容正确、字体已复制
- [ ] `install.bat` 是 **CRLF 且无 BOM**（用 `file`/`python3` 检查）

**Windows 真机（首次/大改后）**

- [ ] 解压 zip → `install.bat` 退出码 0，无 `[error]`
- [ ] 新开 Windows Terminal → `nvim` 正常打开，`:Lazy` 显示 22 个插件
- [ ] `.\check.ps1`：插件 22、LSP 三项有版本、字体已注册、WT 片段存在
- [ ] 打开 `.lua` 文件出现诊断/补全（lua_ls）；打开 `.c` 文件 clangd 启动
- [ ] `<Tab>` / `<M-CR>` AI 补全（需要 key+网络）；断网时启动无报错
- [ ] 字体在 Windows Terminal 中生效；中文正常
- [ ] `uninstall.ps1` 后配置/片段被移走，原配置在 `.removed-*` 里

---

## 10. 踩坑与修复记录（防止回归）

| 日期 | 问题 | 原因 | 修复 | 守护测试 |
| --- | --- | --- | --- | --- |
| 2026-11-14 | `install.bat` 第一行被 cmd 报错 | 先加了 UTF-8 BOM，cmd 不认；后来又变 LF | 重写为 **UTF-8 无 BOM + CRLF** | §9 的 CRLF/BOM 检查 |
| 2026-11-14 | 安装时复制插件/工具崩溃 `Cannot find path ...\*` | `Copy-Item -LiteralPath (Join-Path $Src '*')` 中 `LiteralPath` 不展开通配符 | 改成 `Get-ChildItem -LiteralPath $Src -Force \| ForEach-Object { Copy-Item ... }` | 模拟安装必须成功 |
| 2026-11-14 | 字体在受限环境安装失败时直接中断安装 | 注册表创建在文件复制之前，且无 try/catch | 先复制字体文件，再在 try/catch 内注册；失败只告警 | 模拟安装（Linux 上注册必失败）+ 检查 ttf 已复制 |
| 2026-11-14 | `Unblock-File` 在非 Windows/受限环境抛错导致脚本退出 | cmdlet 平台差异 + 未捕获 | `try { Unblock-File ... } catch {}` | 模拟安装无该报错 |
| 2026-11-14 | `check.ps1` 解析失败 | 把 `if (...) {...} else {...}` 直接当命令参数用 | 先赋值给变量再 `Show-Item` | §9 语法检查 |
| 2026-11-14 | `check.ps1` 字体检查输出 `Get-Member` 报错 | 注册表键不存在时管道收到 `$null` | 先判断对象再 `Get-Member` | 模拟运行 check.ps1 |
| 2026-11-14 | 排查时 nvim 启动“卡死” | 隔离测试把 lazy 放在 `XDG_DATA_HOME/lazy`，实际应为 `XDG_DATA_HOME/nvim/lazy`，导致触发 git clone | 修正测试脚本路径 | §5.2 代理测试 |

---

## 11. 组件版本清单

| 组件 | 版本 | 来源 |
| --- | --- | --- |
| Neovim | v0.11.6 | https://github.com/neovim/neovim/releases |
| clangd | 23.1.0 | https://github.com/clangd/clangd/releases |
| lua-language-server | 3.19.2 | https://github.com/LuaLS/lua-language-server/releases |
| stylua | v2.6.0 | https://github.com/JohnnyMorganz/StyLua/releases |
| ripgrep | 15.2.0 | https://github.com/BurntSushi/ripgrep/releases |
| fd | v10.5.2 | https://github.com/sharkdp/fd/releases |
| 插件 | 见 `nvim/lazy-lock.json` | 与 Linux 版共用 |

完整第三方许可见 [THIRD_PARTY.md](THIRD_PARTY.md)。

---

## 12. 给后续 AI 助手 / 维护者的提示

- 本仓库的 Windows 包是**在 Linux 上交叉组合官方 Windows 二进制**得到的；改动后必须重跑 §9 的本地清单。
- **不要提交** `dist/`、`.cache/`、`*.zip`、token、`%LOCALAPPDATA%` 下的备份；仓库 `.gitignore` 已排除。
- 修改 `install.ps1` 后，务必：加 UTF-8 BOM + CRLF → pwsh 解析 → 模拟安装 → 重新打包并校验 zip 内文件。
- 修改 `nvim/` 后，务必做 §5.2 的离线代理测试；确认没有引入启动时联网行为。
- 发布资产一旦上传就不要原地替换（校验和/用户缓存会乱）；发新版请用新版本号。
- 同一套配置逻辑在 Linux 仓库（[nvim-config](https://github.com/jianghao629/nvim-config)）也有对应实现和
  [DEBUG 文档](https://github.com/jianghao629/nvim-config/blob/main/DEBUG.md)，两边改动尽量同步。
- 排障时优先收集：`.\check.ps1` 输出 + `:messages` + `nvim -V16` 日志 + 安装时 Transcript。
