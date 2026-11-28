---
name: pi-delegate
description: Hand coding work to the local llama.cpp model (through pi, in a visible Rex tab) so Claude spends its own tokens on writing the task and reviewing, not on editing. Use whenever the user says "run pi", "have pi do it", "use the local model", "delegate to pi", "offload this", "save tokens on this edit", or names a model alias (see models.md), even if they do not mention pi or Rex explicitly.
---

# Delegating work to a local model: Claude + Rex + pi + llama.cpp

Claude writes the task and reviews. Pi (a local llama.cpp model in a visible Rex tab)
does the editing. The point is to spend pi's tokens, not Claude's, and to see how well
the local model really does: if Claude quietly patches pi's mistakes, the user never
learns where the model fails and the token saving disappears. So defects go back to pi
(Review loop), and Claude edits the project files itself only when the user says so.

## Workflow

0. **Pick the model.** If the user named one (alias, partial name, "the liquid one"),
   resolve it to a full ID with `models.md`. If they did not, run
   `llama serve --cache-list`: with one cached model, use it and say which; with several,
   ask with AskUserQuestion, one option per model (alias and one-line description from
   `models.md`; the "use for" column says which to recommend). Reuse the answer for the
   session unless the user changes it. A cached model that `models.md` lacks is still
   valid: offer it by its ID and add a row after.
1. **Write the task file** in the scratchpad from `references/task-template.md`:
   numbered, concrete, with exact code for each change where possible, ending with a
   **check command that prints OK**. Small models need this. Make the check strict: if
   existing behavior must not change, compare against the original (see the template).
   A check that only greps for expected strings lets pi report OK while regressing things.
2. **Snapshot** every file pi may touch (`cp -p f f.orig` in the scratchpad, or rely on
   `git diff` in a repo). Without it you cannot see what pi really changed, or catch
   edits outside the task. Many directories are not git repos.
3. **Run it** (in the project dir, as a background Bash call so you are notified on exit):
   ```sh
   ~/.claude/skills/pi-delegate/pi-run.sh [-s SESSION] -m MODEL_ID [-t SECONDS] [-r] [-l LOG] /abs/task.md
   ```
   - `-m` takes the full model ID from step 0 (required; no default, no alias handling).
   - `-s` is the Rex session (default: the session of your own pane).
   - Default: a **fresh** pi session for every task. The old `pi-<model name>` tab is
     closed and a new one opens in the current directory, so pi starts with only the
     task file, no memory of earlier work, and the right cwd.
   - `-r` reuses the running pi tab so it keeps its context. Use it **only for fix
     rounds** (`fix-N.md`) of the same task; never for a new, unrelated task.
   - `-l` is where pi's full screen and scrollback are saved (default `<task>.log`). The
     script prints only the last 25 lines; read the log when you need to know what pi did.
   - One pi tab exists per model, so do not run two tasks on the same model at once.
     Run them in sequence, or use the other model for the second task.

   The script starts the llama server and loads the model if needed, then waits on pi's
   own reported status (not screen text) and prints pi's last screen. Rex shows the tab
   indicator and a macOS notification when pi finishes (Rex setting: Notifications >
   Program Activity > Show system notifications); do not send your own.

   | Exit | Meaning | What to do |
   |------|---------|------------|
   | 0 | pi reported done | Verify (step 4). Done does not mean correct. |
   | 1 | pi reported error/blocked, or exited | Read the log, then write a fix file with what blocked it. |
   | 2 | timeout (pi was sent Escape) | Read the log. If pi was making progress, rerun with `-r` and a larger `-t`; if it looped, treat as a failed round. |
   | 3 | setup failed (server, model, tab) | Not pi's fault: read the message, fix the environment, rerun. Does not count as a failed round. |
4. **Verify yourself**: diff against the snapshot, compile, run the check and the real
   program. Do not trust pi's summary; it often says done after only checking syntax.
5. **If anything is incomplete or wrong, send it back to pi** (Review loop).

## Review loop

1. List each defect: what you ran, what you expected, the exact output, file/function.
2. Write `fix-N.md` from `references/fix-template.md`: numbered items with symptom and
   acceptance check, exact code where useful, what already works (so pi does not undo
   it), and a final command that prints OK only when every item passes.
3. Run `pi-run.sh -r ... fix-N.md` (same tab, so pi keeps context) and re-verify.
4. Escalate detail each round: symptom, then expected behavior, then exact code. After
   3 failed rounds, or if pi loops, stop and tell the user; offer `qwen-27b` (its full ID,
   fresh session) or patching it yourself.
5. A one-line fix still goes back to pi: put it in the fix file.

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
  Protocol; read it with `rex block call -s S -b B program_status`. The script snapshots
  that record before sending the task and treats a changed `done`/`error`/`blocked`
  record as the result, so a fast run cannot be missed.

## Gotchas

- `rex send-key` takes one key per call; `rex send` for text. Never send input to your
  own pane.
- Wrapping `rex send-key ...` in a zsh variable breaks word splitting; use a function.
- Task files must use absolute paths. Pi runs in the cwd where `pi-run.sh` was called.
- Pi often reports "done" with only some edits landed. Always run the real program.
- Tabs: `pi-run.sh` keeps one `pi-<model name>` tab per model. A fresh run interrupts pi
  (Escape), exits it with `/quit` (Ctrl+C does not exit pi), and as a last resort closes
  the tab with `rex block close`. Stray tabs with other labels are yours to close with
  `rex block close <label>`.
- How the task reaches pi: the script types "Read <abs task path> and do every item, then
  run its check"; pi opens the file with its read tool. Task files in the scratchpad are
  temporary, so put exact code and absolute paths in them.
- Pi runs with the user's permissions in the cwd and nothing sandboxes it. Keep tasks
  scoped to the project dir, and do not hand it destructive or credential-touching work.
- Untested paths (as of the last edit): exit codes 1 and 2 and the Escape-before-`/quit`
  close. The status polling replaced an event waiter and has had only a syntax check.
  Run one deliberately failing task and one with `-t 5` before relying on them.
