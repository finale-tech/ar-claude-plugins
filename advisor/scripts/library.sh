#!/usr/bin/env bash
# library.sh — read the advisor library and a domain's own manual.
#
# The library (advisor/library/) holds the general plan (playbook.md). A domain's
# operating-manual.md holds the user's patterns, instincts and rules, each written
# in full. For each of its headings the script knows three cases:
#   LOCAL      matches no library entry and carries its own text: the normal case,
#              since the library holds no manual entries today.
#   OVERLAY    matches a library heading and carries only the user's own lines
#              (Status, Instances, Source, My angle): the library text is joined in.
#   FULL COPY  matches a library heading and still carries the general text: the
#              user's text is used as it stands and the library's is left out.
# The two join cases apply only if general manual entries are ever added to the
# library again. A heading with no text of its own is an error. This script owns
# that check, so a name that resolves to nothing stops the run.
#
# Usage:
#   library.sh index [type]              one line per library entry: type | name | file | summary
#   library.sh show <name> [<name>...]   full text of the named entries
#   library.sh mine <DOMAIN_PATH> <patterns|instincts|rules|all> [--active]
#                                        the user's manual by section (library text joined
#                                        in where a heading matches a library entry);
#                                        --active keeps only patterns whose Status is active
#   library.sh check <DOMAIN_PATH>       validate the join for a domain
#   library.sh lint [--deny <file>]      validate the library on its own; --deny names a
#                                        file of terms (one per line) that must not appear
#
# An entry is a level-3 or level-4 heading with no deeper heading under it, or a
# paragraph that starts with a bold rule ID (**R-ABC-1. ...**). Headings inside
# fenced code blocks are ignored. Names are unique across the whole library.
#
# Stdout on success ends with LIBRARY_OK (check) or LINT_OK (lint).
# Exit non-zero with "LIBRARY FAILED: <reason>" on stderr otherwise.
#
# Env override (for testing): ADVISOR_LIBRARY
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBRARY="${ADVISOR_LIBRARY:-$SCRIPT_DIR/../library}"

