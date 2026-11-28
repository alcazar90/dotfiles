#!/bin/bash
# pi-run.sh: send a task file to pi (local llama.cpp model) in a Rex tab and block until pi is done.
#
# usage: pi-run.sh [-s SESSION] -m MODEL_ID [-t SECONDS] [-r] [-l LOGFILE] TASK_FILE
#   -s  Rex session (default: the session of the calling pane)
#   -m  full model ID (required; alias resolution is done by the caller, see models.md)
#   -t  give up after SECONDS (default 900). On timeout pi is interrupted (Escape).
#   -r  reuse the existing pi tab (keeps pi's context): for fix rounds only.
#       Default is a FRESH pi session in the current directory for every task.
#   -l  write pi's full screen + scrollback here (default: <task file>.log)
#
# One tab per model, labelled "pi-<model name>". Default: close it and start a fresh pi
# (clean context, correct cwd). With -r, send the task to the running pi instead.
# Starts the llama server and loads the model if needed. Waits on pi's own reported
# status (the program_status block method), never on screen text, and decides "done"
# by a status change since the task was sent, so a fast run cannot be missed.
# Rex shows its own tab indicator and notification when pi finishes, so this script
# does not notify.
#
# exit: 0 done, 1 pi reported error/blocked, 2 timeout, 3 setup failure
set -u

SESSION="" MODEL_IN="" TIMEOUT=900 REUSE=0 LOG=""
while getopts "s:m:t:l:r" o; do
  case $o in s) SESSION=$OPTARG;; m) MODEL_IN=$OPTARG;; t) TIMEOUT=$OPTARG;; l) LOG=$OPTARG;; r) REUSE=1;; *) exit 3;; esac
done
shift $((OPTIND-1))
TASK="${1:-}"
[ -f "$TASK" ] || { echo "pi-run: task file not found: $TASK" >&2; exit 3; }
case "$TASK" in /*) ;; *) TASK="$PWD/$TASK";; esac
[ -n "$LOG" ] || LOG="$TASK.log"

# model: full ID only; Claude resolves aliases (models.md) or asks the user
case "$MODEL_IN" in
  */*) MODEL=$MODEL_IN; MODEL_NAME=$(echo "$MODEL" | sed 's|.*/||; s|:.*||' | tr 'A-Z' 'a-z');;
  *) echo "pi-run: -m <full model ID> required, e.g. ggml-org/LFM2.5-24B-A2B-GGUF:Q4_K_M (see: llama serve --cache-list)" >&2; exit 3;;
esac

[ -n "$SESSION" ] || SESSION=$(rex whoami --json | jq -r '.session_id // .session.id // empty')
[ -n "$SESSION" ] || { echo "pi-run: no session; pass -s" >&2; exit 3; }
LABEL="pi-$MODEL_NAME"
URL=http://127.0.0.1:9931

models_json() { curl -s -m 3 "$URL/v1/models"; }
server_up() { models_json | jq -e '.data' >/dev/null 2>&1; }

# 1. server up (a stale "llama-server" tab is closed first so dead tabs do not pile up)
if ! server_up; then
  echo "pi-run: starting llama server"
  rex block close -s "$SESSION" llama-server >/dev/null 2>&1
  rex run -s "$SESSION" --label llama-server --focus=false -- llama serve --no-models-autoload >/dev/null
  for _ in $(seq 1 30); do server_up && break; sleep 1; done
  server_up || { echo "pi-run: llama server did not start (look at the llama-server tab)" >&2; exit 3; }
fi

# 2. model loaded
status() { models_json | jq -r --arg id "$MODEL" '.data[]? | select(.id==$id) | .status.value'; }
[ -n "$(status)" ] || { echo "pi-run: $MODEL is not in the server's model list (llama serve --cache-list)" >&2; exit 3; }
if [ "$(status)" != loaded ]; then
  echo "pi-run: loading $MODEL_NAME"
  RESP=$(curl -s -m 10 -X POST "$URL/models/load" -H 'Content-Type: application/json' -d "{\"model\":\"$MODEL\"}")
  for _ in $(seq 1 100); do [ "$(status)" = loaded ] && break; sleep 3; done
  [ "$(status)" = loaded ] || { echo "pi-run: model failed to load (load response: $RESP)" >&2; exit 3; }
