#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

deny_file="tools/leak_deny.txt"
allow_file="tools/leak_allow.txt"
status=0

if [ ! -f "$deny_file" ]; then
  echo "missing $deny_file" >&2
  exit 2
fi

patterns=()
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  patterns+=("$line")
done < "$deny_file"

allow_pattern='^$'
if [ -f "$allow_file" ]; then
  allow_pattern="$(grep -v '^#' "$allow_file" | grep -v '^$' | paste -sd'|' - || true)"
  [ -z "$allow_pattern" ] && allow_pattern='^$'
fi

files="$(git ls-files --cached --others --exclude-standard | grep -vE '^(tools/leak_deny.txt|tools/leak_allow.txt|tools/leak_scan.sh)$' || true)"

for pattern in "${patterns[@]}"; do
  hits="$(printf '%s\n' "$files" | xargs grep -nIiE -- "$pattern" 2>/dev/null | grep -vE -- "$allow_pattern" || true)"
  if [ -n "$hits" ]; then
    echo "LEAK: pattern '$pattern'"
    printf '%s\n' "$hits" | head -20
    status=1
  fi
done

names="$(printf '%s\n' "$files" | grep -iE '(^|/)(\.claude|claude\.md)(/|$)|\.p8$|\.pem$|service-?account' || true)"
if [ -n "$names" ]; then
  echo "LEAK: forbidden file names"
  printf '%s\n' "$names"
  status=1
fi

if git rev-parse --git-dir >/dev/null 2>&1 && git rev-parse HEAD >/dev/null 2>&1; then
  for pattern in "${patterns[@]}"; do
    history="$(git log --all -i -E --grep="$pattern" --format='%h %an %s' | head -5 || true)"
    if [ -n "$history" ]; then
      echo "LEAK in commit messages: pattern '$pattern'"
      printf '%s\n' "$history"
      status=1
    fi
  done
  trailers="$(git log --all --format='%an <%ae>%n%b' | grep -iE 'co-authored-by|generated with' || true)"
  if [ -n "$trailers" ]; then
    echo "LEAK: commit trailers"
    printf '%s\n' "$trailers" | head -5
    status=1
  fi
fi

if [ "$status" -eq 0 ]; then
  echo "leak scan: clean"
fi
exit "$status"
