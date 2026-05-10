#!/usr/bin/env python3
"""
Unified AI statusline for tmux status-format[1].
Called as: ai-status.py <pane_current_command> <pane_pid>
"""

import json
import subprocess
import sys
import time
from datetime import date, datetime, timedelta
from pathlib import Path

SESSIONS_DIR = Path.home() / ".claude" / "sessions"
LIVE_STATE   = SESSIONS_DIR / "live.json"
CAPS_FILE    = Path.home() / ".claude" / "caps.json"

# Gruvbox Dark
_SEP = "#665c54"
_DIM = "#a89984"
_HI  = "#ebdbb2"
_GRN = "#b8bb26"
_YLW = "#fabd2f"
_RED = "#fb4934"


def col(hex_color: str, text: str) -> str:
    return f"#[fg={hex_color}]{text}#[fg=default]"


def hi(text)  -> str: return col(_HI,  str(text))
def dim(text) -> str: return col(_DIM, str(text))

sep = col(_SEP, " | ")


def rate_col(pct: float) -> str:
    return _RED if pct >= 80 else (_YLW if pct >= 50 else _GRN)


def ctx_col(pct: float) -> str:
    return _RED if pct >= 80 else (_YLW if pct >= 50 else _GRN)


def time_until(ts) -> str | None:
    try:
        ts = float(ts)
        if ts > time.time() * 100:
            ts /= 1000
        delta = int(ts - time.time())
        if delta <= 0:
            return None
        d = delta // 86400
        h = (delta % 86400) // 3600
        m = (delta % 3600) // 60
        if d:   return f"{d}d{h}h"
        if h:   return f"{h}h{m:02d}m"
        return f"{m}m"
    except Exception:
        return None


def find_child_pid(shell_pid: int, name: str) -> int | None:
    try:
        r = subprocess.run(
            ["pgrep", "-P", str(shell_pid), "-x", name],
            capture_output=True, text=True,
        )
        if r.returncode == 0:
            return int(r.stdout.strip().splitlines()[0])
    except Exception:
        pass
    return None


def load_caps() -> dict:
    try:
        return json.loads(CAPS_FILE.read_text())
    except Exception:
        return {}


def get_cap(model: str, caps: dict) -> dict | None:
    for prefix, cap in caps.items():
        if prefix.startswith("_"):
            continue
        if model.lower().startswith(prefix.lower()):
            return cap
    return None


def load_live_state() -> dict:
    try:
        return json.loads(LIVE_STATE.read_text())
    except Exception:
        return {}


# ── Claude ────────────────────────────────────────────────────────────────────

def claude_status() -> str | None:
    if not SESSIONS_DIR.exists():
        return None

    today       = date.today()
    month_start = today.replace(day=1)
    trailing_30 = today - timedelta(days=30)
    month_label = today.strftime("%b").lower()

    today_cost = month_cost = trailing_cost = 0.0
    current: dict | None = None
    current_mtime = 0.0

    for f in SESSIONS_DIR.glob("*.json"):
        try:
            s = json.loads(f.read_text())
        except Exception:
            continue

        if "cost_usd" not in s:  # skip pid files (they have no cost_usd)
            continue

        mtime = f.stat().st_mtime
        if mtime > current_mtime:
            current_mtime = mtime
            current = s

        for date_str, v in (s.get("costs_by_date") or {}).items():
            try:
                d = datetime.strptime(date_str, "%Y-%m-%d").date()
                if d == today:       today_cost    += v
                if d >= month_start: month_cost    += v
                if d >= trailing_30: trailing_cost += v
            except Exception:
                pass

    if not current:
        return None

    live      = load_live_state()
    sess_cost = float(current.get("cost_usd", 0))
    model     = live.get("model") or current.get("model", "")
    model_s   = model.replace("claude-", "").replace("-latest", "")
    effort    = live.get("effort", "")
    human     = current.get("human_turns", 0)
    tools     = current.get("tool_ops", 0)
    ctx_pct   = live.get("ctx_pct", 0)
    rl        = live.get("rate_limits", {})

    effort_s = f" {dim('~')}{hi(effort)}" if effort and effort != "medium" else ""
    ctx_s    = (f"{dim('ctx')} {col(ctx_col(ctx_pct), f'{ctx_pct:.1f}%')}" if ctx_pct >= 0.1
                else f"{dim('ctx')} {col(_DIM, '--')}")

    parts = [f"{hi(model_s)}{effort_s}"]
    if ctx_s:
        parts.append(ctx_s)
    parts += [
        hi(f'${sess_cost:.2f}'),
        f"{hi(human)} {dim('m')} {hi(tools)} {dim('op')}",
        f"{dim('td')} {hi(f'${today_cost:.2f}')}",
        f"{dim(month_label)} {hi(f'${month_cost:.2f}')}",
    ]

    fh = rl.get("five_hour", {})
    sd = rl.get("seven_day", {})
    rate_parts = []
    if fh:
        p5 = fh.get("used_percentage", 0)
        t5 = time_until(fh.get("resets_at"))
        rate_parts.append(
            f"{dim('5h')} {col(rate_col(p5), f'{p5:.0f}%')}"
            + (f" {hi(t5)}" if t5 else "")
        )
    if sd:
        p7 = sd.get("used_percentage", 0)
        t7 = time_until(sd.get("resets_at"))
        rate_parts.append(
            f"{dim('7d')} {col(rate_col(p7), f'{p7:.0f}%')}"
            + (f" {hi(t7)}" if t7 else "")
        )
    if rate_parts:
        parts.append(sep.join(rate_parts))

    return sep.join(parts)


