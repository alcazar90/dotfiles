#!/bin/bash
# pi-run.sh: send a task file to pi (local llama.cpp model) in a Rex tab and block until pi is done.
#
# usage: pi-run.sh [-s SESSION] -m MODEL_ID [-t SECONDS] [-r] TASK_FILE
#   -s  Rex session (default: the session of the calling pane)
#   -m  full model ID (required; alias resolution is done by the caller, see models.md)
#   -t  give up after SECONDS (default 900)
#   -r  reuse the existing pi tab (keeps pi's context): for fix rounds only.
#       Default is a FRESH pi session in the current directory for every task.
#
# One tab per model, labelled "pi-<model name>". Default: close it and start a fresh pi
# (clean context, correct cwd). With -r, send the task to the running pi instead.
# Starts the llama server and loads the model if needed. Waits on pi's own status
# (terminal.program_status_changed), not on screen text. Rex shows its own tab
# indicator and notification when pi finishes, so this script does not notify.
#
# exit: 0 done, 1 pi reported error/blocked, 2 timeout, 3 setup failure
set -u

SESSION="" MODEL_IN="" TIMEOUT=900 REUSE=0
while getopts "s:m:t:r" o; do
  case $o in s) SESSION=$OPTARG;; m) MODEL_IN=$OPTARG;; t) TIMEOUT=$OPTARG;; r) REUSE=1;; *) exit 3;; esac
done
shift $((OPTIND-1))
TASK="${1:-}"
[ -f "$TASK" ] || { echo "pi-run: task file not found: $TASK" >&2; exit 3; }
case "$TASK" in /*) ;; *) TASK="$PWD/$TASK";; esac

# model: full ID only; Claude resolves aliases (models.md) or asks the user
case "$MODEL_IN" in
  */*) MODEL=$MODEL_IN; ALIAS=$(echo "$MODEL" | sed 's|.*/||; s|:.*||' | tr 'A-Z' 'a-z');;
  *) echo "pi-run: -m <full model ID> required, e.g. ggml-org/LFM2.5-24B-A2B-GGUF:Q4_K_M (see: llama serve --cache-list)" >&2; exit 3;;
esac

[ -n "$SESSION" ] || SESSION=$(rex whoami --json | jq -r '.session_id // .session.id // empty')
[ -n "$SESSION" ] || { echo "pi-run: no session; pass -s" >&2; exit 3; }
LABEL="pi-$ALIAS"
URL=http://127.0.0.1:9931

# 1. server up
if ! curl -s -m 2 "$URL/v1/models" >/dev/null 2>&1 || [ -z "$(curl -s -m 2 $URL/v1/models)" ]; then
  echo "pi-run: starting llama server"
  rex run -s "$SESSION" --label llama-server --focus=false -- llama serve --no-models-autoload >/dev/null
  for _ in $(seq 1 30); do [ -n "$(curl -s -m 2 $URL/v1/models)" ] && break; sleep 1; done
  [ -n "$(curl -s -m 2 $URL/v1/models)" ] || { echo "pi-run: server did not start" >&2; exit 3; }
fi

# 2. model loaded
status() { curl -s -m 3 "$URL/v1/models" | jq -r --arg id "$MODEL" '.data[] | select(.id==$id) | .status.value'; }
[ -n "$(status)" ] || { echo "pi-run: $MODEL not in llama cache (llama serve --cache-list)" >&2; exit 3; }
if [ "$(status)" != loaded ]; then
  echo "pi-run: loading $ALIAS"
  curl -s -X POST "$URL/models/load" -H 'Content-Type: application/json' -d "{\"model\":\"$MODEL\"}" >/dev/null
  for _ in $(seq 1 100); do [ "$(status)" = loaded ] && break; sleep 3; done
  [ "$(status)" = loaded ] || { echo "pi-run: model failed to load" >&2; exit 3; }
fi

# 3. pi tab (label exists == pi still running, since the tab closes when pi exits)
exists() { rex block inspect -s "$SESSION" "$LABEL" --json >/dev/null 2>&1; }
if [ $REUSE = 0 ] && exists; then
  rex send -s "$SESSION" -b "$LABEL" "/quit"; sleep 0.5
  for _ in 1 2; do rex send-key -s "$SESSION" -b "$LABEL" enter; for _ in 1 2 3 4 5; do exists || break; sleep 1; done; exists || break; done
  exists && { echo "pi-run: could not close the old pi tab" >&2; exit 3; }
fi
[ $REUSE = 1 ] && ! exists && echo "pi-run: no pi tab to reuse; starting fresh"
NEW=0
if ! exists; then
  NEW=1
  rex run -s "$SESSION" --label "$LABEL" --cwd "$PWD" --focus=false -- \
    pi --provider llama.cpp --model "$MODEL" >/dev/null || { echo "pi-run: could not open pi tab" >&2; exit 3; }
  for _ in $(seq 1 30); do rex capture -s "$SESSION" -b "$LABEL" --trim 2>/dev/null | grep -q "$ALIAS\|llama" && break; sleep 1; done
  sleep 2
fi
BLOCK=$(rex block inspect -s "$SESSION" "$LABEL" --json | jq -r '.block.block_id')
[ -n "$BLOCK" ] && [ "$BLOCK" != null ] || { echo "pi-run: cannot resolve pi block id" >&2; exit 3; }

# 4. subscribe first, then send, so the 'working' event cannot be missed
OUT=$(mktemp)
cat > "$OUT.lua" <<EOF
local deadline = os.time() + $TIMEOUT
local saw_working = false
while true do
  local left = deadline - os.time()
  if left <= 0 then return "timeout" end
  local ev = rex.wait("terminal.program_status_changed", { block_id = "$BLOCK" }, left)
  if ev == nil then return "timeout" end
  local st = ev.record and ev.record.state
  if st == "working" then saw_working = true end
  if st == "error" or st == "blocked" then return st end
  if st == "done" and saw_working then return "done" end
end
EOF
rex do -s "$SESSION" --timeout "$((TIMEOUT+30))s" "$OUT.lua" > "$OUT" 2>&1 &
WAITER=$!
sleep 2
rex send -s "$SESSION" -b "$BLOCK" "Read $TASK and do every item, then run its check and report the exact output."
rex send-key -s "$SESSION" -b "$BLOCK" enter
echo "pi-run: $ALIAS working on $TASK (tab: $LABEL)"
wait $WAITER
RESULT=$(tr -d '"\n' < "$OUT")
rm -f "$OUT" "$OUT.lua"

# 5. report
echo "pi-run: result=$RESULT"
echo "----- last of pi's screen -----"
rex capture -s "$SESSION" -b "$BLOCK" --trim | grep -v '^─*$' | tail -25
case "$RESULT" in done) exit 0;; timeout) exit 2;; *) exit 1;; esac
