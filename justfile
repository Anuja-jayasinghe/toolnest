# Windows has no `sh` by default, so recipes run in PowerShell 7 there.
set windows-shell := ["pwsh", "-NoLogo", "-NoProfile", "-Command"]

python := if os_family() == "windows" { "python" } else { "python3" }
venv_python := if os_family() == "windows" { ".venv/Scripts/python.exe" } else { ".venv/bin/python" }

default:
    @just --list

# Create the local virtual environment and install every tool's dependencies.
install:
    {{ python }} -m venv .venv
    {{ venv_python }} -c 'from pathlib import Path; import subprocess, sys; files = sorted(Path(".").glob("*/requirements.txt")); print(f"Installing from {len(files)} requirements file(s)...", flush=True); [subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", str(path)]) for path in files]'

# Move the mouse periodically to keep the computer active.
mouse-auto-active: install
    {{ venv_python }} mouse_auto_active/mouse_active.py

# Calculate standard competition rankings from pasted marks.
ranking-calculator: install
    {{ venv_python }} ranking_calculator/ranking_calculator.py

# Check an Anthropic API key with a minimal live request.
anthropic-key-test: install
    {{ venv_python }} anthropic_key_test/anthropic_key_test.py

# Set the desktop wallpaper (Windows). Args: -Name file.jpg | -Random | -Path image.
wallpaper *args:
    pwsh -NoProfile -File set_wallpaper/set_wallpaper.ps1 {{ args }}

# Apply per-user Windows preferences: dark mode, file extensions, hidden files (Windows). Arg: -Light.
windows-preferences *args:
    pwsh -NoProfile -File windows_preferences/windows_preferences.ps1 {{ args }}

# Connect or disconnect a paired Bluetooth device from a picker (Windows). Args: -Name part -Disconnect.
bluetooth *args:
    pwsh -NoProfile -File bluetooth_connect/bluetooth_connect.ps1 {{ args }}

# Install and configure WSL (Windows). Args: -Install from an elevated terminal first.
wsl-setup *args:
    pwsh -NoProfile -File wsl_setup/wsl_setup.ps1 {{ args }}

# Compile all Python scripts without running them.
check:
    {{ python }} -c 'from pathlib import Path; files = [p for p in Path(".").glob("*/**/*.py") if not any(part.startswith(".") for part in p.parts)]; [compile(p.read_text(encoding="utf-8"), str(p), "exec") for p in files]; print(f"Python syntax: ok ({len(files)} files)")'
