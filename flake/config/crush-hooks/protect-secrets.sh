#!/usr/bin/env sh
# Crush PreToolUse hook: keep secrets out of the session. Generic deny list —
# nothing project-specific: no sops commands, no age/ssh private keys, no .env
# files, nothing under a secrets/ directory. Exit 2 = tool blocked.
case "$CRUSH_TOOL_INPUT_COMMAND $CRUSH_TOOL_INPUT_FILE_PATH" in
  *sops*|*age/keys.txt*|*age-key*|*ssh/id_*|*id_rsa*|*id_ed25519*|*.env|*.env[.\ ]*|*secrets/*)
    echo "blocked: this would expose secrets (.env, age/ssh keys, sops) — see agent-rules.md" >&2
    exit 2
    ;;
esac
exit 0
