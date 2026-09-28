python := if os_family() == "windows" { "python" } else { "python3" }

default:
    @just --list

# Check an Anthropic API key with a minimal live request.
anthropic-key-test:
    {{python}} anthropic_key_test/anthropic_key_test.py

# Calculate standard competition rankings from pasted marks.
ranking-calculator:
    {{python}} ranking_calculator/ranking_calculator.py

# Move the mouse periodically to keep the computer active.
mouse-auto-active:
    {{python}} mouse_auto_active/mouse_active.py

# Compile all Python scripts without running them.
check:
    {{python}} -c 'from pathlib import Path; [compile(p.read_text(encoding="utf-8"), str(p), "exec") for p in Path(".").glob("*/**/*.py")]; print("Python syntax: ok")'
