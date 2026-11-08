#!/usr/bin/env bash
# spawn-worker.sh — hand one task to a background Claude session (the PM's
# "assign to an engineer" step for /advisor:next).
#
# Given a task (a folder, or a single .md file) under the tasks root, this:
#   1. promotes a single-file task to its own folder (so the worker gets a clean,
#      per-task conversation history — Claude groups history by cwd),
#   2. appends the brief to <task>/TASK.md,
#   3. refuses if a worker is already live there (the PM must SendMessage it —
#      `claude --resume` on a live session starts a *copy*),
#   4. otherwise starts `claude --bg` in the task folder, resuming the task's
#      newest past conversation when there is one.
#
# Workers start in `manual` permission mode (override: ADVISOR_WORKER_MODE), so
# a worker can edit even when the user's default mode is `plan`.
#
# Usage: spawn-worker.sh <task-path> <worker-name> <brief-file> --tasks-root <dir> [--repo <dir>]
#   --tasks-root  the tasks root (next-context.sh's TASKS_ROOT); the task must sit inside it.
#
# Env:   ADVISOR_WORKER_MODE  permission mode (default: manual)
#
# Stdout on success (key=value lines, final line SPAWN_WORKER_OK):
#   TASK_DIR=<dir>
#   PROMOTED=<old file> -> <new file>      # only when a single-file task moved
#   RESUMED=<session uuid | NONE>
#   WORKER_ID=<short id from `claude agents`>
#   WORKER_NAME=<-n name; Claude may auto-rename it later — track the id>
#   ATTACH=claude attach <id>
#   SPAWN_WORKER_OK
# Exit 3 with `WORKER_LIVE id=<id> status=<status>` on stdout if a worker is
# already live in the task folder (not an error — the caller should message it).
# Exit non-zero with a specific reason on stderr otherwise.
set -euo pipefail

fail() { echo "SPAWN_WORKER FAILED: $*" >&2; exit 1; }

USAGE="usage: spawn-worker.sh <task-path> <worker-name> <brief-file> --tasks-root <dir> [--repo <dir>]"
TASK_PATH="${1:?$USAGE}"
NAME="${2:?$USAGE}"
BRIEF="${3:?$USAGE}"
shift 3

REPO=""
TASKS_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2:?--repo needs a directory}"; shift 2 ;;
    --tasks-root) TASKS_ROOT="${2:?--tasks-root needs a directory}"; shift 2 ;;
    *) fail "unknown argument '$1'." ;;
  esac
done

command -v claude >/dev/null 2>&1 || fail "claude not found on PATH."
command -v python3 >/dev/null 2>&1 || fail "python3 not found on PATH."
[ -f "$BRIEF" ] || fail "brief file '$BRIEF' not found."
[ -z "$REPO" ] || [ -d "$REPO" ] || fail "--repo '$REPO' is not a directory."

[ -n "$TASKS_ROOT" ] || fail "--tasks-root is required. $USAGE"
ROOT="$TASKS_ROOT"
[ -d "$ROOT" ] || fail "tasks root '$ROOT' is not a directory."
ROOT="$(cd "$ROOT" && pwd -P)"
MODE="${ADVISOR_WORKER_MODE:-manual}"

# Resolve the task path and keep it inside the tasks root — this script moves
# files, so it must never act on anything outside.
if [ -d "$TASK_PATH" ]; then
  TASK_DIR="$(cd "$TASK_PATH" && pwd -P)"
elif [ -f "$TASK_PATH" ]; then
  TASK_DIR=""
  SRC_FILE="$(cd "$(dirname "$TASK_PATH")" && pwd -P)/$(basename "$TASK_PATH")"
else
  fail "task path '$TASK_PATH' does not exist."
fi
CHECK="${TASK_DIR:-$SRC_FILE}"
case "$CHECK" in
  "$ROOT"/*) : ;;
  *) fail "'$CHECK' is outside the tasks root '$ROOT'." ;;
esac

# Promote a single-file task: tasks/foo.md -> tasks/foo/foo.md. A folder that
# does not exist yet cannot hold a live worker, so promoting before the live
# check is safe.
PROMOTED=""
if [ -z "$TASK_DIR" ]; then
  base="$(basename "$SRC_FILE")"
  stem="${base%.*}"
  TASK_DIR="$(dirname "$SRC_FILE")/$stem"
  [ ! -e "$TASK_DIR" ] || fail "cannot promote '$SRC_FILE': '$TASK_DIR' already exists."
  mkdir "$TASK_DIR"
  mv "$SRC_FILE" "$TASK_DIR/$base"
  PROMOTED="$SRC_FILE -> $TASK_DIR/$base"
fi

# A live worker in this folder? `claude agents --json` lists active sessions
# only (no --all). An idle background session still counts as running, and a
# `--resume` of it would start a copy, so hand control back to the caller.
agents_json="$(claude agents --json --cwd "$TASK_DIR")" || fail "'claude agents --json' failed; cannot tell whether a worker is already live in '$TASK_DIR'."
live="$(printf '%s' "$agents_json" | python3 -I -c '
import json, sys
rows = json.load(sys.stdin)
for r in rows:
    print("id=%s status=%s" % (r.get("id"), r.get("status")))
    break
')" || fail "could not parse 'claude agents --json' output."
if [ -n "$live" ]; then
  echo "WORKER_LIVE $live"
  exit 3
fi

# Brief -> TASK.md (append; the folder may already hold earlier steps).
{
  echo ""
  echo "## $(date '+%Y-%m-%d %H:%M') — step from the PM"
  echo ""
  cat "$BRIEF"
} >> "$TASK_DIR/TASK.md"

# Newest past conversation for this folder, if any. Claude stores history in
# ~/.claude/projects/<cwd with every non-alphanumeric char replaced by '-'>/.
ENC="$(printf '%s' "$TASK_DIR" | sed 's/[^A-Za-z0-9]/-/g')"
HIST="$HOME/.claude/projects/$ENC"
RESUME_ID="NONE"
if [ -d "$HIST" ]; then
  newest="$(ls -t "$HIST"/*.jsonl 2>/dev/null | head -1 || true)"
  if [ -n "$newest" ]; then RESUME_ID="$(basename "$newest" .jsonl)"; fi
fi

PROMPT="Read TASK.md in this folder and do the latest step described there. When you finish or get blocked, overwrite STATUS.md in this folder with exactly three lines: 'done: ...', 'blocked: ...', 'next: ...'. Never post to Jira, Slack or GitHub without the user's explicit OK."

args=(--bg --permission-mode "$MODE" -n "$NAME")
[ -z "$REPO" ] || args+=(--add-dir "$REPO")
[ "$RESUME_ID" = "NONE" ] || args+=(--resume "$RESUME_ID")

out="$(cd "$TASK_DIR" && claude "${args[@]}" "$PROMPT" 2>&1)" || fail "claude --bg failed: $out"
ID="$(printf '%s\n' "$out" | sed -n 's/^backgrounded · \([0-9a-f]\{8\}\).*/\1/p' | head -1)"
[ -n "$ID" ] || fail "could not read the worker id from claude's output: $out"

echo "TASK_DIR=$TASK_DIR"
if [ -n "$PROMOTED" ]; then echo "PROMOTED=$PROMOTED"; fi
echo "RESUMED=$RESUME_ID"
echo "WORKER_ID=$ID"
echo "WORKER_NAME=$NAME"
echo "ATTACH=claude attach $ID"
echo "STEP SPAWN-WORKER: worker=$ID, resumed=$RESUME_ID, mode=$MODE · ${SECONDS}s · OK"
echo "SPAWN_WORKER_OK"
