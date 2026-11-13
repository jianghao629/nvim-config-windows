#Requires -Version 5.1
<#
.SYNOPSIS
    nvim-config Windows 体检脚本
.DESCRIPTION
    打印版本、路径、插件数量、LSP 工具、字体、DeepSeek key 等状态，排查问题时把输出贴出来即可。
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$LocalAppData = $env:LOCALAPPDATA
$ConfigDir    = Join-Path $LocalAppData 'nvim'
$DataDir      = Join-Path $LocalAppData 'nvim-data'
$NvimDir      = Join-Path $LocalAppData 'nvim-config\nvim'
$ToolDir      = Join-Path $DataDir 'bin\tools'
$OfflinePathsFile = Join-Path $DataDir 'offline_paths.txt'
$KeyFile      = Join-Path $env:USERPROFILE '.config\deepseek\api_key'

function Show-Item([string]$Label, [string]$Value) {
    Write-Host ("{0,-24} {1}" -f $Label, $Value)
}
function Get-ToolVersion([string]$Exe, [string[]]$ToolArgs = @('--version')) {
    if (-not (Test-Path -LiteralPath $Exe)) { return 'MISSING' }
    try { return ((& $Exe @ToolArgs 2>&1 | Select-Object -First 1) | Out-String).Trim() } catch { return 'ERROR' }
}

Write-Host '=== nvim-config 体检 ===' -ForegroundColor Cyan
Show-Item 'OS' ((Get-CimInstance Win32_OperatingSystem).Caption)
Show-Item 'PowerShell' ($PSVersionTable.PSVersion.ToString())
Show-Item 'LOCALAPPDATA' $LocalAppData
Show-Item '配置目录' $ConfigDir
Show-Item '数据目录' $DataDir
Show-Item '配置存在' (Test-Path -LiteralPath (Join-Path $ConfigDir 'init.lua'))
Show-Item '插件目录' (Join-Path $DataDir 'lazy')
Show-Item '插件数量' ((Get-ChildItem -LiteralPath (Join-Path $DataDir 'lazy') -Directory -ErrorAction SilentlyContinue).Count)
Show-Item '离线标志文件' (Test-Path -LiteralPath $OfflinePathsFile)
Show-Item 'PATH 含 nvim-config' (((@($env:Path -split ';')) -contains (Join-Path $LocalAppData 'nvim-config\bin')))

$nvimCandidates = @(
    (Join-Path $NvimDir 'bin\nvim.exe'),
    (Join-Path $LocalAppData 'nvim-config\bin\nvim.cmd')
)
$nvimFound = $nvimCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
Show-Item 'nvim 可执行' $nvimFound
if ($env:Path -match 'nvim-config\\bin') { Show-Item 'nvim 命令' 'PATH 中已包含 nvim-config\bin' }
if (Get-Command nvim.exe -ErrorAction SilentlyContinue) {
    Show-Item 'nvim --version' ((& nvim.exe --version 2>&1 | Select-Object -First 1) | Out-String).Trim()
}

# 启动一次 headless，验证配置
$nvimExe = Join-Path $NvimDir 'bin\nvim.exe'
if (Test-Path -LiteralPath $nvimExe) {
    Write-Host '--- 启动测试 ---' -ForegroundColor DarkGray
    try {
        $out = & $nvimExe --headless "+lua print('PLUGINS=' .. #vim.fn.readdir(vim.fn.stdpath('data') .. '/lazy'))" '+qa' 2>&1
        $out | Out-String | Write-Host
    } catch {
        Write-Host "启动失败：$($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host '--- LSP / 工具 ---' -ForegroundColor DarkGray
Show-Item 'clangd' (Get-ToolVersion (Join-Path $ToolDir 'clangd\bin\clangd.exe'))
Show-Item 'lua-language-server' (Get-ToolVersion (Join-Path $ToolDir 'lua-language-server\bin\lua-language-server.exe'))
Show-Item 'stylua' (Get-ToolVersion (Join-Path $ToolDir 'stylua\stylua.exe'))
Show-Item 'curl.exe' (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\curl.exe'))
Show-Item 'git' (Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue)

Write-Host '--- 字体 / 终端 ---' -ForegroundColor DarkGray
$fontReg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$maple = Get-ItemProperty -Path $fontReg -ErrorAction SilentlyContinue |
    Get-Member -MemberType NoteProperty |
    Where-Object { $_.Name -like 'Maple Mono NF CN*' } |
    Select-Object -ExpandProperty Name
$mapleState = if ($maple) { '已注册：' + (@($maple) -join ', ') } else { '未注册' }
Show-Item 'Maple Mono NF CN' $mapleState
$fragment = Join-Path $LocalAppData 'Microsoft\Windows Terminal\Fragments\nvim-config\settings.json'
Show-Item 'WT 配置片段' (Test-Path -LiteralPath $fragment)

Write-Host '--- AI 补全 ---' -ForegroundColor DarkGray
Show-Item 'DeepSeek key 文件' (Test-Path -LiteralPath $KeyFile)
Show-Item 'DEEPSEEK_API_KEY 环境变量' ([bool]$env:DEEPSEEK_API_KEY)