fail() { echo "LIBRARY FAILED: $1" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || fail "python3 not found on PATH."
[ -d "$LIBRARY" ] || fail "no library folder at $LIBRARY."
[ $# -ge 1 ] || fail "no command given. Usage: library.sh <index|show|mine|check|lint> ..."

python3 -I - "$LIBRARY" "$@" <<'PY'
import difflib, os, re, sys

LIB = os.path.abspath(sys.argv[1])
CMD = sys.argv[2]
ARGS = sys.argv[3:]

HEAD = re.compile(r'^(#{1,6})\s+(.*?)\s*$')
FENCE = re.compile(r'^\s*(```|~~~)')
RULE = re.compile(r'^\*\*(R-[A-Z]+-\d+)\.')
SECTION_TYPE = {"Patterns": "pattern", "Instincts": "instinct", "Daily Rules": "daily-rule"}
MINE_SECTIONS = {"patterns": "Patterns", "instincts": "Instincts", "rules": "Daily Rules"}
# Lines that mark general text. An overlay must not carry any of them.
DEFINITION = re.compile(
    r'^(Instead of |> |\*\*(What it looks like|The tell|Why it\'s dangerous|The counter|Why|Detection questions)[^*]*\*\*)')
# Lines an overlay is made of.
OVERLAY = re.compile(r'^(\*Status:|\*Source:|\*\*(Instances|First instance|My angle):\*\*)')
STATUS = re.compile(r'^\*Status:\s*([A-Za-z-]+)')


def die(msg, code=1):
    sys.stderr.write("LIBRARY FAILED: %s\n" % msg)
    sys.exit(code)


def trim(lines):
    """Drop leading/trailing blank lines and trailing horizontal rules."""
    out = list(lines)
    while out and not out[0].strip():
        out.pop(0)
    while out and (not out[-1].strip() or out[-1].strip() == "---"):
        out.pop()
    return out


def parse(path):
    """Headings of a Markdown file, in order, each with its own body lines."""
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    nodes, fenced = [], False
    for i, line in enumerate(lines):
        if FENCE.match(line):
            fenced = not fenced
            continue
        if fenced:
            continue
        m = HEAD.match(line)
        if m:
            nodes.append({"level": len(m.group(1)), "title": m.group(2), "line": i})
    for j, n in enumerate(nodes):
        end = nodes[j + 1]["line"] if j + 1 < len(nodes) else len(lines)
        n["body"] = lines[n["line"] + 1:end]
        nxt = nodes[j + 1]["level"] if j + 1 < len(nodes) else 0
        n["leaf"] = nxt <= n["level"]
        n["h2"] = None
        for k in range(j, -1, -1):
            if nodes[k]["level"] == 2:
                n["h2"] = nodes[k]["title"]
                break
            if nodes[k]["level"] < 2:
                break
    return lines, nodes


def summary(body):
    for ln in body:
        if ln.startswith("Instead of "):
            return ln.strip()
    return ""


def library():
    """All library entries, in file order, and a name -> entry map."""
    entries, dupes = [], []
    files = []
    for d, _, fs in os.walk(LIB):
        for fn in fs:
            if fn.endswith(".md"):
                files.append(os.path.join(d, fn))
    for path in sorted(files):
        rel = os.path.relpath(path, LIB)
        stem = os.path.splitext(rel)[0].replace(os.sep, "-")
        _, nodes = parse(path)
        for n in nodes:
            if rel == "operating-manual.md":
                etype = SECTION_TYPE.get(n["h2"] or "", "manual")
            elif stem.startswith("domains-"):
                etype = "domain-" + stem[len("domains-"):]
            else:
                etype = stem
            if n["leaf"] and n["level"] in (3, 4):
                entries.append({"type": etype, "name": n["title"], "file": rel,
                                "level": n["level"], "body": trim(n["body"])})
            # Rule entries: bold-ID paragraphs anywhere in a heading's own body.
            para = None
            for ln in n["body"] + [""]:
                m = RULE.match(ln)
                if m:
                    para = {"type": "rule", "name": m.group(1), "file": rel,
                            "level": 0, "body": [ln]}
                    entries.append(para)
                elif para is not None:
                    if ln.strip():
                        para["body"].append(ln)
                    else:
                        para = None
    by_name = {}
    for e in entries:
        if e["name"] in by_name:
            dupes.append("'%s' (%s and %s)" % (e["name"], by_name[e["name"]]["file"], e["file"]))
        else:
            by_name[e["name"]] = e
    return entries, by_name, dupes


def manual(domain):
    path = os.path.join(domain, "operating-manual.md")
    if not os.path.isfile(path):
        return None, []
    lines, nodes = parse(path)
    return path, nodes


def classify(node, by_name):
    """overlay | full | local | a problem string, for one leaf heading of the user's manual."""
    body = trim(node["body"])
    has_definition = any(DEFINITION.match(ln) for ln in body)
    own_text = any(ln.strip() and ln.strip() != "---" and not OVERLAY.match(ln) for ln in body)
    hit = by_name.get(node["title"])
    if hit is not None:
        want = SECTION_TYPE.get(node["h2"] or "")
        if want and hit["type"] != want:
            return "'%s' is listed under %s but the library has it as a %s (%s)." % (
                node["title"], node["h2"], hit["type"], hit["file"])
        # The user's file still holds the general text for this entry: use it as
        # it stands. Slimming an entry down to an overlay is the user's choice.
        # A daily rule has no fixed layout to recognise, so any text of the user's
        # own under its name counts as their copy of it.
        if has_definition or (hit["type"] == "daily-rule" and own_text):
            return "full"
        return "overlay"
    if has_definition or own_text:
        return "local"
    near = difflib.get_close_matches(node["title"], list(by_name), n=1, cutoff=0.6)
    hint = " Closest library name: '%s'." % near[0] if near else ""
    return ("'%s' is not in the library and has no text of its own — fix the name or write "
            "the entry in full.%s" % (node["title"], hint))


def user_entries(nodes):
    return [n for n in nodes
            if n["leaf"] and n["level"] in (3, 4) and (n["h2"] or "") in SECTION_TYPE]


def status_of(node):
    for ln in node["body"]:
        m = STATUS.match(ln)
        if m:
            return m.group(1).lower()
    return "active"


def cmd_index(args):
    entries, _, dupes = library()
    if dupes:
        die("duplicate names in the library: %s" % "; ".join(dupes))
    want = args[0] if args else None
    shown = 0
    for e in entries:
        if want and e["type"] != want:
            continue
        print("%s | %s | %s | %s" % (e["type"], e["name"], e["file"], summary(e["body"])))
        shown += 1
    if want and not shown:
        types = sorted({e["type"] for e in entries})
        die("no library entries of type '%s'. Types: %s" % (want, ", ".join(types)), 2)


def cmd_show(args):
    if not args:
        die("show needs at least one entry name.", 2)
    _, by_name, dupes = library()
    if dupes:
        die("duplicate names in the library: %s" % "; ".join(dupes))
    missing = []
    for name in args:
        if name not in by_name:
            near = difflib.get_close_matches(name, list(by_name), n=1, cutoff=0.6)
            missing.append("'%s'%s" % (name, " (closest: '%s')" % near[0] if near else ""))
    if missing:
        die("not in the library: %s" % "; ".join(missing), 2)
    for name in args:
        e = by_name[name]
        print("<!-- library/%s · %s -->" % (e["file"], e["type"]))
        if e["level"]:
            print("%s %s\n" % ("#" * e["level"], e["name"]))
        print("\n".join(e["body"]))
        print()


def cmd_check(args):
    if not args:
        die("check needs a DOMAIN_PATH.", 2)
    entries, by_name, dupes = library()
    problems = ["duplicate name in the library: %s" % d for d in dupes]
    path, nodes = manual(args[0])
    overlays = full = local = 0
    seen = {}
    for n in user_entries(nodes):
        if n["title"] in seen:
            problems.append("'%s' appears twice in %s." % (n["title"], path))
            continue
        seen[n["title"]] = True
        kind = classify(n, by_name)
        if kind == "overlay":
            overlays += 1
        elif kind == "full":
            full += 1
        elif kind == "local":
            local += 1
        else:
            problems.append(kind)
    if problems:
        sys.stderr.write("LIBRARY FAILED: %d problem(s) joining %s with the library:\n" % (
            len(problems), path or args[0]))
        for p in problems:
            sys.stderr.write("  - %s\n" % p)
        sys.exit(1)
    print("STEP LIBRARY-CHECK: %d library entries, %d overlays, %d full copies, %d local · OK" % (
        len(entries), overlays, full, local))
    print("LIBRARY_OK library_entries=%d overlays=%d full_copies=%d local=%d" % (
        len(entries), overlays, full, local))


def cmd_mine(args):
    active_only = "--active" in args
    args = [a for a in args if a != "--active"]
    if len(args) != 2 or args[1] not in list(MINE_SECTIONS) + ["all"]:
        die("usage: library.sh mine <DOMAIN_PATH> <patterns|instincts|rules|all> [--active]", 2)
    domain, what = args
    _, by_name, dupes = library()
    if dupes:
        die("duplicate names in the library: %s" % "; ".join(dupes))
    path, nodes = manual(domain)
    # Intro lines of the library's grouping headings (a heading with entries under it).
    groups = {}
    lib_manual = os.path.join(LIB, "operating-manual.md")
    if os.path.isfile(lib_manual):
        for n in parse(lib_manual)[1]:
            if not n["leaf"] and n["level"] in (3, 4):
                groups[n["title"]] = trim(n["body"])
    wanted = list(MINE_SECTIONS) if what == "all" else [what]
    for key in wanted:
        section = MINE_SECTIONS[key]
        print("## %s\n" % section)
        mine = [n for n in nodes if n["h2"] == section]
        if key == "rules":
            # Daily Rules apply as a whole: the library's section, then the user's own.
            # A rule the user's file also holds is printed once, from their file.
            own_titles = {n["title"] for n in mine}
            for n in mine:
                if n["level"] == 2 and trim(n["body"]):
                    print("\n".join(trim(n["body"])) + "\n")
            lib_path = os.path.join(LIB, "operating-manual.md")
            if os.path.isfile(lib_path):
                _, lib_nodes = parse(lib_path)
                for n in lib_nodes:
                    if n["h2"] == section and n["level"] > 2 and n["title"] not in own_titles:
                        print("%s %s" % ("#" * n["level"], n["title"]))
                        print("\n".join(n["body"]))
            for n in mine:
                if n["level"] > 2:
                    print("%s %s" % ("#" * n["level"], n["title"]))
                    print("\n".join(n["body"]))
            continue
        printed = 0
        for n in mine:
            if n["level"] == 2:
                intro = trim(n["body"])
                if intro:
                    print("\n".join(intro) + "\n")
                continue
            heading = "%s %s" % ("#" * n["level"], n["title"])
            if not (n["leaf"] and n["level"] in (3, 4)):
                # A grouping heading. Its intro comes from the user's file, or,
                # when the user's file has none, from the same group in the library.
                print(heading)
                body = trim(n["body"]) or groups.get(n["title"], [])
                print(("\n" + "\n".join(body) + "\n") if body else "")
                continue
            kind = classify(n, by_name)
            if kind not in ("overlay", "full", "local"):
                die("%s Run `library.sh check` for the full list." % kind)
            if active_only and key == "patterns" and status_of(n) != "active":
                continue
            print(heading + "\n")
            if kind == "overlay":
                print("\n".join(by_name[n["title"]]["body"]) + "\n")
            own = trim(n["body"])
            if own:
                print("\n".join(own) + "\n")
            printed += 1
        if not printed:
            where = "no operating-manual.md in %s" % domain if path is None else "none listed in %s" % path
            print("*(%s%s)*\n" % ("no active entries; " if active_only and key == "patterns" else "", where))


def cmd_lint(args):
    deny_file = None
    if args[:1] == ["--deny"]:
        if len(args) < 2:
            die("--deny needs a file.", 2)
        deny_file = args[1]
    entries, by_name, dupes = library()
    problems = ["duplicate name: %s" % d for d in dupes]
    rule_ids = {e["name"] for e in entries if e["type"] == "rule"}
    sources = set()
    src_path = os.path.join(LIB, "sources.md")
    if os.path.isfile(src_path):
        with open(src_path, encoding="utf-8") as f:
            sources = set(re.findall(r'(?m)^(?:\|\s*|-\s*|\*\*)?(S\d+[a-z]?)\b', f.read()))
    deny = []
    if deny_file:
        if not os.path.isfile(deny_file):
            die("deny file '%s' not found." % deny_file, 2)
        with open(deny_file, encoding="utf-8") as f:
            deny = [t.strip() for t in f if t.strip() and not t.startswith("#")]
    named_ref = re.compile(r'(?i)\b(?:instinct|pattern|framework|script)s?\s+\*([^*\n]+)\*')
    related_ref = re.compile(r'Related (?:pattern|instinct):\s*([^.*\n]+)')
    rule_ref = re.compile(r'\bR-[A-Z]+-\d+\b')
    tag_ref = re.compile(r'\[((?:S\d+[a-z]?(?:·K)?(?:,\s*)?)+)\]')
    months = r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*'
    date_ref = re.compile(
        r'\b20\d\d-\d\d-\d\d\b|\b%s \d{1,2}, 20\d\d\b|\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]*,? %s \d{1,2}\b'
        % (months, months))
    for d, _, fs in os.walk(LIB):
        for fn in sorted(fs):
            if not fn.endswith(".md"):
                continue
            path = os.path.join(d, fn)
            rel = os.path.relpath(path, LIB)
            with open(path, encoding="utf-8") as f:
                for no, ln in enumerate(f.read().split("\n"), 1):
                    at = "%s:%d" % (rel, no)
                    for m in list(named_ref.finditer(ln)) + list(related_ref.finditer(ln)):
                        name = m.group(1).strip()
                        if name not in by_name:
                            problems.append("%s refers to '%s', which is not a library entry." % (at, name))
                    for rid in rule_ref.findall(ln):
                        if rid not in rule_ids:
                            problems.append("%s cites %s, which is not a library rule." % (at, rid))
                    for m in tag_ref.finditer(ln):
                        for tag in re.findall(r'S\d+[a-z]?', m.group(1)):
                            if tag not in sources:
                                problems.append("%s cites source %s, which sources.md does not define." % (at, tag))
                    if rel != "sources.md" and date_ref.search(ln):
                        problems.append("%s has a calendar date — use a relative day or week." % at)
                    low = ln.lower()
                    for term in deny:
                        if term.lower() in low:
                            problems.append("%s contains the private term '%s'." % (at, term))
    if problems:
        sys.stderr.write("LIBRARY FAILED: %d problem(s) in the library:\n" % len(problems))
        for p in problems:
            sys.stderr.write("  - %s\n" % p)
        sys.exit(1)
    print("STEP LIBRARY-LINT: %d entries, references resolve%s · OK" % (
        len(entries), ", %d private terms absent" % len(deny) if deny else ""))
    print("LINT_OK entries=%d" % len(entries))


COMMANDS = {"index": cmd_index, "show": cmd_show, "mine": cmd_mine, "check": cmd_check, "lint": cmd_lint}
if CMD not in COMMANDS:
    die("unknown command '%s'. Use index, show, mine, check or lint." % CMD, 2)
COMMANDS[CMD](ARGS)
PY
