# Toolnest

A small personal toolbox for reusable scripts. Each script lives in its own
directory with its implementation and documentation together. `just` provides
short commands from the repository root.

## Install `just`

Install the `just` command-line tool before using the recipes below. Verify it
with `just --version`.

macOS with Homebrew:

```bash
brew install just
```

Linux or macOS with Cargo:

```bash
cargo install just
```

Windows with WinGet:

```powershell
winget install --id Casey.Just --exact
```

Other installation methods are documented in the [official Just manual](https://just.systems/man/en/).

## Layout

```text
toolnest/
├── mouse_auto_active/
│   ├── mouse_active.py
│   ├── requirements.txt
│   └── README.md
├── ranking_calculator/
│   ├── ranking_calculator.py
│   └── README.md
├── anthropic_key_test/
│   ├── anthropic_key_test.py
│   └── README.md
├── bluetooth_connect/      (Windows, PowerShell)
├── set_wallpaper/          (Windows, PowerShell)
├── windows_preferences/    (Windows, PowerShell)
├── wsl_setup/              (Windows, PowerShell)
├── remote_access/          (Windows, PowerShell)
├── justfile
└── README.md
```

## Run a script

From this directory:

```bash
just
just install
just mouse-auto-active
just ranking-calculator
just anthropic-key-test
just bluetooth
just wallpaper -Random
just windows-preferences
just wsl-setup
just remote-access
just check
```

`just remote-access` makes this PC reachable from your other devices through
Tailscale: Remote Desktop and an SSH server (key sign-in only), neither open to
anything outside Tailscale. It also installs RustDesk, which shares the real
screen (with a privacy mode toggle) and is reachable by RustDesk ID or
directly over Tailscale; set its permanent password and 2FA in its settings.
Add an SSH key with `just remote-access -AddKey "ssh-ed25519 ..."` and check
the setup with `just remote-access -Status`.

The five Windows recipes run PowerShell scripts through `pwsh` (PowerShell 7).
On Windows every recipe uses `pwsh` as its shell, since `sh` is not installed by
default. The Python scripts need Python 3 installed.

This repo sits next to the [dotfiles](https://github.com/Anuja-jayasinghe/dotfiles)
repo in the projects folder (`C:\gitprojects`); the dotfiles bootstrap script
clones both. The wallpaper and WSL scripts read the dotfiles repo from there.

`just install` creates an isolated `.venv`, discovers every
`*/requirements.txt` file, and installs the dependencies for all scripts. New
scripts are automatically included when they keep their requirements file in
their own directory. Currently, Mouse Auto Active requires `pyautogui`; the
other two scripts use only Python's standard library.

Every script recipe runs the installation recipe automatically before starting,
so any `just <script-name>` command works as the first command on a new
checkout.

You can also run the files directly with Python:

```bash
.venv/bin/python mouse_auto_active/mouse_active.py
.venv/bin/python ranking_calculator/ranking_calculator.py
.venv/bin/python anthropic_key_test/anthropic_key_test.py
```

See [`mouse_auto_active/README.md`](mouse_auto_active/README.md) for its
dependency installation and usage instructions.

See [`ranking_calculator/README.md`](ranking_calculator/README.md) for the
ranking calculator's input format and ranking behavior.

The Anthropic checker prompts for a key and performs one minimal live Messages
request. It uses no third-party packages. See
[`anthropic_key_test/README.md`](anthropic_key_test/README.md) for details.
