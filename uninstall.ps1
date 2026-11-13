#Requires -Version 5.1
<#
.SYNOPSIS
    nvim-config Windows 卸载脚本（保守策略：只移走，不删除）

.DESCRIPTION
    默认只移走配置、Windows Terminal 片段和离线工具路径清单，
    插件/LSP/Neovim 保留。加 -Purge 才会连这些一起移走。
    已移走的内容都带 .removed-<时间> 后缀，可手动改回。

.EXAMPLE
    .\uninstall.ps1

.EXAMPLE
    .\uninstall.ps1 -Purge
#>
[CmdletBinding()]
param(
    [switch]$Purge
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$LocalAppData = $env:LOCALAPPDATA
$ConfigDir    = Join-Path $LocalAppData 'nvim'
$DataDir      = Join-Path $LocalAppData 'nvim-data'
$NvimBase     = Join-Path $LocalAppData 'nvim-config'
$ShimDir      = Join-Path $NvimBase 'bin'
$ToolDir      = Join-Path $DataDir 'bin\tools'
$OfflinePathsFile = Join-Path $DataDir 'offline_paths.txt'
$FragmentDir  = Join-Path $LocalAppData 'Microsoft\Windows Terminal\Fragments\nvim-config'
$Stamp        = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Step([string]$Message) { Write-Host "[uninstall] $Message" -ForegroundColor Cyan }
function Write-Warn([string]$Message) { Write-Host "[warn] $Message" -ForegroundColor Yellow }

function Move-Away([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $target = "$Path.removed-$Stamp"
        Move-Item -LiteralPath $Path -Destination $target
        Write-Step "已移走 $Path -> $target"
    }
}

Move-Away $ConfigDir
Move-Away $FragmentDir
Move-Away $OfflinePathsFile

if ($Purge) {
    Move-Away (Join-Path $DataDir 'lazy')
    Move-Away $ToolDir
    Move-Away $NvimBase
    if (Test-Path -LiteralPath $ShimDir) { Move-Away $ShimDir }

    # 从用户 PATH 中移除 nvim-config\bin
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) {
        $parts = @($userPath -split ';' | Where-Object { $_ -ne '' -and $_ -ne $ShimDir })
        [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
        Write-Step "已从用户 PATH 移除 $ShimDir"
    }
}

Write-Warn "已移走的文件都带 .removed-$Stamp 后缀，可随时改回；确认不要后可手动删除。"
if (-not $Purge) {
    Write-Warn '插件/LSP/便携版 Neovim 未处理；如需彻底清理请加 -Purge 重新执行。'
}
Write-Warn '字体不自动删除；如需移除请到 设置 -> 字体 或 %LOCALAPPDATA%\Microsoft\Windows\Fonts 手动处理。'
