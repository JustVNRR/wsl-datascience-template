# Optional Tooling

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

This module holds one target: `gcp_install`, which installs the Google Cloud
CLI. It is offered only while that CLI is absent, so a fresh distro shows the
way in instead of commands that cannot run. Its counterpart, `gcp_uninstall`,
lives in [the gcp module](gcp.md) — loaded only when the CLI is there.

The guides live with the tools they install:
[Google Cloud](../optional_tooling/gcp_onboarding.md) ·
[Ollama](../optional_tooling/ollama_onboarding.md).
