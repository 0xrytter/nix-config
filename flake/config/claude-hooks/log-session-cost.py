#!/usr/bin/env python3
import json
import sys
from datetime import datetime
from pathlib import Path

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# Try both flat and nested field names
cost = (
    data.get("cost_usd")
    or data.get("cost", {}).get("total_cost_usd")
    or 0
)
input_tokens = (
    data.get("total_input_tokens")
    or data.get("context_window", {}).get("total_input_tokens")
    or 0
)
output_tokens = (
    data.get("total_output_tokens")
    or data.get("context_window", {}).get("total_output_tokens")
    or 0
)

if not cost:
    sys.exit(0)

log = Path.home() / ".claude" / "session-costs.log"
timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

with log.open("a") as f:
    f.write(f"{timestamp}\t${cost:.4f}\t{input_tokens}in\t{output_tokens}out\n")