# ── Pi ────────────────────────────────────────────────────────────────────────

PI_SESSIONS = Path.home() / ".pi" / "sessions"


def pi_status(pane_pid: int) -> str | None:
    pi_pid = find_child_pid(pane_pid, "pi")
    if pi_pid is None:
        return None
    return pi_format(pi_pid)


# ── Headset ───────────────────────────────────────────────────────────────────

_HEADSET_CACHE = Path("/tmp/tmux-ai-headset")

def headset_status() -> str | None:
    try:
        if _HEADSET_CACHE.exists() and time.time() - _HEADSET_CACHE.stat().st_mtime < 30:
            return _HEADSET_CACHE.read_text() or None
    except Exception:
        pass
    try:
        r = subprocess.run(["upower", "-e"], capture_output=True, text=True)
        devices = [d for d in r.stdout.splitlines() if "headset" in d.lower()]
        if not devices:
            return None
        r2 = subprocess.run(["upower", "-i", devices[0]], capture_output=True, text=True)
        for line in r2.stdout.splitlines():
            if "percentage" in line:
                pct = int(line.split()[-1].rstrip('%'))
                color = _RED if pct <= 25 else (_YLW if pct <= 50 else _GRN)
                result = f"{dim('🎧')} {col(color, f'{pct}%')}"
                _HEADSET_CACHE.write_text(result)
                return result
    except Exception:
        pass
    return f"{dim('🎧')} {col(_DIM, '--')}"


def pi_format(pi_pid: int) -> str | None:
    state_file = Path(f"/tmp/pi-status-{pi_pid}.json")
    if not state_file.exists():
        return None
    try:
        s = json.loads(state_file.read_text())
    except Exception:
        return None

    model    = s.get("model", "unknown")
    thinking = s.get("thinking", "")
    ctx_pct  = float(s.get("ctx_pct", 0))
    cost     = float(s.get("sess_cost", 0))
    human    = int(s.get("human_messages", 0))
    tool_ops = int(s.get("tool_ops", 0))
    rate     = s.get("rate")
    if rate is None:
        cap = get_cap(model, load_caps())
        if cap:
            rate = {"used": 0, "limit": cap["messages"], "window_hours": cap["window_hours"], "resets_at": None}

    today       = date.today()
    month_start = today.replace(day=1)
    month_label = today.strftime("%b").lower()
    today_cost = month_cost = 0.0

    if PI_SESSIONS.exists():
        for f in PI_SESSIONS.glob("*.json"):
            try:
                ps = json.loads(f.read_text())
                d = datetime.strptime(ps.get("started_date", ""), "%Y-%m-%d").date()
                v = float(ps.get("sess_cost", 0))
                if d == today:       today_cost += v
                if d >= month_start: month_cost += v
            except Exception:
                pass

    thinking_s = f" {dim('~think')}" if thinking else ""
    ctx_s      = (f"{dim('ctx')} {col(ctx_col(ctx_pct), f'{ctx_pct:.1f}%')}" if ctx_pct >= 0.1
                  else f"{dim('ctx')} {col(_DIM, '--')}")

    parts = [f"{hi(model)}{thinking_s}"]
    if ctx_s:
        parts.append(ctx_s)
    parts += [
        hi(f'${cost:.2f}'),
        f"{hi(human)} {dim('m')} {hi(tool_ops)} {dim('op')}",
        f"{dim('td')} {hi(f'${today_cost:.2f}')}",
        f"{dim(month_label)} {hi(f'${month_cost:.2f}')}",
    ]

    if rate:
        used   = int(rate.get("used", 0))
        limit  = int(rate.get("limit", 160))
        window = int(rate.get("window_hours", 3))
        pct    = used / limit * 100 if limit else 0
        t      = time_until(rate.get("resets_at", 0))
        parts.append(
            f"{dim(f'{window}h')} {col(rate_col(pct), f'{used}/{limit}')}"
            + (f" {hi(t)}" if t else "")
        )

    return sep.join(parts)


# ── Main ──────────────────────────────────────────────────────────────────────

_CACHE_DIR = Path("/tmp")

def main() -> None:
    if len(sys.argv) < 3:
        return

    command  = sys.argv[1]
    pane_pid = int(sys.argv[2])

    # write-cache modes: called from hooks to pre-render status to file
    if command == "write-claude":
        result = claude_status()
        (_CACHE_DIR / "tmux-ai-claude").write_text(result or "")
        return
    if command == "write-pi":
        result = pi_format(pane_pid)  # pane_pid is the pi pid here
        (_CACHE_DIR / f"tmux-ai-pi-{pane_pid}").write_text(result or "")
        return

    if command == "headset":
        result = headset_status()
    elif command == "pi":
        result = pi_status(pane_pid)
    elif command == "claude":
        result = claude_status()
    else:
        result = None

    print(result or "", end="")


if __name__ == "__main__":
    main()
