# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
## What this plugin does

A Neovim plugin for reviewing agent-written code and feeding review comments back to a running agent:

1. Compute the git diff of the working tree against a **base branch** (merge-base, not tip).
2. Render that diff in a buffer where the user can visually select a region and attach a comment.
3. Accumulate comments across many files in a session-scoped store.
4. On submit, serialize all comments into one prompt and deliver it to a live **Herdr** agent.

The interesting complexity is in steps 2 and 4; the rest is plumbing.

## Environment (verified on this machine)

- `nvim` 0.12.1 (LuaJIT) — `/opt/homebrew/bin/nvim`
- `herdr` — `~/.local/bin/herdr`


## Architecture notes

Intended module split under `lua/herdr-review/` (`plugin/` holds only command/keymap registration so the
Lua modules stay lazily loadable):

- **git** — resolve repo root and base branch, then `git merge-base <base> HEAD` and diff against that SHA.
  Diffing against the branch *tip* gives false hunks when the base has moved; always use the merge-base.
- **diff** — parse unified diff into files → hunks → lines. Each rendered buffer line must retain a back-pointer
  to `(path, side, original_line_number)`. This mapping is the plugin's core data structure: comments anchor to
  source positions, not to buffer positions, so a re-render or a refreshed diff must not orphan them.
- **ui** — scratch buffer rendering plus extmarks/signs for commented regions. Visual-mode selection produces a
  line range that gets translated through the diff mapping before it becomes a comment.
- **store** — comments keyed by `(path, start_line, end_line, side)`. Owns ordering for serialization and must
  survive a diff refresh: reconcile by source position, dropping comments whose anchor no longer exists and
  telling the user which were dropped.
- **herdr** — the only module that shells out to `herdr`. Everything above it works on plain tables. Keeping
  this boundary sharp is what makes the review flow testable without a live Herdr session.
- **prompt** — render the comment set into agent-directed text. Comments are review feedback, so include enough
  surrounding diff context that the agent can locate the code without re-reading the whole file.

## Conventions

- Lua only, targeting nvim 0.12 APIs (`vim.system`, `vim.uv`, `vim.json`) — no compat shims for older nvim.
- No hard dependency on plenary in runtime code; test-only is fine.
- User-facing entry points are commands + a `setup()` table; do not require the user to call internal modules.
