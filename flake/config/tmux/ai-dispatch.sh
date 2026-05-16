#!/usr/bin/env bash
cmd=$1
pid=$2
pane=${3#%}
status_dir=${TMUX_AI_STATUS_DIR:-/tmp/tmux-ai}

pane_status() {
  [ -n "$pane" ] && cat "$status_dir/pane-$pane.status" 2>/dev/null
}

render_pane_status() {
  [ -z "$pane" ] && return 1
  case ${1:-} in
    claude)
      TMUX_AI_PANE="$pane" TMUX_AI_STATUS_DIR="$status_dir" \
        python3 ~/.config/tmux/ai-status.py write-claude "$pane" >/dev/null 2>&1
      ;;
    pi)
      [ -f "$status_dir/pi-status-$pane.json" ] || return 1
      TMUX_AI_PANE="$pane" TMUX_AI_STATUS_DIR="$status_dir" \
        python3 ~/.config/tmux/ai-status.py write-pi "$pane" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

pane_status_or_render() {
  local kind=$1
  pane_status || { render_pane_status "$kind" && pane_status; }
}

# Containerized agents are keyed by tmux pane id, not process id.  tmux sees the
# foreground process as docker, while the actual AI process lives in the
# container with a different PID namespace.
if [ -n "$pane" ] && [ -f "$status_dir/pane-$pane.kind" ]; then
  kind=$(cat "$status_dir/pane-$pane.kind" 2>/dev/null)
  pane_status_or_render "$kind"
  exit 0
fi

case $cmd in
  claude)
    pane_status_or_render claude || cat /tmp/tmux-ai-claude 2>/dev/null
    ;;
  pi)
    if ! pane_status_or_render pi; then
      pi_pid=$(pgrep -P "$pid" -x pi 2>/dev/null | head -1)
      [ -n "$pi_pid" ] && cat "/tmp/tmux-ai-pi-$pi_pid" 2>/dev/null
    fi
    ;;
  docker)
    pane_status
    ;;
esac
