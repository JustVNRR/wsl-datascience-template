# Ollama Onboarding

[← Back to the README](../../README.md#optional-tooling)

Ollama runs a model on your own machine and answers on port 11434. The image
does not ship it: the server and its models weigh several gigabytes, and they
belong to the projects that want them rather than to everyone's image.

## Ollama Server

One command either way. The question is only *where* the server runs, and what
that does with the models:

| Where the server runs | What that gives you |
| :--- | :--- |
| [In the distro](#run-ollama-in-the-distro) | The models travel with the VHDX, which is the point of a portable workstation. A rebuild takes them with it. |
| [On Windows](#run-ollama-on-windows) | The models stay on `C:`, out of a rebuild's reach, and a GPU is driven natively. Best when the machine stays put. |

The client side is the same in both cases, and lives [further down](#ollama-client).

### Run Ollama in the distro

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

The models land in `~/.ollama/models` — inside the distro. A rebuild erases them
like everything else in there: nothing is lost, they download again, but it is a
few gigabytes each time. A VHDX you carry to another machine takes them along,
and that is the case this option is for.

Once the command exists, its `Ctrl + H` sheet appears (`ollama_commands.sh`
declares `# requires: ollama`, so it stays out of the picker until then) and
lists the day-to-day commands: `ollama pull`, `ollama run`, `ollama list`,
`ollama ps`.

### Run Ollama on Windows

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

The `ollama` command reads that variable; a Python script points its client at
the same address, explicitly — see below.

This route has never been exercised here — it is written from the tools'
configuration, not from a machine that had both ends running.

## Ollama Client

The client is a project dependency, like any other:

```bash
uv add ollama
```

It talks to a server; it never runs a model itself. The module-level functions
use the server on this machine, which is the usual case:

```python
import ollama

response = ollama.chat(
    model="llama3.2",
    messages=[{"role": "user", "content": "Why is the sky blue?"}],
)
print(response["message"]["content"])
```

To reach another server — the Windows one above, say — hand the client its
address:

```python
from ollama import Client

client = Client(host="http://localhost:11434")
client.chat(model="llama3.2", messages=[{"role": "user", "content": "..."}])
```

The rest of the surface has the same shape:

```python
ollama.generate(model="llama3.2", prompt="Why is the sky blue?")  # one-shot, no history
ollama.list()                                                      # what the server holds
ollama.embed(model="nomic-embed-text", input="The sky is blue")    # vectors, for search or RAG
```

And streaming, once the answers get long enough to want it:

```python
stream = ollama.chat(model="llama3.2", messages=[...], stream=True)
for chunk in stream:
    print(chunk["message"]["content"], end="", flush=True)
```

`ollama list` in the terminal answers the same question as `ollama.list()` in
Python: which models this server has. A model that is missing is downloaded on
first use, by either side.
