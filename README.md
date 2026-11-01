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
├── set_wallpaper/          (Windows, PowerShell)
├── windows_preferences/    (Windows, PowerShell)
├── wsl_setup/              (Windows, PowerShell)
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
just wallpaper -Random
just windows-preferences
just wsl-setup
just check
```

The three Windows recipes run PowerShell scripts through `pwsh` (PowerShell 7).
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
