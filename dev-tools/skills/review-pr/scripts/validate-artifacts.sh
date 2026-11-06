#!/usr/bin/env bash
# review-pr: validate the Step 9 artifacts before anything is posted.
#
# Usage: bash validate-artifacts.sh <N> <REVIEWS_DIR>
#
# Checks <REVIEWS_DIR>/pr_<N>_review.md (File A) and pr_<N>_comments.json
# (File B). File C (the HTML dashboard) is not checked.
#
# Exit 0  stdout: ARTIFACTS_OK comments=<count>
# Exit 1  stderr: every problem found, one per line.

set -u

if [ $# -ne 2 ]; then
  echo "usage: validate-artifacts.sh <N> <REVIEWS_DIR>" >&2
  exit 1
fi

exec python3 - "$1" "$2" <<'PY'
import json, os, re, sys

n_arg, reviews_dir = sys.argv[1], sys.argv[2]
errors = []

def err(msg):
    errors.append(msg)

def finish(count=None):
    if errors:
        for e in errors:
            sys.stderr.write("validate-artifacts: %s\n" % e)
        sys.exit(1)
    print("ARTIFACTS_OK comments=%d" % count)
    sys.exit(0)

if not n_arg.isdigit():
    err("PR number must be digits, got %r" % n_arg)
    finish()
N = n_arg
review_path = os.path.join(reviews_dir, "pr_%s_review.md" % N)
comments_path = os.path.join(reviews_dir, "pr_%s_comments.json" % N)

DASH = "[—–-]+"
SEVERITIES = ("Must resolve", "Should address", "Nice to have")
STATUSES = ("Open", "Resolved", "Partially addressed", "No longer relevant")
REQUIRED = ["Finding Index", "Context", "Review History", "Review Comments",
            "Verification Coverage", "Resolved Issues", "CI Status", "Strengths",
            "Recommended Action"]
ID_RE = re.compile(r"\[(\d+)-(\d+)\]")

# ---------------------------------------------------------------- File A

try:
    with open(review_path) as fh:
        text = fh.read()
except OSError:
    err("missing %s" % review_path)
    text = None

ids_headers = {}
if text is not None:
    if not text.strip():
        err("%s is empty" % review_path)
    # Ignore fenced code and HTML comments when reading structure.
    prose = re.sub(r"(?ms)^(```|~~~).*?^\1[^\n]*$", "", text)
    prose = re.sub(r"(?s)<!--.*?-->", "", prose)
    lines = prose.split("\n")

    first = next((l for l in text.split("\n") if l.strip()), "")
    if not re.match(r"^# PR #%s Review: .+ -- (OPEN|MERGED|CLOSED)\s*$" % N, first, re.I):
        err("first line must be '# PR #%s Review: <TICKET> | <title> -- <state>', got %r" % (N, first[:100]))
    for label in ("**PR:**", "**Author:**", "**Base branch:**", "**Last updated:**", "**Last author commit:**"):
        if label not in prose:
            err("header is missing the %s line" % label)
    if "**PR:** https://github.com/" not in prose or ("/pull/%s" % N) not in prose:
        err("**PR:** line must be https://github.com/<owner>/<repo>/pull/%s" % N)

    leftovers = sorted(set(re.findall(r"<(?:N|n|owner|repo|title|state|sha|path|line|TICKET|EPIC_KEY|YYYY-MM-DD|brief title|subject|author login|headRefName|baseRefName)>", prose)))
    if leftovers:
        err("template placeholders left in the review: %s" % ", ".join(leftovers))

    # Sections: map required name -> body text.
    sections, order, current = {}, [], None
    for line in lines:
        m = re.match(r"^## (?!#)(.*\S)\s*$", line)
        if m:
            title = m.group(1)
            if title.startswith("File:"):
                if current == "Review Comments":
                    sections[current].append(line)
                else:
                    err("'%s' must sit inside ## Review Comments" % line.strip())
                continue
            name = next((r for r in REQUIRED if title == r or (r == "CI Status" and title.startswith("CI Status"))), None)
            if name is None:
                err("unexpected section '## %s'" % title)
                current = None
                continue
            if name in sections:
                err("duplicate section '## %s'" % name)
            order.append(name)
            sections[name] = []
            current = name
            continue
        if current:
            sections[current].append(line)

    missing = [r for r in REQUIRED if r not in sections]
    if missing:
        err("missing section(s): %s" % ", ".join("## " + m for m in missing))
    present = [r for r in REQUIRED if r in sections]
    if order and [o for o in order if o in present] != present:
        err("sections out of order; expected: %s" % " > ".join(REQUIRED))
    if order and order[0] != "Finding Index":
        err("## Finding Index must be the first ## section")
    if "CI Status" in sections and not re.search(r"(?m)^## CI Status \(as of .+\)", prose):
        err("CI section header must be '## CI Status (as of <date>)'")
    for name, body in sections.items():
        if not "".join(body).strip():
            err("## %s is empty (write None if there is nothing to say)" % name)

    # Finding headers.
    for line in lines:
        m = re.match(r"^### \[(\d+)-(\d+)\] (.+?) %s (.+)$" % DASH, line)
        if line.startswith("### [") and not m:
            err("finding header not in '### [%s-<n>] <Severity> — <title>' form: %r" % (N, line[:100]))
            continue
        if not m:
            continue
        pr, k, sev = m.group(1), int(m.group(2)), m.group(3)
        if pr != N:
            err("finding [%s-%d] belongs to another PR" % (pr, k))
            continue
        if sev not in SEVERITIES:
            err("[%s-%d] severity %r is not one of %s" % (N, k, sev, ", ".join(SEVERITIES)))
        if k in ids_headers:
            err("[%s-%d] has two finding headers" % (N, k))
        ids_headers[k] = sev

    # Finding Index rows.
    index = {}
    for line in sections.get("Finding Index", []):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not line.strip().startswith("|") or len(cells) < 6 or not ID_RE.fullmatch(cells[0]):
            continue
        pr, k = ID_RE.fullmatch(cells[0]).groups()
        k = int(k)
        if pr != N:
            err("Finding Index row %s belongs to another PR" % cells[0])
            continue
        sev, status, thread = cells[2], cells[3], cells[4]
        if k in index:
            err("[%s-%d] appears twice in the Finding Index" % (N, k))
        index[k] = status
        if status not in STATUSES:
            err("[%s-%d] status %r is not one of %s" % (N, k, status, ", ".join(STATUSES)))
        if k in ids_headers and sev != ids_headers[k]:
            err("[%s-%d] severity differs: index %r, header %r" % (N, k, sev, ids_headers[k]))
        if thread != "-" and not re.fullmatch(r"(\[#r\d+\]\(\S+#discussion_r\d+\)[ ,]*)+", thread):
            err("[%s-%d] Thread cell must be '-' or [#r<id>](<PR_URL>#discussion_r<id>), got %r" % (N, k, thread))
    for k in sorted(set(ids_headers) - set(index)):
        err("[%s-%d] has a finding header but no Finding Index row" % (N, k))
    for k in sorted(set(index) - set(ids_headers)):
        err("[%s-%d] is in the Finding Index but has no finding header" % (N, k))

    # Recommended Action must carry every open finding.
    action = "\n".join(sections.get("Recommended Action", []))
    for k, status in sorted(index.items()):
        if status in ("Open", "Partially addressed") and ("[%s-%d]" % (N, k)) not in action:
            err("[%s-%d] is %s but has no Recommended Action bullet" % (N, k, status))

    # Verification Coverage.
    cov = "\n".join(sections.get("Verification Coverage", []))
    m = re.search(r"(\d+) pre-scan obligations? %s (\d+) confirmed, (\d+) cleared with evidence, (\d+) unverified" % DASH, cov)
    if not m:
        err("## Verification Coverage needs the tally line '<n> pre-scan obligations — <n> confirmed, <n> cleared with evidence, <n> unverified'")
    else:
        total, conf, clr, unv = (int(x) for x in m.groups())
        if conf + clr + unv != total:
            err("Verification Coverage tally does not add up: %d + %d + %d != %d" % (conf, clr, unv, total))
        gm = re.search(r"\*\*Verification gaps:\*\*(.*)", cov, re.S)
        if not gm:
            err("## Verification Coverage needs a '**Verification gaps:**' part (write None if there are none)")
        else:
            gap_text = gm.group(1)
            bullets = [l for l in gap_text.split("\n") if re.match(r"^\s*[-*] \S", l)]
            says_none = re.match(r"^\s*None\b", gap_text) is not None
            if not bullets and not says_none:
                err("Verification gaps is empty; list the gaps or write None")
            if unv and not bullets:
                err("%d unverified obligation(s) but no Verification gaps listed" % unv)
            if bullets and len(bullets) < unv:
                err("%d unverified obligation(s) but only %d gap(s) listed" % (unv, len(bullets)))
            for b in bullets:
                if not re.search(r"%s blocked on \S" % DASH, b):
                    err("gap not in '<obligation> — blocked on <what would settle it>' form: %r" % b.strip()[:100])

# ---------------------------------------------------------------- File B

count = 0
try:
    with open(comments_path) as fh:
        comments = json.load(fh)
except OSError:
    err("missing %s (write [] when no finding maps to a diff line)" % comments_path)
    comments = None
except ValueError as exc:
    err("%s is not valid JSON: %s" % (comments_path, exc))
    comments = None

if comments is not None:
    if not isinstance(comments, list):
        err("%s must be a JSON array" % comments_path)
    else:
        count = len(comments)
        allowed = {"path", "line", "side", "start_line", "start_side", "subject_type", "body"}
        for i, c in enumerate(comments, 1):
            where = "comments.json item %d" % i
            if not isinstance(c, dict):
                err("%s is not an object" % where)
                continue
            extra = set(c) - allowed
            if extra:
                err("%s has unknown key(s): %s" % (where, ", ".join(sorted(extra))))
            if not isinstance(c.get("path"), str) or not c["path"]:
                err("%s needs a path" % where)
            body = c.get("body")
            if not isinstance(body, str) or not body.strip():
                err("%s needs a body" % where)
            else:
                m = re.match(r"^\[(\d+)-(\d+)\]", body)
                if not m or m.group(1) != N:
                    err("%s body must start with its [%s-<n>] finding ID" % (where, N))
                elif text is not None and int(m.group(2)) not in ids_headers:
                    err("%s body tag [%s-%s] has no finding in the review file" % (where, N, m.group(2)))
            if c.get("subject_type") == "file":
                for k in ("line", "side", "start_line", "start_side"):
                    if k in c:
                        err("%s is file-level but has %s" % (where, k))
                continue
            if "subject_type" in c and c["subject_type"] != "line":
                err('%s subject_type must be "file" or "line"' % where)
            line = c.get("line")
            if not isinstance(line, int) or isinstance(line, bool) or line < 1:
                err("%s needs a positive integer line" % where)
            if c.get("side") not in ("RIGHT", "LEFT"):
                err('%s side must be "RIGHT" or "LEFT"' % where)
            if "start_line" in c or "start_side" in c:
                sl = c.get("start_line")
                if not isinstance(sl, int) or isinstance(sl, bool) or c.get("start_side") not in ("RIGHT", "LEFT"):
                    err("%s range needs integer start_line and start_side RIGHT/LEFT" % where)
                elif isinstance(line, int) and c.get("start_side") == c.get("side") and sl >= line:
                    err("%s start_line must be below line" % where)

finish(count)
PY
