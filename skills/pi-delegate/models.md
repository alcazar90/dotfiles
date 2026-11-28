# Model aliases

Aliases are shorthand for the user. Resolve the alias to the **Model ID** and pass that
exact string to `pi --provider llama.cpp --model "<ID>"`.

| Alias        | Model ID                               | What it is                          | In pi? |
|--------------|----------------------------------------|-------------------------------------|--------|
| `liquid-24b` | `ggml-org/LFM2.5-24B-A2B-GGUF:Q4_K_M`  | Liquid LFM2.5 24B (A2B MoE), Q4_K_M | yes    |
| `qwen-27b`   | `ggml-org/Qwen3.8-27B-GGUF:Q4_K_M`     | Qwen3.8 27B dense, Q4_K_M           | not yet in `pi --list-models`; in llama cache |

`liquid`, `lfm` map to `liquid-24b`; `qwen` maps to `qwen-27b`. Prefer the fast MoE
(`liquid-24b`) for mechanical edits; use `qwen-27b` when it needs more reasoning.

Aliases live only here. `pi-run.sh` takes a full model ID, so resolve before calling it.
If the user did not name a model, ask (see SKILL.md step 0) instead of defaulting.

Rules:
- Resolve whatever the user says (alias, partial name, "the liquid one") to the full ID.
  If it is ambiguous, pick the closest row and state which ID you chose.
- If the ID is not in `llama serve --cache-list`, ask the user instead of guessing one.
- If it is in the cache but not in `pi --list-models`, try it anyway; pi refreshes its
  list from the server. If pi rejects it, add it to `~/.pi/agent/models-store.json`
  (copy the existing entry and change `id`/`name`).
- To add a new row: `llama serve --cache-list`, pick an alias, add it above.

