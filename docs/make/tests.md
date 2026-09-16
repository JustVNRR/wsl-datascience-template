# Tests

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Run a project's pytest suite, split into lanes by marker.

## Targets

| Target | Lane |
|---|---|
| `test` | Run the whole test suite |
| `test-fast` | Fast tests only, no external infrastructure (the CI lane) |
| `test-functional` | Tests that need real local infrastructure (`.env`, Docker, a model...) |
| `test-gcp` | Tests that hit a real GCP environment (test/staging/prod) |

## Marker convention

Declare the markers your project uses in its `pyproject.toml`
(`[tool.pytest.ini_options] markers`):

- (none) — fast unit tests, no external infrastructure
- `functional` — needs real local infra (`.env`, Docker, a trained model...)
- `gcp` — hits a real GCP environment (test/staging/prod)

Unmarked tests run in every lane, so projects without the convention still
work out of the box (pytest only warns about unknown markers).

## Where pytest lives

Unlike ruff, `pytest` is a project dependency, not a machine tool: it must
run inside the project's virtual environment to import its code and plugins.
Install it per project:

```bash
uv add --dev pytest
```

`gmake test-*` fails fast with a reminder when pytest is missing from the
active environment — the most common cause being a launch from outside the
project directory (the venv activates via direnv on `cd`).
