#Requires -Version 5.1
<#
.SYNOPSIS
    nvim-config Windows 安装脚本（离线开箱即用）

.DESCRIPTION
    安装内容（全部在当前用户目录，不需要管理员权限）：
      * Neovim 配置        -> %LOCALAPPDATA%\nvim
      * 插件 / 数据         -> %LOCALAPPDATA%\nvim-data
      * LSP / 格式化工具    -> %LOCALAPPDATA%\nvim-data\bin\tools
      * 便携版 Neovim       -> %LOCALAPPDATA%\nvim-config\nvim（+ nvim 命令）
      * 字体                -> %LOCALAPPDATA%\Microsoft\Windows\Fonts（注册到当前用户）
      * Windows Terminal 片段 -> %LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\nvim-config
      * DeepSeek key 目录   -> %USERPROFILE%\.config\deepseek

.PARAMETER NoFonts
    不安装字体（Maple Mono NF CN）。

.PARAMETER NoTerminal
    不导入 Windows Terminal 字体/配色片段。

.PARAMETER NoPath
    不把 nvim 命令目录加入用户 PATH。

.PARAMETER ShellProfile
    把 EDITOR/vim 别名的片段写入 PowerShell profile（默认不写）。

.PARAMETER NoVerify
    跳过安装后的启动验证。

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -ShellProfile
#>
[CmdletBinding()]
param(
    [switch]$NoFonts,
    [switch]$NoTerminal,
    [switch]$NoPath,
    [switch]$ShellProfile,
    [switch]$NoVerify
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$Root         = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalAppData = $env:LOCALAPPDATA
$UserProfile  = $env:USERPROFILE
$Stamp        = Get-Date -Format 'yyyyMMdd-HHmmss'

$ConfigDir  = Join-Path $LocalAppData 'nvim'
$DataDir    = Join-Path $LocalAppData 'nvim-data'
$NvimBase   = Join-Path $LocalAppData 'nvim-config'
$NvimDir    = Join-Path $NvimBase 'nvim'
$ShimDir    = Join-Path $NvimBase 'bin'
$ToolDir    = Join-Path $DataDir 'bin\tools'
$OfflinePathsFile = Join-Path $DataDir 'offline_paths.txt'

function Write-Step([string]$Message) { Write-Host "[install] $Message" -ForegroundColor Cyan }
function Write-Warn([string]$Message) { Write-Host "[warn] $Message" -ForegroundColor Yellow }
function Write-Err([string]$Message)  { Write-Host "[error] $Message" -ForegroundColor Red }

function Backup-Path([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $backup = "$Path.bak-$Stamp"
        Move-Item -LiteralPath $Path -Destination $backup
        Write-Step "已备份 $Path -> $backup"
    }
}

function Copy-Directory([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

# ---------------------------------------------------------------------------
# 0. 基础检查
# ---------------------------------------------------------------------------
if (-not $LocalAppData) {
    throw '环境变量 LOCALAPPDATA 不存在，无法确定安装目录（请在正常登录的 Windows 会话中运行）。'
}
if (-not (Test-Path -LiteralPath (Join-Path $Root 'nvim\init.lua'))) {
    throw '找不到 nvim\init.lua。请在解压后的 nvim-config-offline-* 目录里运行 install.bat。'
}

# 去掉脚本的“来自 Internet”标记（不处理插件等大量文件，避免拖慢安装）
Get-ChildItem -Path $Root -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.ps1', '.bat', '.cmd' } |
    ForEach-Object { try { Unblock-File -LiteralPath $_.FullName -ErrorAction Stop } catch {} }

$CurlExe = Join-Path $env:SystemRoot 'System32\curl.exe'
if (-not (Test-Path -LiteralPath $CurlExe)) {
    Write-Warn '系统没有 curl.exe（AI 补全需要）。Windows 10 1803+ 默认自带，请先升级/安装 curl。'
}

# ---------------------------------------------------------------------------
# 1. Neovim 配置
# ---------------------------------------------------------------------------
Write-Step "安装 Neovim 配置到 $ConfigDir"
New-Item -ItemType Directory -Force -Path $LocalAppData | Out-Null
Backup-Path $ConfigDir
Copy-Item -LiteralPath (Join-Path $Root 'nvim') -Destination $ConfigDir -Recurse -Force
Write-Step '配置安装完成'

# ---------------------------------------------------------------------------
# 2. 插件
# ---------------------------------------------------------------------------
$LazySrc = Join-Path $Root 'deps\lazy'
$LazyDst = Join-Path $DataDir 'lazy'
if (Test-Path -LiteralPath $LazySrc) {
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
    Backup-Path $LazyDst
    Copy-Directory $LazySrc $LazyDst
    $pluginCount = (Get-ChildItem -LiteralPath $LazyDst -Directory -ErrorAction SilentlyContinue).Count
    Write-Step "插件安装完成：$LazyDst（$pluginCount 个）"
} else {
    Write-Warn '未发现离线插件目录 deps\lazy：首次启动 Neovim 时会联网下载插件（需要 git + 网络）。'
}

# ---------------------------------------------------------------------------
# 3. LSP / 格式化工具
# ---------------------------------------------------------------------------
$ToolsSrc = Join-Path $Root 'deps\tools'
if (Test-Path -LiteralPath $ToolsSrc) {
    New-Item -ItemType Directory -Force -Path $ToolDir | Out-Null
    Backup-Path $ToolDir
    Copy-Directory $ToolsSrc $ToolDir

    $toolPaths = @(
        (Join-Path $ToolDir 'clangd\bin'),
        (Join-Path $ToolDir 'lua-language-server\bin'),
        (Join-Path $ToolDir 'stylua'),
        (Join-Path $ToolDir 'rg'),
        (Join-Path $ToolDir 'fd')
    ) | Where-Object { Test-Path -LiteralPath $_ }

    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
    if (@($toolPaths).Count -gt 0) {
        [System.IO.File]::WriteAllLines($OfflinePathsFile, [string[]]$toolPaths, (New-Object System.Text.UTF8Encoding($false)))
        Write-Step "LSP/格式化工具安装完成：$ToolDir"
        Write-Step "离线工具路径清单：$OfflinePathsFile"
    } else {
        Write-Warn 'deps\tools 里没有找到 LSP 工具，跳过'
    }
} else {
    Write-Warn '未发现离线 LSP 工具（deps\tools）：LSP 相关功能需要联网安装 mason 包。'
}

# ---------------------------------------------------------------------------
# 4. 便携版 Neovim + nvim 命令
# ---------------------------------------------------------------------------
$NvimExe      = Join-Path $NvimDir 'bin\nvim.exe'
$PortableSrc  = Join-Path $Root 'deps\nvim'
if (Test-Path -LiteralPath (Join-Path $PortableSrc 'bin\nvim.exe')) {
    New-Item -ItemType Directory -Force -Path $NvimBase | Out-Null
    Backup-Path $NvimDir
    Copy-Item -LiteralPath $PortableSrc -Destination $NvimDir -Recurse -Force
    Write-Step "便携版 Neovim 安装完成：$NvimDir"
}

if (-not (Test-Path -LiteralPath $NvimExe)) {
    $systemNvim = Get-Command nvim.exe -ErrorAction SilentlyContinue
    if ($systemNvim) {
        $NvimExe = $systemNvim.Source
        Write-Step "使用系统已安装的 Neovim：$NvimExe"
    } else {
        Write-Err '没有可用的 Neovim（离线包 deps\nvim 缺失，系统也没有 nvim）。配置已装好，请先安装 Neovim 0.11+。'
        $NvimExe = $null
    }
}

if ($NvimExe -and (Test-Path -LiteralPath (Join-Path $NvimDir 'bin\nvim.exe'))) {
    New-Item -ItemType Directory -Force -Path $ShimDir | Out-Null
    $shimContent = "@echo off`r`n`"%~dp0..\nvim\bin\nvim.exe`" %*`r`n"
    Set-Content -LiteralPath (Join-Path $ShimDir 'nvim.cmd') -Value $shimContent -Encoding ASCII -NoNewline
    Write-Step "已创建 nvim 命令：$(Join-Path $ShimDir 'nvim.cmd')"

    if (-not $NoPath) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($null -eq $userPath) { $userPath = '' }
        $parts = @($userPath -split ';' | Where-Object { $_ -ne '' })
        if ($parts -notcontains $ShimDir) {
            try {
                $newPath = if ($userPath.Trim() -eq '') { $ShimDir } else { "$ShimDir;$userPath" }
                [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
                Write-Step "已把 $ShimDir 加入用户 PATH（新开的终端生效）"
            } catch {
                Write-Warn "无法自动写入用户 PATH（$($_.Exception.Message)）；请手动把 $ShimDir 加入 PATH"
            }
        }
        if (@($env:Path -split ';') -notcontains $ShimDir) { $env:Path = "$ShimDir;$env:Path" }
    }
}

# ---------------------------------------------------------------------------
# 5. 字体（按用户安装，无需管理员权限）
# ---------------------------------------------------------------------------
if (-not $NoFonts) {
    $FontSrc = Join-Path $Root 'env\fonts'
    $FontDst = Join-Path $LocalAppData 'Microsoft\Windows\Fonts'
    if (Test-Path -LiteralPath $FontSrc) {
        New-Item -ItemType Directory -Force -Path $FontDst | Out-Null

        # 先复制字体文件，保证即使注册表不可写字体也已就位
        $fontFiles = @()
        Get-ChildItem -LiteralPath $FontSrc -Filter '*.ttf' -ErrorAction SilentlyContinue | ForEach-Object {
            $destFont = Join-Path $FontDst $_.Name
            Copy-Item -LiteralPath $_.FullName -Destination $destFont -Force
            $fontFiles += @{ Name = $_.Name; Path = $destFont }
            Write-Step "字体已复制：$($_.Name)"
        }

        try {
            $fontRegPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
            if (-not (Test-Path -LiteralPath $fontRegPath)) {
                New-Item -Path $fontRegPath -Force | Out-Null
            }
            $fontFriendlyNames = @{
                'MapleMono-NF-CN-Regular.ttf' = 'Maple Mono NF CN Regular (TrueType)'
                'MapleMono-NF-CN-Bold.ttf'    = 'Maple Mono NF CN Bold (TrueType)'
            }
            try {
                Add-Type -Namespace Win32 -Name Gdi32 -MemberDefinition '[DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceW(string lpFileName);' -ErrorAction SilentlyContinue
            } catch {}
            foreach ($font in $fontFiles) {
                $friendly = $fontFriendlyNames[$font.Name]
                if (-not $friendly) {
                    $friendly = "$([IO.Path]::GetFileNameWithoutExtension($font.Name)) (TrueType)"
                }
                Set-ItemProperty -Path $fontRegPath -Name $friendly -Value $font.Path
                try { [Win32.Gdi32]::AddFontResourceW($font.Path) | Out-Null } catch {}
            }
            try {
                Add-Type -Namespace Win32 -Name User32 -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam, int fuFlags, int uTimeout, out IntPtr lpdwResult);' -ErrorAction SilentlyContinue
                $fontChangeResult = [IntPtr]::Zero
                [Win32.User32]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$fontChangeResult) | Out-Null
            } catch {}
            Write-Step '字体注册完成（新开的终端生效；若字体列表里没有，请注销一次再登录）'
        } catch {
            Write-Warn "字体注册失败：$($_.Exception.Message)"
            Write-Warn "字体文件已复制到 $FontDst，可手动右键安装（或注销后由系统自动识别）"
        }
    } else {
        Write-Warn '未找到字体目录 env\fonts，跳过字体安装'
    }
} else {
    Write-Step '按参数要求跳过字体安装（-NoFonts）'
}

# ---------------------------------------------------------------------------
# 6. Windows Terminal 配置片段
# ---------------------------------------------------------------------------
if (-not $NoTerminal) {
    $FragmentSrc = Join-Path $Root 'env\windows-terminal\nvim-config.fragment.json'
    if (Test-Path -LiteralPath $FragmentSrc) {
        $fragmentDir = Join-Path $LocalAppData 'Microsoft\Windows Terminal\Fragments\nvim-config'
        New-Item -ItemType Directory -Force -Path $fragmentDir | Out-Null
        Copy-Item -LiteralPath $FragmentSrc -Destination (Join-Path $fragmentDir 'settings.json') -Force
        Write-Step "Windows Terminal 配置片段已安装：$fragmentDir"
    }
} else {
    Write-Step '按参数要求跳过 Windows Terminal 配置（-NoTerminal）'
}

# ---------------------------------------------------------------------------
# 7. PowerShell profile 片段（可选）
# ---------------------------------------------------------------------------
if ($ShellProfile) {
    $snippet = Join-Path $Root 'env\powershell\Profile.snippet.ps1'
    if (Test-Path -LiteralPath $snippet) {
        $profilePath = $PROFILE.CurrentUserAllHosts
        if (-not $profilePath) {
            $profilePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\profile.ps1'
        }
        $profileParent = Split-Path -Parent $profilePath
        if ($profileParent) { New-Item -ItemType Directory -Force -Path $profileParent | Out-Null }
        $existing = if (Test-Path -LiteralPath $profilePath) { Get-Content -LiteralPath $profilePath -Raw } else { '' }
        if ($existing -notmatch '>>> nvim-config >>>') {
            $snippetText = Get-Content -LiteralPath $snippet -Raw
            Add-Content -LiteralPath $profilePath -Value "`r`n$snippetText"
            Write-Step "PowerShell 配置片段已写入：$profilePath"
        } else {
            Write-Step 'PowerShell profile 里已有 nvim-config 片段，跳过'
        }
    }
}

# ---------------------------------------------------------------------------
# 8. DeepSeek API key 目录（只放示例，绝不写真实 key）
# ---------------------------------------------------------------------------
$KeyDir = Join-Path $UserProfile '.config\deepseek'
New-Item -ItemType Directory -Force -Path $KeyDir | Out-Null
$KeyFile    = Join-Path $KeyDir 'api_key'
$KeyExample = Join-Path $Root 'env\deepseek\api_key.example'
if ((Test-Path -LiteralPath $KeyExample) -and -not (Test-Path -LiteralPath $KeyFile)) {
    Copy-Item -LiteralPath $KeyExample -Destination (Join-Path $KeyDir 'api_key.example') -Force
    Write-Warn '未检测到 DeepSeek API key，AI 补全默认关闭。启用方法：'
    Write-Warn "  Set-Content -Path `"$KeyFile`" -Value `"sk-你的key`" -NoNewline"
    Write-Warn '  或者设置用户环境变量 DEEPSEEK_API_KEY'
}

# ---------------------------------------------------------------------------
# 9. 验证
# ---------------------------------------------------------------------------
if (-not $NoVerify -and $NvimExe) {
    Write-Step '验证 Neovim 启动...'
    try {
        $output = & $NvimExe --headless "+lua print('PLUGINS=' .. #vim.fn.readdir(vim.fn.stdpath('data') .. '/lazy'))" '+qa' 2>&1
        $text = ($output | Out-String)
        if ($text -match 'PLUGINS=(\d+)') {
            $verLine = (& $NvimExe --version 2>&1 | Select-Object -First 1)
            Write-Step "启动验证通过：$verLine；已安装插件 $($Matches[1]) 个"
        } else {
            Write-Warn "启动验证输出异常：`n$text"
        }
    } catch {
        Write-Warn "启动验证失败：$($_.Exception.Message)"
    }

    try {
        $lspOutput = & $NvimExe --headless "+lua local ok,err = pcall(function() require('lazy').load({ plugins = { 'mason.nvim', 'none-ls.nvim' } }) end); print('LSP_LOAD=' .. tostring(ok) .. ' ' .. tostring(err))" '+qa' 2>&1
        $lspText = ($lspOutput | Out-String)
        if ($lspText -match 'LSP_LOAD=(true|false)') {
            if ($Matches[1] -eq 'true') {
                Write-Step 'LSP 配置加载验证通过（离线模式）'
            } else {
                Write-Warn "LSP 配置加载异常：`n$lspText"
            }
        }
    } catch {
        Write-Warn "LSP 配置加载验证失败：$($_.Exception.Message)"
    }

    $lspChecks = @(
        @{ Name = 'clangd';              Exe = (Join-Path $ToolDir 'clangd\bin\clangd.exe');        Args = @('--version') },
        @{ Name = 'stylua';              Exe = (Join-Path $ToolDir 'stylua\stylua.exe');             Args = @('--version') },
        @{ Name = 'lua-language-server'; Exe = (Join-Path $ToolDir 'lua-language-server\bin\lua-language-server.exe'); Args = $null }
    )
    foreach ($check in $lspChecks) {
        if (Test-Path -LiteralPath $check.Exe) {
            if ($null -eq $check.Args) {
                Write-Step "$($check.Name)：已安装（$($check.Exe)）"
            } else {
                try {
                    $firstLine = (& $check.Exe @($check.Args) 2>&1 | Select-Object -First 1)
                    Write-Step "$($check.Name)：$firstLine"
                } catch {
                    Write-Warn "$($check.Name) 已安装，但版本检查失败"
                }
            }
        }
    }
} else {
    Write-Step '按参数要求跳过验证（-NoVerify）'
}

# ---------------------------------------------------------------------------
# 10. 完成
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
Write-Host '安装完成 🎉' -ForegroundColor Green
Write-Host ''
Write-Host '  nvim                  启动编辑器（新开一个终端窗口后可用）'
Write-Host '  :Lazy                 查看/管理插件（联网 + git 时 :Lazy sync 更新）'
Write-Host '  :checkhealth          体检（LSP、字体、剪贴板等）'
Write-Host '  :Telescope find_files 查找文件'
Write-Host '  <Space>e              文件树'
Write-Host '  Tab                   接受 AI 补全（DeepSeek，需要 API key + 网络）'
Write-Host '  Alt+Enter             打开 AI 补全面板'
Write-Host ''
Write-Host "  DeepSeek API key: $KeyFile（或环境变量 DEEPSEEK_API_KEY）"
Write-Host "  备份目录：        $ConfigDir.bak-$Stamp 等"
Write-Host '  体检脚本：        .\check.ps1'
Write-Host '  卸载：            .\uninstall.ps1'
if (-not $NoTerminal) {
    Write-Host '  提示：Windows Terminal 的字体/配色在重启 Windows Terminal 后生效。'
}
Write-Host '────────────────────────────────────────────────────────────' -ForegroundColor DarkGray
Write-Host ''
