#!/usr/bin/env python3
import json
import sys
import hashlib
import os
from datetime import datetime, date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from cost_calc import calc_cost, calc_cost_by_date

SESSIONS = Path.home() / ".claude" / "sessions"
SESSIONS.mkdir(exist_ok=True)

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

path       = data.get("transcript_path") or ""
session_id = data.get("session_id") or ""
last_msg   = data.get("last_assistant_message", "").strip()[:200]
if not path:
    sys.exit(0)


def extract_model(p: str) -> str:
    try:
        for line in Path(p).read_text().splitlines():
            obj = json.loads(line)
            if obj.get("type") == "assistant":
                model = obj.get("message", {}).get("model", "")
                if model:
                    return model
    except Exception:
        pass
    return "unknown"


def count_messages(p: str) -> int:
    try:
        return sum(
            1 for line in Path(p).read_text().splitlines()
            if json.loads(line).get("type") == "user"
        )
    except Exception:
        return 0


def find_sessions_dir() -> Path | None:
    cache = Path("/tmp/.llmthing_sessions")
    if cache.exists():
        cached = cache.read_text().strip()
        if cached and (Path(cached) / ".llmthing-sessions").exists():
            return Path(cached)
    matches = list(Path.home().glob("**/.llmthing-sessions"))
    if matches:
        d = matches[0].parent
        cache.write_text(str(d))
        return d
    return None


def extract_new_messages(p: str, from_line: int) -> tuple[list[str], int]:
    turns = []
    try:
        lines = Path(p).read_text().splitlines()
        for line in lines[from_line:]:
            obj = json.loads(line)
            role = obj.get("type")
            if role not in ("user", "assistant"):
                continue
            content = obj.get("message", {}).get("content", "")
            text = ""
            if isinstance(content, str):
                text = content.strip()
            elif isinstance(content, list):
                parts = [b["text"].strip() for b in content
                         if b.get("type") == "text" and b.get("text", "").strip()]
                text = "\n".join(parts)
            if text:
                turns.append(("U" if role == "user" else "A", text))
        return turns, len(lines)
    except Exception:
        return [], from_line


# ── Update ~/.claude/sessions/ JSON ──────────────────────────────────────────
model = extract_model(path)
cost  = calc_cost(path, model) or 0
now   = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

session_file = SESSIONS / (hashlib.md5(path.encode()).hexdigest()[:16] + ".json")
started_at   = now
if session_file.exists():
    try:
        started_at = json.loads(session_file.read_text()).get("started_at", now)
    except Exception:
        pass

costs_by_date = calc_cost_by_date(path, model)
session_file.write_text(json.dumps({
    "transcript_path": path,
    "model": model,
    "started_at": started_at,
    "updated_at": now,
    "cost_usd": cost,
    "costs_by_date": costs_by_date,
    "message_count": count_messages(path),
    "is_final": True,
}))

# ── Write joi session log (append-only, cursor-tracked) ───────────────────────
sessions_dir = find_sessions_dir()
if not sessions_dir:
    sys.exit(0)

cursor_file = Path(f"/tmp/session-cursor-{session_id}.json")
cursor_data = {}
if cursor_file.exists():
    try:
        cursor_data = json.loads(cursor_file.read_text())
    except Exception:
        pass
# migrate old plain-int cursor file
old_cursor_file = Path(f"/tmp/session-cursor-{session_id}.txt")
if not cursor_data and old_cursor_file.exists():
    try:
        cursor_data = {"cursor": int(old_cursor_file.read_text())}
        old_cursor_file.unlink()
    except Exception:
        pass

cursor = cursor_data.get("cursor", 0)

new_turns, new_cursor = extract_new_messages(path, cursor)
if not new_turns and cursor > 0:
    sys.exit(0)

# find or create the session log file
log_path_str = cursor_data.get("log_path", "")
log_path     = Path(log_path_str) if log_path_str and Path(log_path_str).exists() else None

if log_path is None:
    # migrate old naming: session-{id[:8]}-{ts}.md → session-{ts}.md
    old = list(sessions_dir.glob(f"session-{session_id[:8]}-*.md"))
    if old:
        old_path = old[0]
        # extract the timestamp portion and rename
        stem     = old_path.stem  # session-{id[:8]}-{ts}
        ts_part  = stem[len(f"session-{session_id[:8]}-"):]
        new_name = sessions_dir / f"session-{ts_part}.md"
        old_path.rename(new_name)
        log_path = new_name

if log_path and log_path.exists():
    content = log_path.read_text()
    content = "\n".join(
        f"cost: ${cost:.2f}" if line.startswith("cost:") else line
        for line in content.split("\n")
    )
    if new_turns:
        new_text = "\n\n".join(f"{r}: {t}" for r, t in new_turns)
        content  = content.rstrip("\n") + f"\n\n{new_text}\n"
    log_path.write_text(content)
else:
    ts          = datetime.now().strftime("%Y-%m-%d-%H%M")
    model_short = model.replace("claude-", "").replace("-latest", "")
    relaunch    = f"claude --resume {session_id}" if session_id else path
    summary     = last_msg or f"session {ts}"
    body        = "\n\n".join(f"{r}: {t}" for r, t in new_turns)
    log_path    = sessions_dir / f"session-{ts}.md"
    log_path.write_text(
        f"---\n"
        f"summary: {summary}\n"
        f"date: {date.today().isoformat()}\n"
        f"relaunch: {relaunch}\n"
        f"model: {model_short}\n"
        f"cost: ${cost:.2f}\n"
        f"---\n\n"
        f"{body}\n"
    )

cursor_file.write_text(json.dumps({"cursor": new_cursor, "log_path": str(log_path)}))
