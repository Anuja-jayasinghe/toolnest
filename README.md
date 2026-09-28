# Personal scripts

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
scripts/
├── anthropic_key_test/
│   ├── anthropic_key_test.py
│   └── README.md
├── ranking_calculator/
│   ├── ranking_calculator.py
│   └── README.md
├── justfile
└── README.md
```

## Run a script

From this directory:

```bash
just
just anthropic-key-test
just ranking-calculator
just check
```

You can also run the files directly with Python:

```bash
python3 anthropic_key_test/anthropic_key_test.py
python3 ranking_calculator/ranking_calculator.py
```

The Anthropic checker prompts for a key and performs one minimal live Messages
request. It uses no third-party packages. See
[`anthropic_key_test/README.md`](anthropic_key_test/README.md) for details.

See [`ranking_calculator/README.md`](ranking_calculator/README.md) for the
ranking calculator's input format and ranking behavior.
