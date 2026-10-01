sha=$(git rev-parse --verify "${1:-HEAD}^{commit}")
shift || true
summary="$*"
if [ -z "$summary" ]; then
  git log -1 --format='%h %s' "$sha"
  printf 'What does it do? (or "skip"): '
  read -r summary
fi
if [ -z "$summary" ]; then
  echo "git stamp: empty summary, not stamped" >&2
  exit 1
fi
git notes --ref=reviewed add -f -m "$summary" "$sha"
