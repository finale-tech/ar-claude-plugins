#!/usr/bin/env python3
"""Extract Claude Code session messages for a given date across all projects.

Discovers sessions two ways and merges them: ~/.claude/history.jsonl (an index of
sessionId + project + timestamp) and a direct scan of the transcripts on disk.
Both routes bin events by the event's own timestamp, so a missing or partial index
costs speed, never coverage. Reads each session's JSONL file for user/assistant
messages and outputs structured text to stdout.

Usage: python3 extract_sessions.py [date]
  date: 'today' (default), 'yesterday', or YYYY-MM-DD

Path overrides (for testing, or for sandboxes where ~/.claude is not present) —
env vars take precedence over the defaults:
  CLAUDE_HISTORY_PATH, CLAUDE_PROJECTS_DIR
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

HISTORY_PATH = Path(os.environ.get("CLAUDE_HISTORY_PATH") or Path.home() / ".claude" / "history.jsonl")
PROJECTS_DIR = Path(os.environ.get("CLAUDE_PROJECTS_DIR") or Path.home() / ".claude" / "projects")
HOME_DIR = str(Path.home())

NOISE_PREFIXES = (
    "<command-message>",
    "<command-name>",
    "<local-command",
    "<task-notification",
    "<system-reminder>",
    "This session is being continued",
    "[Request interrupted",
)

MAX_MSG_LEN = 400
MAX_OUTPUT_BYTES = 50_000
TRUNCATED_MSG_LEN = 200


def parse_date(arg: str) -> str:
    """Return YYYY-MM-DD for the target date."""
    if not arg or arg == "today":
        return datetime.now().strftime("%Y-%m-%d")
    if arg == "yesterday":
        return (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
    datetime.strptime(arg, "%Y-%m-%d")
    return arg


def to_local(ts: str):
    """Parse an ISO timestamp (UTC 'Z' or with offset) and return it in local time.

    Returns an aware datetime in the machine's local zone, or None if unparseable.
    Naive stamps are assumed UTC. Binning on the local calendar date (not the UTC
    date) is what keeps a session that runs past a day boundary in the correct
    day's file.
    """
    if not ts:
        return None
    s = ts.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone()


def shorten_project(project_path: str) -> str:
    """Shorten a project path to just the last segment, or '(home)' for ~."""
    if project_path == HOME_DIR:
        return "(home)"
    return os.path.basename(project_path) or project_path


def discover_sessions(target_date: str) -> dict:
    """Read history.jsonl and return sessions matching the target date.

    Returns {sessionId: project_path} for sessions active on target_date.
    """
    sessions = {}
    if not HISTORY_PATH.exists():
        return sessions

    with open(HISTORY_PATH) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            ts_ms = entry.get("timestamp")
            if not ts_ms:
                continue

            entry_date = datetime.fromtimestamp(ts_ms / 1000).strftime("%Y-%m-%d")
            if entry_date != target_date:
                continue

            sid = entry.get("sessionId", "")
            project = entry.get("project", "")
            if sid and project:
                sessions[sid] = project

    return sessions


def session_file_path(project: str, session_id: str) -> Path:
    """Derive the session JSONL file path from project and session ID."""
    project_key = re.sub(r"[/._+ ]", "-", project)
    return PROJECTS_DIR / project_key / f"{session_id}.jsonl"


def day_start_epoch(target_date: str) -> float:
    """Epoch seconds for local midnight at the start of target_date."""
    naive = datetime.strptime(target_date, "%Y-%m-%d")
    return naive.astimezone().timestamp()


def scan_session_for_date(session_file: Path, target_date: str):
    """Return (has_events_on_target_date, project_path) for one transcript.

    Decides from the events' OWN timestamps, not from file metadata, and picks up
    the real project path from the transcript's `cwd` so this route labels projects
    the same way the history index does.
    """
    project = None
    hit = False
    try:
        with open(session_file, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if project is None and obj.get("cwd"):
                    project = obj["cwd"]
                if not hit and obj.get("type") in ("user", "assistant"):
                    ldt = to_local(obj.get("timestamp", ""))
                    if ldt is not None and ldt.strftime("%Y-%m-%d") == target_date:
                        hit = True
                # Both answers found — stop; the caller re-reads the file for the
                # events themselves. Matters because the caller runs once per date,
                # so a 7-day range would otherwise re-read every file to EOF 7 times.
                if hit and project is not None:
                    break
    except OSError:
        return False, None
    return hit, project


def discover_sessions_on_disk(target_date: str, already_found: set) -> dict:
    """Scan the transcripts on disk for sessions with events on target_date.

    Returns {sessionId: (file_path, project_path)} for sessions not in already_found.

    Decided by reading each transcript's event timestamps — the authoritative
    source. mtime is used only as a *lower bound* to skip files cheaply: a file's
    last write cannot precede the events it contains, so anything last modified
    before target_date's local midnight cannot hold events from that day. That is a
    sound bound; the old `mtime == target_date` equality was a proxy that silently
    disagreed with the data, dropping every session whose file was written on a
    later day (e.g. one that ran past midnight, or was resumed the next morning).
    """
    sessions = {}
    cutoff = day_start_epoch(target_date)
    for session_file in PROJECTS_DIR.glob("*/*.jsonl"):
        if "subagents" in session_file.parts:
            continue
        sid = session_file.stem
        if sid in already_found:
            continue
        try:
            if session_file.stat().st_mtime < cutoff:
                continue
        except OSError:
            continue
        hit, project = scan_session_for_date(session_file, target_date)
        if hit:
            sessions[sid] = (session_file, project or session_file.parent.name)
    return sessions


def extract_text_from_content(content) -> str:
    """Extract readable text from message content (string or block array)."""
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                text = block.get("text", "").strip()
                if text:
                    return text
    return ""


def is_noise(text: str) -> bool:
    """Return True if the text is a system/command noise message."""
    return any(text.startswith(prefix) for prefix in NOISE_PREFIXES)


def read_session(file_path: Path, project: str, target_date: str) -> list:
    """Read a session JSONL file and extract user/assistant events.

    Returns list of (local_datetime, role, project_short, text) tuples, keeping
    only events whose LOCAL calendar date equals target_date — so a session that
    spans multiple days contributes only its target_date events to that day's file.
    """
    events = []
    short_project = shorten_project(project)

    if not file_path.exists():
        print(f"WARNING: session file not found: {file_path}", file=sys.stderr)
        return events

    with open(file_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg_type = obj.get("type")
            if msg_type not in ("user", "assistant"):
                continue

            ts = obj.get("timestamp", "")
            if not ts:
                continue

            ldt = to_local(ts)
            if ldt is None or ldt.strftime("%Y-%m-%d") != target_date:
                continue

            msg = obj.get("message")
            if not isinstance(msg, dict):
                continue

            content = msg.get("content", "")
            text = extract_text_from_content(content)

            if not text:
                continue
            if is_noise(text):
                continue

            role = "USER" if msg_type == "user" else "ASSISTANT"

            if role == "USER" and len(text) < 10:
                continue
            if role == "ASSISTANT" and len(text) < 30:
                continue

            text = text[:MAX_MSG_LEN]
            events.append((ldt, role, short_project, text))

    return events


def format_output(target_date: str, session_count: int, all_events: list, discovery: str = "") -> str:
    """Format the extracted events as structured text."""
    all_events.sort(key=lambda e: e[0])
    project_names = sorted(set(e[2] for e in all_events))
    now_local = datetime.now().astimezone()

    lines = []
    lines.append("=== SESSION SUMMARY ===")
    lines.append(f"Date: {target_date} (local {now_local.strftime('%Z%z')})")
    lines.append(f"Generated: {now_local.strftime('%Y-%m-%dT%H:%M%z')}")
    lines.append(f"Sessions found: {session_count}")
    lines.append(f"Events: {len(all_events)}")
    lines.append(f"Projects: {', '.join(project_names) if project_names else 'none'}")
    # State which discovery route(s) ran, so a caller can never mistake thin
    # coverage for complete coverage (guardrails.md #3: no silent skips).
    if discovery:
        lines.append(f"Discovery: {discovery}")
    lines.append("")

    total_size = 0
    truncate_aggressively = False

    for ldt, role, project, text in all_events:
        if truncate_aggressively:
            text = text[:TRUNCATED_MSG_LEN]

        time_str = ldt.strftime("%H:%M")
        block = f"--- EVENT ---\nTIME: {time_str}\nROLE: {role}\nPROJECT: {project}\nTEXT: {text}\n"
        total_size += len(block)

        if total_size > MAX_OUTPUT_BYTES and not truncate_aggressively:
            truncate_aggressively = True
            text = text[:TRUNCATED_MSG_LEN]
            block = f"--- EVENT ---\nTIME: {time_str}\nROLE: {role}\nPROJECT: {project}\nTEXT: {text}\n"

        lines.append(block)

    return "\n".join(lines)


def main():
    date_arg = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else ""

    try:
        target_date = parse_date(date_arg)
    except ValueError:
        print(f"ERROR: Invalid date format '{date_arg}'. Use YYYY-MM-DD, 'today', or 'yesterday'.", file=sys.stderr)
        sys.exit(1)

    sessions = discover_sessions(target_date)
    disk_sessions = discover_sessions_on_disk(target_date, set(sessions.keys()))

    all_events = []
    contributing = set()
    for sid, project in sessions.items():
        file_path = session_file_path(project, sid)
        events = read_session(file_path, project, target_date)
        if events:
            contributing.add(sid)
        all_events.extend(events)
        subagent_dir = file_path.parent / sid / "subagents"
        if subagent_dir.exists():
            for agent_file in sorted(subagent_dir.glob("agent-*.jsonl")):
                sub_events = read_session(agent_file, project, target_date)
                if sub_events:
                    contributing.add(sid)
                all_events.extend(sub_events)

    for sid, (file_path, project) in disk_sessions.items():
        events = read_session(file_path, project, target_date)
        if events:
            contributing.add(sid)
        all_events.extend(events)
        subagent_dir = file_path.parent / sid / "subagents"
        if subagent_dir.exists():
            for agent_file in sorted(subagent_dir.glob("agent-*.jsonl")):
                sub_events = read_session(agent_file, project, target_date)
                if sub_events:
                    contributing.add(sid)
                all_events.extend(sub_events)

    parts = []
    if HISTORY_PATH.exists():
        parts.append(f"history-index {len(sessions)}")
    else:
        parts.append(f"history-index unavailable ({HISTORY_PATH})")
    parts.append(f"on-disk scan {len(disk_sessions)}")
    output = format_output(target_date, len(contributing), all_events, " + ".join(parts))
    print(output)


if __name__ == "__main__":
    main()
