#!/usr/bin/env bash
cmd=$1
pid=$2
case $cmd in
  claude)
    cat /tmp/tmux-ai-claude 2>/dev/null
    ;;
  pi)
    pi_pid=$(pgrep -P "$pid" -x pi 2>/dev/null | head -1)
    [ -n "$pi_pid" ] && cat "/tmp/tmux-ai-pi-$pi_pid" 2>/dev/null
    ;;
esac
