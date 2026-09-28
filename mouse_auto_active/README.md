# Mouse auto active

A small Python utility that moves the mouse periodically to help keep a
computer active during periods of inactivity.

## Install

From the Toolnest repository root:

```bash
python3 -m pip install -r mouse_auto_active/requirements.txt
```

On Windows, use `python` instead of `python3` if that is the command installed
on your system.

## Run

Using `just` from the repository root:

```bash
just mouse-auto-active
```

Or run it directly:

```bash
python3 mouse_auto_active/mouse_active.py
```

Stop it at any time with `Ctrl-C`.

## Configuration

The current script chooses random coordinates between `x=1600..1700` and
`y=200..600`, moves over `0.5` seconds, and waits `3` seconds between moves.
Edit those values in `mouse_active.py` to match your screen and preferred
timing.

The script was imported from
[Mouse-auto-active](https://github.com/Anuja-jayasinghe/Mouse-auto-active).