fi

# 3. pi tab (label exists == pi still running, since the tab closes when pi exits)
exists() { rex block inspect -s "$SESSION" "$LABEL" --json >/dev/null 2>&1; }
pi_state() { rex block call -s "$SESSION" -b "$BLOCK" program_status 2>/dev/null | jq -r '.records[0] | "\(.state // "none") \(.updated_at // "")"'; }
if [ $REUSE = 0 ] && exists; then
  # Escape first: a pi that is still working (e.g. after a timeout) would otherwise
  # queue /quit as a prompt instead of exiting.
  rex send-key -s "$SESSION" -b "$LABEL" escape; sleep 1
  rex send -s "$SESSION" -b "$LABEL" "/quit"; sleep 0.5
  for _ in 1 2; do rex send-key -s "$SESSION" -b "$LABEL" enter; for _ in 1 2 3 4 5; do exists || break; sleep 1; done; exists || break; done
  # last resort: closing the block ends the program running in it
  exists && { rex block close -s "$SESSION" "$LABEL" >/dev/null 2>&1; sleep 1; }
  exists && { echo "pi-run: could not close the old pi tab" >&2; exit 3; }
fi
[ $REUSE = 1 ] && ! exists && echo "pi-run: no pi tab to reuse; starting fresh"
FRESH=0
if ! exists; then
  FRESH=1
  rex run -s "$SESSION" --label "$LABEL" --cwd "$PWD" --focus=false -- \
    pi --provider llama.cpp --model "$MODEL" >/dev/null || { echo "pi-run: could not open pi tab" >&2; exit 3; }
fi
BLOCK=$(rex block inspect -s "$SESSION" "$LABEL" --json | jq -r '.block.block_id')
[ -n "$BLOCK" ] && [ "$BLOCK" != null ] || { echo "pi-run: cannot resolve pi block id" >&2; exit 3; }

# a new pi needs a moment before it accepts input; wait (max 20s) until it reports a state
if [ $FRESH = 1 ]; then
  for _ in $(seq 1 20); do
    case "$(pi_state)" in none*|"") sleep 1;; *) break;; esac
  done
  sleep 1
fi

# 4. snapshot pi's status, send the task, then poll for a status CHANGE. Comparing
#    against the snapshot (not a 'working' event we might miss) means a stale 'done'
#    from before cannot be mistaken for the new result, and a fast run cannot be missed.
BEFORE=$(pi_state)
rex send -s "$SESSION" -b "$BLOCK" "Read $TASK and do every item, then run its check and report the exact output."
rex send-key -s "$SESSION" -b "$BLOCK" enter
echo "pi-run: $MODEL_NAME working on $TASK (tab: $LABEL)"

RESULT=timeout
DEADLINE=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  sleep 2
  exists || { RESULT=error; echo "pi-run: pi exited unexpectedly" >&2; break; }
  NOW=$(pi_state)
  [ "$NOW" = "$BEFORE" ] && continue
  case "${NOW%% *}" in
    done) RESULT=done; break;;
    error|blocked) RESULT=${NOW%% *}; break;;
  esac
done
# do not leave a runaway pi behind after a timeout: interrupt it so the next run starts clean
[ "$RESULT" = timeout ] && rex send-key -s "$SESSION" -b "$BLOCK" escape

# 5. report: full capture to the log, the tail to stdout
rex capture -s "$SESSION" -b "$BLOCK" --trim > "$LOG" 2>/dev/null
echo "pi-run: result=$RESULT"
echo "pi-run: full pi screen + scrollback: $LOG"
echo "----- last of pi's screen -----"
grep -v '^─*$' "$LOG" | tail -25
case "$RESULT" in done) exit 0;; timeout) exit 2;; *) exit 1;; esac
