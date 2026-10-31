# Per-user Windows preferences (HKCU only, no admin). Safe to re-run. Review before running:
#   just windows-preferences            apply
#   just windows-preferences -Light     use light mode instead of dark
param([switch]$Light)
$theme = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$adv   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$mode  = if ($Light) { 1 } else { 0 }

Set-ItemProperty $theme AppsUseLightTheme $mode
Set-ItemProperty $theme SystemUsesLightTheme $mode
Set-ItemProperty $adv HideFileExt 0      # show file extensions
Set-ItemProperty $adv Hidden 1           # show hidden files (dotfiles)

# Make Explorer pick the changes up.
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
"Applied: $(if ($Light) {'light'} else {'dark'}) mode, file extensions + hidden files shown."
