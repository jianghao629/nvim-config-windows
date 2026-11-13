# nvim-config-windows

我的 Neovim 配置 **Windows 版** —— 目标是 **换台 Windows 电脑、甚至没有网络，解压安装即可用**。

与 [Linux 版 nvim-config](https://github.com/jianghao629/nvim-config) 使用同一套配置和插件版本，
针对 Windows 调整了路径、LSP 分发方式和终端环境。仓库里除配置外还包含字体、Windows Terminal
配置片段和 **离线开箱即用包**（Releases 里下载，安装全程不需要联网）。

- 配置目录：`nvim/`（安装后等于 `%LOCALAPPDATA%\nvim`）
- 插件管理器：[lazy.nvim](https://github.com/folke/lazy.nvim)（22 个插件）
- 补全：[blink.cmp](https://github.com/saghen/blink.cmp) + [DeepSeek AI 补全](https://github.com/jianghao629/copilot-deepseek.nvim)
- LSP：`clangd`（C/C++）、`lua-language-server`（Lua）、`stylua`（格式化）
- 主题：[tokyonight.nvim](https://github.com/folke/tokyonight.nvim)（moon）
- 字体：Maple Mono NF CN（等宽 + 中文 + Nerd Font 图标，SIL OFL 1.1）
- 终端环境：Windows Terminal 字体/配色/透明背景配置片段、可选 PowerShell profile 片段

---

## 一、快速开始

### 方式 A：离线包（推荐，全程无需联网）

1. 打开 [Releases](https://github.com/jianghao629/nvim-config-windows/releases) 下载
   `nvim-config-offline-<版本>-windows-x64.zip`；
2. 解压到任意目录（例如 `D:\nvim-config-offline`）；
3. 双击 `install.bat`（或 `右键 -> 使用 PowerShell 运行 install.ps1`）；
4. 重新打开一个 **Windows Terminal** 窗口，执行：

   ```powershell
   nvim
   ```

离线包里已经打包好：配置、22 个插件、LSP/格式化工具（Windows 版）、字体、
便携版 Neovim、`rg`/`fd`。安装和日常使用都不需要网络。

> 系统要求：Windows 10 1809+ / Windows 11（x64）。
> 无需管理员权限，所有内容安装在当前用户目录。
> SmartScreen 提示“Windows 已保护你的电脑”时，点“更多信息 → 仍要运行”。
> 若双击 install.bat 提示脚本被禁止运行，可在当前目录执行：
> `powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1`

> **下载慢？** GitHub Releases 直连有时很慢，可以在下载地址前加镜像前缀，例如：
> `https://gh-proxy.com/https://github.com/jianghao629/nvim-config-windows/releases/download/v1.0.0/nvim-config-offline-1.0.0-windows-x64.zip`
> 下载后可用 `certutil -hashfile <文件> SHA256` 与 `SHA256SUMS` 核对。

### 方式 B：git clone（已联网、系统已有 Neovim 0.11+ 和 git）

```powershell
git clone https://github.com/jianghao629/nvim-config-windows.git
cd nvim-config-windows
.\install.bat    # 或 powershell -ExecutionPolicy Bypass -File .\install.ps1
nvim             # 首次启动时 lazy.nvim 会联网下载插件
```

### 安装脚本做了什么

- 备份已有的 `%LOCALAPPDATA%\nvim`（重命名为 `nvim.bak-<时间>`），再安装本仓库的 `nvim/`；
- 离线包会把插件装到 `%LOCALAPPDATA%\nvim-data\lazy`，LSP/工具装到
  `%LOCALAPPDATA%\nvim-data\bin\tools`，并生成 `offline_paths.txt` 让 Neovim 启动时自动加入 PATH；
- 便携版 Neovim 装到 `%LOCALAPPDATA%\nvim-config\nvim`，创建 `nvim` 命令并加入用户 PATH；
- 按用户安装字体（`%LOCALAPPDATA%\Microsoft\Windows\Fonts` + 当前用户字体注册表，无需管理员）；
- 安装 Windows Terminal 配置片段（字体 Maple Mono NF CN 14、Tokyo Night Moon 配色、92% 透明）；
- 创建 `%USERPROFILE%\.config\deepseek` 目录和 API key 示例（**绝不写入真实密钥**）；
- 最后用 `nvim --headless` 做一次启动验证，并检查各 LSP 工具版本。

可用参数：

| 参数 | 说明 |
| --- | --- |
| `-NoFonts` | 不安装字体 |
| `-NoTerminal` | 不导入 Windows Terminal 配置片段 |
| `-NoPath` | 不把 `nvim` 命令目录加入用户 PATH |
| `-ShellProfile` | 把 `EDITOR=nvim` / `vim` 别名写入 PowerShell profile（默认不写） |
| `-NoVerify` | 跳过安装后的启动验证 |

---

## 二、按键速查

Leader 键是 **空格**。

| 按键 | 功能 |
| --- | --- |
| `<Tab>` | **接受 AI 补全**（有 ghost text 时；没有则交给 blink.cmp 补全/跳转） |
| `<M-CR>`（Alt+Enter） | 打开 AI 补全面板 |
| `<C-]>` | 关闭 AI 补全 |
| `<Space>e` | 文件树（nvim-tree） |
| `<Space>bh` / `<Space>bl` | 上一个 / 下一个 buffer |
| `<Space>bd` | 关闭当前 buffer |
| `<Space>lf` | 格式化当前文件（stylua） |
| `<Space>lr` / `<Space>lc` | 重命名 / code action |
| `<Space>ld` / `<Space>lh` | 跳转定义 / 悬浮文档 |
| `<Space>lR` | LSP finder |
| `<Space>ln` / `<Space>lp` | 下一个 / 上一个诊断 |
| `jk` | 插入模式下快速回到普通模式 |
| `:Telescope find_files` / `:Telescope live_grep` | 查找文件 / 全文搜索 |

---

## 三、AI 补全（DeepSeek）

补全通过 [`copilot-deepseek.nvim`](https://github.com/jianghao629/copilot-deepseek.nvim)
调用 DeepSeek 的 FIM 接口，**需要网络 + DeepSeek API key**（Windows 10 1803+ 自带 `curl.exe`）。
没有 key 时插件自动禁用，Neovim 其他功能完全不受影响；断网时补全请求失败但不会影响编辑。

配置 API key（任选其一）：

```powershell
# 1) 本地文件（推荐，install.ps1 已创建目录）
Set-Content -Path "$env:USERPROFILE\.config\deepseek\api_key" -Value "sk-你的key" -NoNewline

# 2) 用户环境变量（优先级最高）
[Environment]::SetEnvironmentVariable("DEEPSEEK_API_KEY", "sk-你的key", "User")
```

参数在 `nvim/lua/plugins/copilot.lua`：

- `model = "deepseek-flash"`（可选 `deepseek-v4-pro`）
- `max_tokens = 256`，`max_lines = 4`（补全最多 4 行，短小风格）
- `keymap.accept = "<Tab>"`，`trigger_on_accept = false`（Tab 只在有 ghost text 时接受）

---

## 四、环境配置说明

### 字体

`env/fonts/` 内是 **Maple Mono NF CN** 的 Regular/Bold 字重（等宽、中文全字符、
Nerd Font 图标），许可为 SIL OFL 1.1（见 `env/fonts/OFL.txt`）。
`install.ps1` 会按用户安装（无需管理员）：复制到
`%LOCALAPPDATA%\Microsoft\Windows\Fonts` 并写入
`HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts`，同时广播字体变更消息。
如果字体列表里没看到，注销一次或重启即可。

### Windows Terminal

`env/windows-terminal/nvim-config.fragment.json` 会被安装成 Windows Terminal 的
**配置片段**（Fragments），内容：

- 所有 profile 的默认字体：`Maple Mono NF CN`，字号 14
- 配色方案：`Tokyo Night Moon (nvim-config)`（取自 tokyonight.nvim 官方 Windows Terminal extras）
- 背景 92% 透明 + 亚克力效果、光标形状竖线

重启 Windows Terminal 生效。不想要这些效果时，删除
`%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\nvim-config` 目录即可；
只想保留部分效果，可直接编辑该目录下的 `settings.json`。

### PowerShell

`env/powershell/Profile.snippet.ps1` 是可选片段（`EDITOR=nvim`、`vim`/`vi` 别名）。
默认不写入；需要时用 `.\install.ps1 -ShellProfile` 安装，或手动把片段内容粘贴到 `$PROFILE`。

### 命令与工具

- `nvim` 命令：`%LOCALAPPDATA%\nvim-config\bin\nvim.cmd` 会被加入用户 PATH（新终端生效）；
- `rg` / `fd`：离线包内附带的 Windows 版，安装到 `%LOCALAPPDATA%\nvim-data\bin\tools\rg|fd`，
  由 `offline_paths.txt` 自动加入 Neovim 的 PATH（Telescope 搜索使用）；
- 剪贴板：Windows 版 Neovim 原生支持系统剪贴板，不需要额外工具。

---

## 五、目录结构

```
nvim/                    Neovim 配置（= %LOCALAPPDATA%\nvim）
  init.lua
  lua/core/basic.lua     基础选项
  lua/core/offline.lua   离线包 PATH 注入（install.ps1 生成 offline_paths.txt）
  lua/core/lazy.lua      插件管理器（已关闭启动时联网检查）
  lua/plugins/*.lua      各插件配置（一个插件一个文件）
  lazy-lock.json         插件版本锁定
env/
  fonts/                 Maple Mono NF CN 字体 + OFL 许可
  windows-terminal/      Windows Terminal 配置片段
  powershell/            PowerShell profile 可选片段
  deepseek/              API key 示例（不含真实 key）
install.ps1              安装脚本（离线/在线通用）
install.bat              双击入口（调用 install.ps1）
uninstall.ps1            卸载脚本（保守：只移走不删除）
check.ps1                体检脚本（排查问题用）
package.sh               维护者脚本：在 Linux/WSL 上打 Windows 离线 zip
THIRD_PARTY.md           第三方组件与许可证
deps/                    仅离线包中存在：nvim/ + lazy/ + tools/
MANIFEST.txt             仅离线包中存在：版本与提交清单
```

离线包模式下 `lua/core/lazy.lua` 关闭了 lazy.nvim 的自动更新检查
（`checker.enabled = false`、`install.missing = false`），
且 `lua/plugins/mason.lua` / `none-ls.lua` 检测到离线标志后不会访问 mason registry，
保证断网启动没有任何网络请求。需要更新插件时手动执行 `:Lazy sync`（需联网 + git）。

### 与 Linux 版的差异

| 项目 | Linux 版 | Windows 版 |
| --- | --- | --- |
| 插件 | 一样（同一 `lazy-lock.json`） | 一样 |
| LSP 分发 | masonry 目录结构 | 直接随包附带 exe，用 `offline_paths.txt` 注入 PATH |
| blink.cmp 模糊匹配 | Rust 加速库 | Lua 实现（功能一致，速度略慢） |
| telescope fzf 原生扩展 | 已编译 `libfzf.so` | 未附带（需要 cmake+MSVC 才能编译），自动回退默认排序器 |
| 字体安装 | 复制到 `~/.local/share/fonts` + `fc-cache` | 按用户安装到 `%LOCALAPPDATA%\Microsoft\Windows\Fonts` + 注册表 |
| 终端配置 | GNOME Terminal dconf | Windows Terminal 配置片段 |
| 剪贴板 | xclip / wl-copy | 系统原生支持 |

---

## 六、更新与重新打包

- 更新插件：联网后在 Neovim 里执行 `:Lazy sync`；更新后的提交会写入
  `nvim/lazy-lock.json`（记得提交到仓库）。
- 重新生成 Windows 离线包（维护者，在 Linux 或 WSL 上执行，需要网络下载 Windows 版二进制）：

  ```bash
  VERSION=1.0.1 ./package.sh
  # 产物: dist/nvim-config-offline-1.0.1-windows-x64.zip + SHA256SUMS
  ```

  插件目录取自本机已安装的 `~/.local/share/nvim/lazy`（Linux 版 Neovim 的插件），
  Neovim/clangd/lua-language-server/stylua/rg/fd 的 Windows 版会按清单下载并缓存到 `.cache/`。
- 发布：在 GitHub Releases 上传 `dist/nvim-config-offline-*.zip` 和 `SHA256SUMS`。

---

## 七、卸载

```powershell
.\uninstall.ps1           # 移走配置/Windows Terminal 片段/离线清单（加 .removed-<时间> 后缀）
.\uninstall.ps1 -Purge    # 同时移走插件、LSP、便携版 Neovim，并从用户 PATH 移除
```

卸载不会直接删除文件；字体需要到 `设置 -> 字体` 或
`%LOCALAPPDATA%\Microsoft\Windows\Fonts` 手动移除。

---

## 八、安全说明

- 仓库与离线包 **不包含任何 API key、SSH 私钥或密码**；
  DeepSeek key 从环境变量或 `%USERPROFILE%\.config\deepseek\api_key` 读取，位于仓库之外。
- 安装脚本不需要管理员权限，也不会修改系统级设置；所有改动都在当前用户目录。
- 离线包安装后不访问网络；在线模式下 lazy.nvim 只在用户显式执行 `:Lazy sync` 时联网。
- 所有插件、LSP、字体、工具的来源见 `THIRD_PARTY.md`。

## 九、常见问题

| 问题 | 处理 |
| --- | --- |
| SmartScreen 拦截 / “Windows 已保护你的电脑” | 更多信息 → 仍要运行；或右键 zip → 属性 → 解除锁定后再解压 |
| PowerShell 说“禁止运行脚本” | 用 `install.bat`（内部已加 `-ExecutionPolicy Bypass`），或手动执行同名命令 |
| 字体没生效 | 注销/重启一次；`设置 -> 个性化 -> 字体` 里搜索 Maple Mono NF CN |
| Windows Terminal 没变化 | 重启 Windows Terminal；确认已安装较新版本（支持 Fragments）；删除片段目录可恢复 |
| `nvim` 命令找不到 | 安装时用了 `-NoPath`，或当前终端还没刷新 PATH；重新打开终端，或直接用 `%LOCALAPPDATA%\nvim-config\bin\nvim.cmd` |
| LSP 没反应 | 运行 `.\check.ps1` 看工具版本；`:checkhealth` 查看详情；确认 `%LOCALAPPDATA%\nvim-data\bin\tools` 存在 |
| AI 补全没出现 | 检查 key 与网络；确认 `curl.exe` 存在（Win10 1803+ 自带）；`<M-CR>` 可手动打开面板 |
| Telescope 找文件/搜索奇怪 | 确认 `rg.exe`/`fd.exe` 在 `%LOCALAPPDATA%\nvim-data\bin\tools`，并运行 `.\check.ps1` |
| 中文显示成方块 | 字体未生效，见上；Windows Terminal 里也确认字体设置 |

## 十、调试与维护

Windows 真机排障、重新打包、发布流程、已知限制和回归测试清单整理在 **[DEBUG.md](DEBUG.md)**；
Linux 版对应文档见 [nvim-config DEBUG.md](https://github.com/jianghao629/nvim-config/blob/main/DEBUG.md)。

---

## 十一、致谢与许可

- 配置与脚本：MIT（见 `LICENSE`）
- 字体 Maple Mono NF CN：SIL OFL 1.1（见 `env/fonts/OFL.txt`）
- 所有插件、LSP、命令行工具归其作者所有，见 [`THIRD_PARTY.md`](THIRD_PARTY.md)
- AI 补全后端：[copilot-deepseek.nvim](https://github.com/jianghao629/copilot-deepseek.nvim)
  （基于 [zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua) 改造）
- Linux 版配置：[jianghao629/nvim-config](https://github.com/jianghao629/nvim-config)
