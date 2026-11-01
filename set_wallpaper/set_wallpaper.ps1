# Sets the desktop wallpaper from the dotfiles collection (assets/wallpapers) or any image path.
#   just wallpaper -Name mountain.jpg
#   just wallpaper -Random
#   just wallpaper -Path D:\pics\x.png
param([string]$Name, [string]$Path, [switch]$Random)
# toolnest and dotfiles are siblings inside the projects folder (C:\gitprojects by default).
$projects = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$dir = Join-Path $projects 'dotfiles\assets\wallpapers'
if (-not $Path) {
    $imgs = Get-ChildItem $dir -File -ErrorAction SilentlyContinue | Where-Object Extension -match '\.(jpg|jpeg|png|bmp)$'
    if (-not $imgs) { Write-Error "No images in $dir. Add some, or pass -Path."; exit 1 }
    $pick = if ($Name) { $imgs | Where-Object Name -eq $Name } elseif ($Random) { $imgs | Get-Random } else { $imgs | Select-Object -First 1 }
    if (-not $pick) { Write-Error "Not found: $Name"; exit 1 }
    $Path = $pick.FullName
}
Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class Wp { [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int SystemParametersInfo(int a, int b, string c, int d); }'
[void][Wp]::SystemParametersInfo(20, 0, (Resolve-Path $Path).Path, 3)   # SPI_SETDESKWALLPAPER, update ini + broadcast
"Wallpaper set: $Path"
