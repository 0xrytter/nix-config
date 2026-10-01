# git stamp [<commit> | <range>] [summary...]
#
# With no argument, stamps every commit not yet on any remote with one summary:
# review the push as a whole, not commit by commit. A commit or an a..b range
# narrows it. Prompts for the summary when none is given.
target="${1:-}"
if [ $# -gt 0 ]; then shift; fi
summary="$*"

if [ -z "$target" ]; then
  list=$(git rev-list --reverse HEAD --not --remotes)
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
