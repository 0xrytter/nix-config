# git stamp [<commit> | <range>] [summary...]
#
# With no argument, stamps every commit not yet on any remote that has no stamp
# yet, with one summary: review the push as a whole, and keep any per-commit
# stamps already written. A commit or an a..b range (re)stamps exactly those.
# Prompts for the summary when none is given.
target="${1:-}"
if [ $# -gt 0 ]; then shift; fi
summary="$*"

if [ -z "$target" ]; then
  unpushed=$(git rev-list --reverse HEAD --not --remotes)
  list=""
  for sha in $unpushed; do
    git notes --ref=reviewed show "$sha" >/dev/null 2>&1 || list="$list$sha"$'\n'
  done
  list=${list%$'\n'}
elif [[ $target == *..* ]]; then
  list=$(git rev-list --reverse "$target")
else
  list=$(git rev-parse --verify "$target^{commit}")
fi
if [ -z "$list" ]; then
  echo "git stamp: nothing to stamp" >&2
  exit 1
fi
mapfile -t shas <<<"$list"

if [ -z "$summary" ]; then
  for sha in "${shas[@]}"; do
    git log -1 --format='%h %s' "$sha"
  done
  printf 'What does this do? (or "skip"): '
  read -r summary
fi
if [ -z "$summary" ]; then
  echo "git stamp: empty summary, not stamped" >&2
  exit 1
fi

for sha in "${shas[@]}"; do
  git notes --ref=reviewed add -f -m "$summary" "$sha"
done
echo "stamped ${#shas[@]} commit(s)"
