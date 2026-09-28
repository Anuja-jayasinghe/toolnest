python := if os_family() == "windows" { "python" } else { "python3" }

default:
    @just --list

anthropic-key-test:
    {{python}} anthropic_key_test/anthropic_key_test.py

ranking-calculator:
    {{python}} ranking_calculator/ranking_calculator.py

check:
    {{python}} -c 'from pathlib import Path; [compile(p.read_text(encoding="utf-8"), str(p), "exec") for p in Path(".").glob("*/**/*.py")]; print("Python syntax: ok")'
