#!/usr/bin/env bash
# review-pr preflight: check tools and read the user's settings file.
#
# Usage: bash preflight.sh
#
# Exit 0  stdout: REVIEWS_DIR=, KB_DIR=, EXTRA_CHECKS=, CLI=, one
#         "REPO <owner/repo>=<path>" line per configured repo, then PREFLIGHT_OK.
#         KB_DIR and EXTRA_CHECKS are NONE when not configured.
# Exit 2  stdout: NO_CONFIG=<path> (first run: the skill writes the file there).
# Exit 1  any other problem; the reason is on stderr.
#
# REVIEW_PR_CONFIG overrides the settings path (used for testing).

set -u

CONFIG="${REVIEW_PR_CONFIG:-$HOME/.claude/review-pr.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/pr-review-cli"

fail() { echo "preflight: $*" >&2; exit 1; }

for tool in git gh python3; do
  command -v "$tool" >/dev/null 2>&1 || fail "'$tool' is not installed or not on PATH."
done

[ -f "$CLI" ] || fail "bundled CLI not found at $CLI."

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  fail "gh is not logged in to github.com. Run: gh auth login --hostname github.com"
fi

if [ ! -f "$CONFIG" ]; then
  echo "NO_CONFIG=$CONFIG"
  exit 2
fi

# Parse and check the settings with Python (no jq dependency).
python3 - "$CONFIG" "$CLI" <<'PY'
import json, os, sys

config_path, cli = sys.argv[1], sys.argv[2]
errors = []

def fail(msg):
    sys.stderr.write("preflight: " + msg + "\n")
    sys.exit(1)

try:
    with open(config_path) as fh:
        cfg = json.load(fh)
except ValueError as exc:
    fail("%s is not valid JSON: %s" % (config_path, exc))
if not isinstance(cfg, dict):
    fail("%s must hold a JSON object." % config_path)

known = {"reviews_dir", "kb_dir", "repos", "extra_checks"}
unknown = sorted(set(cfg) - known)
if unknown:
    errors.append("unknown key(s) in %s: %s (expected: %s)"
                  % (config_path, ", ".join(unknown), ", ".join(sorted(known))))

def path_value(key):
    value = cfg.get(key)
    if value is None or value == "":
        return None
    if not isinstance(value, str):
        errors.append("'%s' must be a string path." % key)
        return None
    return os.path.abspath(os.path.expanduser(value))

reviews_dir = path_value("reviews_dir")
if reviews_dir is None:
    errors.append("'reviews_dir' is required in %s." % config_path)
elif not os.path.isdir(reviews_dir):
    errors.append("reviews_dir does not exist: %s (create it with mkdir -p)." % reviews_dir)
elif not os.access(reviews_dir, os.W_OK):
    errors.append("reviews_dir is not writable: %s" % reviews_dir)

kb_dir = path_value("kb_dir")
if kb_dir is not None and not os.path.isdir(kb_dir):
    errors.append("kb_dir does not exist: %s (fix it or remove the key)." % kb_dir)

extra = path_value("extra_checks")
if extra is not None and not os.path.isfile(extra):
    errors.append("extra_checks file not found: %s (fix it or remove the key)." % extra)

repo_lines = []
repos = cfg.get("repos", {})
if not isinstance(repos, dict):
    errors.append("'repos' must be an object mapping owner/repo to a local path.")
    repos = {}
for name in sorted(repos):
    raw = repos[name]
    if name.count("/") != 1 or not all(name.split("/")):
        errors.append("repos key '%s' must look like owner/repo." % name)
        continue
    if not isinstance(raw, str) or not raw:
        errors.append("repos['%s'] must be a path string." % name)
        continue
    path = os.path.abspath(os.path.expanduser(raw))
    if not os.path.isdir(os.path.join(path, ".git")) and not os.path.isfile(os.path.join(path, ".git")):
        errors.append("repos['%s'] is not a git checkout: %s" % (name, path))
        continue
    repo_lines.append("REPO %s=%s" % (name, path))

if errors:
    for e in errors:
        sys.stderr.write("preflight: " + e + "\n")
    sys.exit(1)

print("REVIEWS_DIR=" + reviews_dir)
print("KB_DIR=" + (kb_dir or "NONE"))
print("EXTRA_CHECKS=" + (extra or "NONE"))
print("CLI=" + cli)
for line in repo_lines:
    print(line)
print("PREFLIGHT_OK")
PY
