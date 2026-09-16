# Lint

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Static checks for Python (`ruff`) and shell (`shellcheck`) — non-destructive
by default, with an auto-fix lane.

## Targets

| Target | Action |
|---|---|
| `lint` | Run all checks (Python + shell), non-destructive |
| `lint-py` | Check Python code with ruff |
| `lint-sh` | Check shell scripts with shellcheck |
| `lint-format` | Auto-fix and format Python code with ruff |

## Variables

| Variable | Default | Notes |
|---|---|---|
| `PY_TARGETS` | `.` | Scan roots for Python (files or directories) |
| `SH_TARGETS` | `.` | Scan roots for shell (files or directories) |

## Full-scan confirmation

Launched without a scope, the lint targets would scan the entire current
directory — so they ask for confirmation first. When `lint` is the goal, a
single prompt covers both chained checks; the individual targets prompt on
their own when launched bare. Scope instead:

```bash
gmake lint PY_TARGETS="src/" SH_TARGETS="scripts/"
gmake lint-py PY_TARGETS="src/"
```

## Tools

- `ruff` is installed globally at first boot via `uv tool install ruff`; lint
  rules live in each project's `pyproject.toml` (`[tool.ruff]`) — only the
  tool lives on the machine.
- `shellcheck` is bundled in the template image.
