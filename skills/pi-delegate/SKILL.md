---
name: pi-delegate
description: Delegate coding work to the local llama.cpp model through pi in a visible Rex tab. One script (pi-run.sh) starts the server, loads the model, sends the task and blocks until pi reports done; then review the result and send defects back to pi instead of fixing them. Use when the user says "run pi", "use the local model", "delegate to pi", or names a model alias (liquid-24b, qwen-27b, liquid, lfm, qwen).
---

# Delegating work to a local model: Claude + Rex + pi + llama.cpp

Claude writes the task and reviews. Pi (running a local llama.cpp model in a visible
Rex tab) does the editing. The goal is to spend pi's tokens, not Claude's.

## Workflow

0. **Pick the model.** If the user named one (alias, partial name, "the liquid one"),
   resolve it to a full ID with `models.md`. If they did not, do not guess: run
   `llama serve --cache-list` and ask with AskUserQuestion, one option per cached model
   (use the alias and a one-line description from `models.md`; mark `liquid-24b`
   "(Recommended)" for mechanical edits, `qwen-27b` for harder reasoning). Reuse the
   answer for the rest of the session unless the user changes it. A cached model that
   `models.md` lacks is still valid: offer it by its ID and add a row after.
1. **Write the task file** in the scratchpad: numbered, concrete, with exact code for
   each change where possible, ending with a **check command that prints OK**. Small
   models need this. Make the check strict: if existing behavior must not change, back
   up the original file first and have the check compare new output to the original's
   (e.g. strip ANSI codes, require identical text). A check that only greps for expected
   strings lets pi report OK while regressing things.
2. **Run it** (in the project dir, as a background Bash call so you are notified on exit):
   ```sh
   ~/.claude/skills/pi-delegate/pi-run.sh [-s SESSION] -m MODEL_ID [-t SECONDS] [-r] /abs/task.md
   ```
   - `-m` takes the full model ID from step 0 (required; no default, no alias handling).
   - `-s` is the Rex session (default: the session of your own pane).
   - Default: a **fresh** pi session for every task. The old `pi-<model name>` tab is
     closed (`/quit`) and a new one opens in the current directory, so pi starts with
     only the task file, no memory of earlier work, and the right cwd.
   - `-r` reuses the running pi tab so it keeps its context. Use it **only for fix
     rounds** (`fix-N.md`) of the same task; never for a new, unrelated task.
   - Exit: 0 done, 1 pi reported error/blocked, 2 timeout, 3 setup failure.
   The script starts the llama server and loads the model if needed, waits on pi's own
   status events (not screen text), then prints pi's last screen. Rex shows the tab
   indicator and a macOS notification when pi finishes (Rex setting: Notifications >
   Program Activity > Show system notifications); do not send your own.
3. **Verify yourself**: read the diff, compile, run the check and the real program.
   Do not trust pi's summary; it often says done after only checking syntax.
4. **If anything is incomplete or wrong, send it back to pi** (Review loop). Do NOT patch
   the project files yourself unless the user says to.

## Review loop

1. List each defect: what you ran, what you expected, the exact output, file/function.
2. Write `fix-N.md` in the scratchpad: numbered items with symptom and acceptance check,
   exact code where useful, what already works (so pi does not undo it), and a final
   command that prints OK only when every item passes.
3. Run `pi-run.sh -r ... fix-N.md` (same tab, so pi keeps context) and re-verify.
4. Escalate detail each round: symptom, then expected behavior, then exact code. After
   3 failed rounds, or if pi loops, stop and tell the user; offer `qwen-27b` (its full ID,
   fresh session) or patching it yourself.
5. A one-line fix still goes back to pi. If tempted to patch, put it in the fix file.

## How pi reaches the model (for debugging)

- Pi does not start llama.cpp; it talks to a llama.cpp router server at
  `http://127.0.0.1:9931` (`llama serve --no-models-autoload`). The script starts it in a
  `llama-server` tab if missing.
- With `--no-models-autoload`, pi fails with `400 model is not loaded` until the model is
  loaded: `curl -s -X POST http://127.0.0.1:9931/models/load -H 'Content-Type: application/json' -d '{"model":"<ID>"}'`.
  The script does this and waits for status `loaded`.
- `llama serve --cache-list` lists downloaded models; `curl -s :9931/v1/models` shows
  load status. `pi --list-models` only shows models registered in
  `~/.pi/agent/models-store.json`.
- Pi reports its state (working/done/error/blocked) to Rex via the Program Status
  Protocol: `rex block call -s S -b B program_status`. That is what the script waits on.

## Gotchas

- `rex send-key` takes one key per call; `rex send` for text. Never send input to your
  own pane.
- Wrapping `rex send-key ...` in a zsh variable breaks word splitting; use a function.
- Task files must use absolute paths. Pi runs in the cwd where `pi-run.sh` was called.
- Pi often reports "done" with only some edits landed. Always run the real program.
- Tabs: `pi-run.sh` keeps one `pi-<model name>` tab per model. A fresh run exits pi with
  `/quit` (Ctrl+C does not exit pi) and opens a new tab. Rex has no close-block command,
  so stray tabs from other labels must be closed by hand.
- How the task reaches pi: the script types "Read <abs task path> and do every item, then
  run its check"; pi opens the file with its read tool. Task files in the scratchpad are
  temporary, so put exact code and absolute paths in them.
- Untested paths: the exit codes 1 (pi error/blocked) and 2 (timeout).
