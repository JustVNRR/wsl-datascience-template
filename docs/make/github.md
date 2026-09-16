# GitHub Pull Requests

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

A small pull-request workflow built on the GitHub CLI — requires an
authenticated `gh` (`gh auth status`).

## Targets

| Target | Action |
|---|---|
| `gh_pr_create` | Push the current branch and create a non-interactive PR (title/description auto-filled from commits) |
| `gh_pr_toreview` | Add the `toreview` label to the current branch's PR (creates the label if needed) |
| `gh_pr_wip` | Remove the `toreview` label (back to work in progress) |
| `gh_pr_ls` | List open PRs in the repository |

## Variables

| Variable | Default | Notes |
|---|---|---|
| `BASE_BRANCH` | `main` | Base branch for `gh_pr_create` |

## Usage

```bash
gmake gh_pr_create                      # PR onto main
gmake gh_pr_create BASE_BRANCH=develop  # PR onto develop
gmake gh_pr_toreview                    # flag the PR for review
```
