#!/usr/bin/env python3
"""Write the most recent pi session to the llmthing sessions directory."""

import json
import sys
from datetime import date, datetime, timezone
from pathlib import Path

PI_SESSIONS = Path.home() / ".pi" / "agent" / "sessions" / "--work--"


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


def extract_messages(path: Path) -> list[tuple[str, str]]:
    turns = []
    try:
        for line in path.read_text().splitlines():
            obj = json.loads(line)
            if obj.get("type") != "message":
                continue
            role = obj["message"].get("role")
            if role not in ("user", "assistant"):
                continue
            content = obj["message"].get("content", "")
            text = ""
            if isinstance(content, str):
                text = content.strip()
            elif isinstance(content, list):
                parts = [
                    b["text"].strip()
                    for b in content
                    if b.get("type") == "text" and b.get("text", "").strip()
                ]
                text = "\n".join(parts)
            if text:
                turns.append(("U" if role == "user" else "A", text))
    except Exception:
        pass
    return turns


def main() -> None:
    host_cwd = sys.argv[1] if len(sys.argv) > 1 else ""
    since_ts = int(sys.argv[2]) if len(sys.argv) > 2 else 0

    if not PI_SESSIONS.exists():
        return

    candidates = sorted(PI_SESSIONS.glob("*.jsonl"), key=lambda p: p.stat().st_mtime)
    if not candidates:
        return

    # find session created during this run
    session_file = None
    for p in reversed(candidates):
        if p.stat().st_mtime >= since_ts:
            session_file = p
            break

    if not session_file:
        return

    sessions_dir = find_sessions_dir()
    if not sessions_dir:
        return

    turns = extract_messages(session_file)
    if not turns:
        return

    # extract session id and timestamp from filename
    stem = session_file.stem  # 2026-05-11T00-15-03-884Z_019e...
    ts_part = stem.split("_")[0].replace("T", " ").replace("-", ":", 2)[:16]
    session_id = stem.split("_")[1] if "_" in stem else stem

    model = "kimi"
    try:
        for line in session_file.read_text().splitlines():
            obj = json.loads(line)
            if obj.get("type") == "model_change":
                model = obj.get("modelId", "kimi").split("-")[0]
                break
    except Exception:
        pass

    ts = datetime.now().strftime("%Y-%m-%d-%H%M")
    project = host_cwd.strip("/").replace("/", "-") if host_cwd else "unknown"
    summary = turns[0][1][:120] if turns else f"pi session {ts}"
    body = "\n\n".join(f"{r}: {t}" for r, t in turns)

    log_path = sessions_dir / f"pi-{ts}.md"
    log_path.write_text(
        f"---\n"
        f"summary: {summary}\n"
        f"date: {date.today().isoformat()}\n"
        f"agent: pi\n"
        f"model: {model}\n"
        f"project: {project}\n"
        f"session_id: {session_id}\n"
        f"---\n\n"
        f"{body}\n"
    )


if __name__ == "__main__":
    main()
