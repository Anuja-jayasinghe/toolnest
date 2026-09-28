# Ranking calculator

An interactive Python script that calculates standard competition rankings
from a pasted list of marks.

## Run it

From the repository root:

```bash
just ranking-calculator
```

Or run it directly:

```bash
python3 ranking_calculator/ranking_calculator.py
```

## Input

Paste marks one per line or comma-separated. Press Enter on an empty line when
you are finished. Invalid entries are skipped with a warning.

Example:

```text
90, 90, 80, 75
```

Output:

```text
Mark    Rank
90.0    1
90.0    1
80.0    3
75.0    4
```

This uses standard competition ranking: tied marks share a rank, and the next
rank leaves a gap. For example, `1, 1, 3` becomes `1, 1, 3`.

The script was imported from
[Python-ranking-calculator](https://github.com/Anuja-jayasinghe/Python-ranking-calculator).
