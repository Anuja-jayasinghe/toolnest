# Mouse auto active

A small Python utility that moves the mouse periodically to help keep a
computer active during periods of inactivity.

## Install

From the Toolnest repository root:

```bash
just install
```

This creates a repository-local `.venv`, discovers all `requirements.txt`
files in Toolnest, and installs every script's dependencies, including
`pyautogui`. The virtual environment is excluded from Git.

## Run

Using `just` from the repository root:

```bash
just mouse-auto-active
```

This command also runs the installation recipe automatically, so calling it
directly is enough on a fresh checkout.

Or run it directly:

```bash
.venv/bin/python mouse_auto_active/mouse_active.py
```

On Windows, the equivalent interpreter is `.venv\Scripts\python.exe`.

Stop it at any time with `Ctrl-C`.

## Configuration

The current script chooses random coordinates between `x=1600..1700` and
`y=200..600`, moves over `0.5` seconds, and waits `3` seconds between moves.
Edit those values in `mouse_active.py` to match your screen and preferred
timing.

The script was imported from
[Mouse-auto-active](https://github.com/Anuja-jayasinghe/Mouse-auto-active).
