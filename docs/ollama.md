# Local Models (Ollama)

[← Back to the README](../README.md#bundled-software--stack)

The image ships without a local model server: Ollama plus its models weigh
several gigabytes, and not every project wants one. Installing it inside the
distro is one command — and for a workstation you carry around, it is a real
option rather than a fallback.

## Install it in the distro

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

That is ~1.4 GB to download — the binary bundles the CUDA runners, so it is
large even without a GPU (ROCm is a separate, optional download). It installs
the `ollama` command and a systemd service that starts the server on port
11434. systemd is enabled in this distro, so the service really runs: no
`ollama serve` to keep in a terminal.

No NVIDIA GPU is required. Without one the server falls back to the CPU, which
is usable for the small models a targeted task needs (a few billion parameters
at most) and slow beyond that.

Once it is installed, the `Ctrl + H` sheet for it appears: `ollama_commands.sh`
declares `# requires: ollama` and is left out until then, the same rule the
`gmake` menu applies to the Google Cloud modules
([optional tooling](make/install.md)).

## Where the models live

`~/.ollama/models` — inside the distro, therefore inside the VHDX.

- **A distro you carry elsewhere takes its models with it.** That is the point
  of a portable VHDX: the models are part of the workstation, not a cache you
  rebuild somewhere.
- **A rebuild erases them**, like everything else inside the distro (see
  [Maintenance & Removal](../README.md#maintenance--removal)). Nothing is lost
  — they are downloaded again — but it is a few gigabytes each time.

## Or run the server on Windows

Windows-native Ollama drives a GPU natively and keeps the models on `C:`, where
no rebuild reaches them. Two conditions to join it from the distro:

1. **The network mode.** In the default NAT mode, `localhost` inside the distro
   means the distro itself, not Windows: you need the host's IP, which changes
   at every start. `networkingMode=mirrored` in `C:\Users\<you>\.wslconfig`
   makes `localhost` work in both directions (Windows 11 22H2 or later, with
   WSL 2.0+).
2. **The listen address.** Ollama on Windows accepts connections from itself
   only, by default: start it with `OLLAMA_HOST=0.0.0.0:11434`.

The distro then only needs to know where to knock:

```bash
export OLLAMA_HOST=http://localhost:11434   # with mirrored networking
```

This route has never been exercised here — it is written from the tools'
configuration, not from a machine that had both ends running.

## From a project

`uv add ollama` adds the **Python client**: a library in the project's venv
that talks to whichever server `OLLAMA_HOST` names. It is not a fourth way of
running a model — the server still lives in the distro, or on Windows.
