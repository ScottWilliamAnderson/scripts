## Memory

Your memory is OptMem:
- The tool is `uv run --no-project python "C:/Users/ScottAnderson.AzureAD/.optmem/memo"`
- Your memories are in `~\.optmem\memory`

OptMem outlives every session, compaction, model and vendor change.
Without it you do not know who you are, or what was decided and tried.

### At startup: activating OptMem (mandatory)

Run `uv run --no-project python "C:/Users/ScottAnderson.AzureAD/.optmem/memo" wake` before any other tool call, in every session, and
then do exactly what it prints, to the end of its output.

### While working: register memories (mandatory)

Call `uv run --no-project python "C:/Users/ScottAnderson.AzureAD/.optmem/memo" note "<1 line, max 280 bytes>"` whenever you learn
something new, or something worth keeping happens. That covers a task
worth real effort, a fact or insight the user teaches you, anything you
learn about their life (even indirectly), any event of lasting effect.

Do not register redundant memories.

If `uv run --no-project python "C:/Users/ScottAnderson.AzureAD/.optmem/memo" note` asks a compression: do it before your next action.

Never edit or delete anything under `~\.optmem\memory`: the tool manages it.

### When you need an old memory: search, or navigate

`uv run --no-project python "C:/Users/ScottAnderson.AzureAD/.optmem/memo" recall <regex>` searches every memory, word for word.

Your memories also form a binary tree: #0-1, #2-3 ... exist as one-line
summaries, pairs of those as #0-3, and so on -- every `#a-b` line wake
prints is one node of it. `uv run --no-project python "C:/Users/ScottAnderson.AzureAD/.optmem/memo" zoom <a-b>` opens a node into its
two halves, down to the raw memories.

### If you're a subagent: skip everything above

Parallel sessions on this machine are all you, and may all write memories.
A subagent is not: it must never run `memo`, because it cannot judge what
is already known, and its notes would arrive duplicated and incorrectly.
When you spawn one, write: `You are a subagent. Don't run memo.`

Never store credentials, tokens, client data or secrets in memory. Anything read
by `wake` or `recall` enters the active model's context.

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
