# >>> nvim-config >>>
# Written by nvim-config-windows install.ps1 -ShellProfile
$env:EDITOR = "nvim"
$env:VISUAL = "nvim"
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias -Name vim -Value nvim -Option AllScope -Force
    Set-Alias -Name vi  -Value nvim -Option AllScope -Force
}
# <<< nvim-config <<<
