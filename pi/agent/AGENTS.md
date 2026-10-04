# Global Preferences

## Search tools

- Prefer `rg` (ripgrep) over `grep` for all text searching. It is installed and available on PATH.
- Use `find`/`fd` for filename search; prefer `fd` if available. Use `grep` only when you specifically need POSIX behavior or ripgrep is unavailable.

## Python

- Only ever run Python with `uv`, e.g. `uv run python script.py`, `uv run pytest`, or `uv run --with <pkg> python -c "..."`. Never invoke bare `python`/`python3`/`pip`.

## Subagents

- Use the package's native guidance. Model presets aren't roles: give each child its task, file ownership and any instructions it needs. Prefer MiMo/DeepSeek Flash for bounded work, Luna for harder reasoning, and Sol for substantial final reviews.
- Luna/Sol use the parent's provider (`-or` or `-gh`) unless the user chooses otherwise. Flash presets use OpenRouter credit. Announce the model and purpose; ask before using Sol unless the user already requested the review. No random picks or silent expensive fallback.
- The parent owns integration. Children may edit assigned files; don't overlap edits or discard local changes. Get changed files, actual checks and blockers in their reports. Respond to caller_ping; stop stuck work rather than burning retries.
- Use native fresh-context defaults; resume a reviewer for follow-ups when useful. No recursive delegation or Fusion in children. These are workflow rules, not hard spending caps.
- Keep You Should Know's native same-model default. Check `/ysk status` and its private usage log; use `/ysk off` if it costs too much.

## Local patches

- The `pi-chrome-devtools` MCP is locally patched to launch its managed browser with
  `--disable-sync`, keeping it isolated from the Edge profile. The patch is lost on
  package updates; see `~/.pi/agent/pi-chrome-devtools.patch.md` to re-apply.
