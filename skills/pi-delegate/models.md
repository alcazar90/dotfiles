# Model aliases

Aliases are shorthand for the user. Resolve the alias to the **Model ID** and pass that
exact string to `pi-run.sh -m` (it runs `pi --provider llama.cpp --model "<ID>"`).

This file is the single source of truth for aliases; keep copies elsewhere (CLAUDE.md,
the skill description) to a pointer here rather than a list.

| Alias        | Also accepts   | Model ID                              | What it is                          | Use for                   |
|--------------|----------------|---------------------------------------|-------------------------------------|---------------------------|
| `liquid-24b` | `liquid`, `lfm`| `ggml-org/LFM2.5-24B-A2B-GGUF:Q4_K_M` | Liquid LFM2.5 24B (A2B MoE), Q4_K_M | mechanical edits (fast) (Recommended) |
| `qwen-27b`   | `qwen`         | `ggml-org/Qwen3.8-27B-GGUF:Q4_K_M`    | Qwen3.8 27B dense, Q4_K_M           | harder reasoning (slower) |

Rules:
- Resolve whatever the user says (alias, partial name, "the liquid one") to the full ID.
  If it is ambiguous, pick the closest row and state which ID you chose.
- If the ID is not in `llama serve --cache-list`, ask the user instead of guessing one.
- If it is in the cache but pi rejects it, `pi --list-models` may not list it yet: pi
  refreshes from the server, but if it still refuses, add it to
  `~/.pi/agent/models-store.json` (copy the existing entry and change `id`/`name`).
- To add a new row: `llama serve --cache-list`, pick an alias, add it above.
- If the user did not name a model, follow SKILL.md step 0 instead of defaulting.
