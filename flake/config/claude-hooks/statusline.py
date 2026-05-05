#!/usr/bin/env python3
import json
import sys
import hashlib
import time
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from cost_calc import calc_cost, calc_cost_by_date

SESSIONS = Path.home() / ".claude" / "sessions"
SESSIONS.mkdir(exist_ok=True)

_TIER_MULTIPLIERS = {
    "default_claude_ai": 1,
    "max_claude_ai":     5,
    "max_5x":            5,
    "max_20x":          20,
}

def _plan_multiplier():
    import re
    try:
        creds = json.loads((Path.home() / ".claude" / ".credentials.json").read_text())
        tier  = creds.get("claudeAiOauth", {}).get("rateLimitTier", "")
        if tier in _TIER_MULTIPLIERS:
            return _TIER_MULTIPLIERS[tier]
        m = re.search(r"(\d+)x", tier)
        if m:
            return int(m.group(1))
    except Exception:
        pass
    return 1

PLAN_MULTIPLIER = _plan_multiplier()

CTX_AMBER = 50
CTX_RED   = 80

# Catppuccin Mocha
_RST       = "\033[0m"
_SEP       = "#6E6C7E"  # overlay — pipes and dots
_DIM       = "#988BA2"  # subtext — labels and nav
_HIGHLIGHT = "#89b4fa"  # blue — highlighted values
_GREEN     = "#a6e3a1"  # green — ok/low
_YELLOW    = "#f9e2af"  # yellow — warning
_RED       = "#f38ba8"  # red — critical

def col(hex_color, text):
    r, g, b = int(hex_color[1:3], 16), int(hex_color[3:5], 16), int(hex_color[5:7], 16)
    return f"\033[38;2;{r};{g};{b}m{text}{_RST}"


try:
    data = json.load(sys.stdin)
except Exception:
    print("claude")
    sys.exit(0)

model       = data.get("model", {}).get("id", "unknown")
path        = data.get("transcript_path") or ""
effort      = data.get("effort", {}).get("level", "")
ctx_window  = data.get("context_window", {})
ctx_pct     = ctx_window.get("used_percentage") or 0
rate_limits = data.get("rate_limits", {})

cost = calc_cost(path, model) or (data.get("cost") or {}).get("total_cost_usd") or 0


def session_activity(p):
    human = tools = 0
    try:
        for line in Path(p).read_text().splitlines():
            try:
                obj = json.loads(line)
                t = obj.get("type", "")
                content = obj.get("message", {}).get("content", "")
                if t == "user":
                    if isinstance(content, str) and content.strip():
                        human += 1
                    elif isinstance(content, list):
                        if not any(x.get("type") == "tool_result" for x in content):
                            if any(x.get("type") == "text" for x in content):
                                human += 1
                elif t == "assistant" and isinstance(content, list):
                    if any(x.get("type") == "tool_use" for x in content):
                        tools += 1
            except Exception:
                continue
    except Exception:
        pass
    return human, tools


def time_until(ts):
    delta = int(ts - time.time())
    if delta <= 0:
        return "now"
    d, h, m = delta // 86400, (delta % 86400) // 3600, (delta % 3600) // 60
    if d:  return f"{d}d{h}h"
    if h:  return f"{h}h{m:02d}m"
    return f"{m}m"


human, tools = session_activity(path) if path else (0, 0)
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

if path and cost > 0:
    session_file = SESSIONS / (hashlib.md5(path.encode()).hexdigest()[:16] + ".json")
    started_at = now
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
        "human_turns": human,
        "tool_ops": tools,
        "is_final": False,
    }))

today          = date.today()
month_start    = today.replace(day=1)
trailing_start = today - timedelta(days=30)
today_cost = month_cost = trailing_cost = 0.0

