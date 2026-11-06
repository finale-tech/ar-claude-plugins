#!/usr/bin/env bash
# review-pr deterministic pre-scan (Step 7b).
#
# Usage: prescan.sh <WORKTREE> <BASE_REF>
#
# Scans every source file the PR changes (merge-base of BASE_REF..HEAD) with
# prescan.awk and prints each hit as a numbered obligation:
#
#   PRESCAN base=<ref> merge_base=<sha> head=<sha> files_scanned=<n> files_skipped=<n>
#   [1] R2 src/main/java/Foo.java:42 — catch does not rethrow e | } catch (IOException e) {
#   ...
#   PRESCAN_DONE hits=<n> R1=<n> R2=<n> R3=<n> R4=<n>
#
# Exit 0 even with hits. Non-zero = real failure (bad worktree, unresolvable
# base), reason on stderr.
#
# Env: REVIEW_PR_REMOTE (default origin); PRESCAN_INCLUDE_TESTS=1 to also
# scan test files (skipped by default).

set -u

fail() { echo "prescan: $*" >&2; exit 1; }

[ $# -eq 2 ] || fail "usage: prescan.sh <WORKTREE> <BASE_REF>"
WT="$1"
BASE="$2"
REMOTE="${REVIEW_PR_REMOTE:-origin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWK_PROG="$SCRIPT_DIR/prescan.awk"

[ -f "$AWK_PROG" ] || fail "missing $AWK_PROG"
[ -d "$WT" ] || fail "worktree does not exist: $WT"
WT="$(git -C "$WT" rev-parse --show-toplevel 2>/dev/null)" || fail "not a git worktree: $1"

# Refresh the base branch; fall back to local refs if offline.
if ! git -C "$WT" fetch --quiet --no-tags "$REMOTE" "$BASE" >/dev/null 2>&1; then
  echo "prescan: warning: could not fetch '$BASE' from '$REMOTE'; using local refs." >&2
fi

BASE_SHA=""
BASE_LABEL=""
for ref in "refs/remotes/$REMOTE/$BASE" "$BASE"; do
  sha="$(git -C "$WT" rev-parse --verify --quiet "$ref^{commit}" 2>/dev/null)" || continue
  BASE_SHA="$sha"
  BASE_LABEL="${ref#refs/remotes/}"
  break
done
[ -n "$BASE_SHA" ] || fail "cannot resolve base '$BASE' (tried $REMOTE/$BASE and $BASE)."

MB="$(git -C "$WT" merge-base "$BASE_SHA" HEAD 2>/dev/null)" || fail "no merge base between $BASE_LABEL and HEAD."
HEAD_SHA="$(git -C "$WT" rev-parse HEAD)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/prescan.XXXXXX")" || fail "mktemp failed."
trap 'rm -rf "$TMP"' EXIT

git -C "$WT" -c core.quotePath=false diff -U0 --no-color --no-ext-diff -M "$MB" "$HEAD_SHA" > "$TMP/diff" \
  || fail "git diff $MB..HEAD failed."

# Per file: "<path>\t<added new-side ranges>" (files with no added lines are dropped).
awk '
  function flush() { if (path != "" && r != "") print path "\t" r }
  /^--- / { minus = 1; next }
  /^\+\+\+ / && minus {
    flush(); minus = 0; r = ""
    path = substr($0, 5)
    if (path == "/dev/null") path = ""; else sub(/^b\//, "", path)
    next
  }
  { minus = 0 }
  /^@@ / && path != "" {
    s = $3; sub(/^\+/, "", s)
    n = split(s, a, ",")
    st = a[1] + 0; cnt = (n > 1) ? a[2] + 0 : 1
    if (cnt > 0) r = r (r == "" ? "" : ",") st "-" (st + cnt - 1)
  }
  END { flush() }
' "$TMP/diff" > "$TMP/ranges"

scanned=0
skipped=0
: > "$TMP/hits"

while IFS="$(printf '\t')" read -r f ranges; do
  [ -n "$f" ] || continue
  lang=""
  case "$f" in
    *.java|*.kt|*.kts|*.scala|*.groovy|*.cs|*.swift) lang=brace ;;
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs) lang=js ;;
    *.go) lang=go ;;
    *.py) lang=py ;;
  esac
  if [ -z "$lang" ]; then skipped=$((skipped + 1)); continue; fi
  if [ "${PRESCAN_INCLUDE_TESTS:-0}" != "1" ]; then
    case "/$f" in
      */test/*|*/tests/*|*/__tests__/*|*/testFixtures/*|*Test.java|*Tests.java|*IT.java|*Test.kt|*Tests.kt|*_test.go|*_test.py|*/test_*.py|*.test.*|*.spec.*)
        skipped=$((skipped + 1)); continue ;;
    esac
  fi
  [ -f "$WT/$f" ] || { skipped=$((skipped + 1)); continue; }
  scanned=$((scanned + 1))
  awk -v lang="$lang" -v added="$ranges" -f "$AWK_PROG" "$WT/$f" > "$TMP/one" \
    || fail "prescan.awk failed on $f"
  awk -v f="$f" 'BEGIN { FS = OFS = "\t" } { print $1, f, $2, $3, $4 }' "$TMP/one" >> "$TMP/hits"
done < "$TMP/ranges"

echo "PRESCAN base=$BASE_LABEL merge_base=$(git -C "$WT" rev-parse --short "$MB") head=$(git -C "$WT" rev-parse --short "$HEAD_SHA") files_scanned=$scanned files_skipped=$skipped"

sort -t "$(printf '\t')" -k2,2 -k3,3n -k1,1 "$TMP/hits" | awk '
  BEGIN { FS = "\t" }
  { k++; c[$1]++; printf "[%d] %s %s:%s — %s | %s\n", k, $1, $2, $3, $4, $5 }
  END {
    if (k == 0) print "No pre-scan hits."
    printf "PRESCAN_DONE hits=%d R1=%d R2=%d R3=%d R4=%d\n", k, c["R1"], c["R2"], c["R3"], c["R4"]
  }'