for f in SESSIONS.glob("*.json"):
    try:
        s = json.loads(f.read_text())
        costs_by_date = s.get("costs_by_date")
        if costs_by_date:
            for date_str, v in costs_by_date.items():
                try:
                    d = datetime.strptime(date_str, "%Y-%m-%d").date()
                    if d == today:          today_cost    += v
                    if d >= month_start:    month_cost    += v
                    if d >= trailing_start: trailing_cost += v
                except Exception:
                    pass
        else:
            # fallback for old session files without costs_by_date
            d = datetime.strptime(s.get("updated_at", s["started_at"]), "%Y-%m-%d %H:%M:%S").date()
            v = float(s.get("cost_usd", 0))
            if d == today:          today_cost    += v
            if d >= month_start:    month_cost    += v
            if d >= trailing_start: trailing_cost += v
    except Exception:
        pass

# ── Line 1 ────────────────────────────────────────────────────────────────────
ctx_pct_i = int(ctx_pct)
ctx_color = _RED if ctx_pct_i >= CTX_RED else (_YELLOW if ctx_pct_i >= CTX_AMBER else _GREEN)

def hi(text):
    return col(_HIGHLIGHT, str(text))

model_short = model.replace("claude-", "").replace("-latest", "")
effort_str  = f" {col(_DIM, 'effort:')} {hi(effort)}" if effort else ""
month_label = today.strftime('%b').lower()

sep = col(_SEP, " | ")

line1 = (
    f"{hi(model_short)}{effort_str}"
    f"{sep}{col(_DIM, 'ctx')} {col(ctx_color, f'{ctx_pct_i}%')}"
    f"{sep}{hi(f'${cost:.2f}')}"
    f"{sep}{hi(human)} {col(_DIM, 'msg')} {hi(tools)} {col(_DIM, 'ops')}"
    f"{sep}{col(_DIM, 'today')} {hi(f'${today_cost:.2f}')}"
    f"{sep}{col(_DIM, month_label)} {hi(f'${month_cost:.2f}')}"
    f"{sep}{col(_DIM, '30d')} {hi(f'${trailing_cost:.2f}')}"
)

# ── Line 2 ────────────────────────────────────────────────────────────────────
fh = rate_limits.get("five_hour", {})
sd = rate_limits.get("seven_day", {})

def rate_col(pct):
    return _RED if pct >= 80 else (_YELLOW if pct >= 50 else _GREEN)

rate_parts = []
PRO_REF_MULTIPLIER = 5  # reference Max tier used when comparing from Pro

def other_plan_pct(p):
    """Convert p% on current plan to equivalent % on the other plan."""
    if PLAN_MULTIPLIER == 1:
        return round(p / PRO_REF_MULTIPLIER, 1)   # Pro → Max 5x: smaller number
    else:
        return round(p * PLAN_MULTIPLIER, 1)        # Max → Pro: bigger number

if fh:
    p5, r5 = fh.get("used_percentage", 0), fh.get("resets_at")
    t5 = time_until(r5) if r5 else None
    other5 = other_plan_pct(p5)
    rate_parts.append(
        f"{col(_DIM, '5h')} {col(rate_col(p5), f'{p5:.0f}%')}{col(_SEP, '/')}{col(rate_col(other5), f'{other5:.1f}%')}"
        + (f" {col(_DIM, 'in')} {hi(t5)}" if t5 and t5 != "now" else "")
    )
if sd:
    p7, r7 = sd.get("used_percentage", 0), sd.get("resets_at")
    t7 = time_until(r7) if r7 else None
    other7 = other_plan_pct(p7)
    rate_parts.append(
        f"{col(_DIM, '7d')} {col(rate_col(p7), f'{p7:.0f}%')}{col(_SEP, '/')}{col(rate_col(other7), f'{other7:.1f}%')}"
        + (f" {col(_DIM, 'in')} {hi(t7)}" if t7 and t7 != "now" else "")
    )

nav      = col(_DIM, "compact | clear | rewind | effort | model opusplan")
rate_str = col(_SEP, " | ").join(rate_parts)
line2    = "  " + (col(_SEP, " | ").join(filter(None, [rate_str, nav])))

print(f"{line1}\n{line2}")
