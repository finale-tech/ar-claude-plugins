# prescan.awk — review-pr deterministic pre-scan, one source file per run.
#
# Called by prescan.sh:
#   awk -v lang=<brace|js|go|py> -v added=<ranges> -f prescan.awk FILE
#
#   lang    brace = Java/Kotlin/Scala/Groovy/C#/Swift, js = JS/TS, go, py
#   added   new-side line ranges added by the PR, e.g. "12-14,40-40"
#
# Output: one tab-separated hit per line:  RULE  LINE  WHAT  EXCERPT
# A shape is reported only when it touches an added line. Rules:
#   R1  a caught exception reaches a logging/stdout sink
#   R2  an empty catch, or a catch that does not rethrow (swallows)
#   R3  an input-bearing parse (throws or misbehaves on bad input)
#   R4  an identifier-shaped argument (id, email, token...) in a sink call
#
# Heuristic by design: it puts shapes on the agenda, it decides nothing.
# String literals and comments are blanked before matching, so text in
# log messages never triggers a hit.

function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }

function clean(s) { s = trim(s); gsub(/\t/, " ", s); if (length(s) > 120) s = substr(s, 1, 117) "..."; return s }

function range_added(a, b,   i) { for (i = a; i <= b; i++) if (i in ADDED) return 1; return 0 }

function hit(rule, line, what) { printf "%s\t%d\t%s\t%s\n", rule, line, clean(what), clean(LINES[line]) }

function has_word(s, w) {
  if (w !~ /^[A-Za-z_][A-Za-z0-9_]*$/) return 0
  return match(s, "(^|[^A-Za-z0-9_$])" w "([^A-Za-z0-9_$]|$)")
}

function paren_delta(s,   o, c) { o = gsub(/\(/, "(", s); c = gsub(/\)/, ")", s); return o - c }

# Blank string literals and drop comments; tracks /* */ across lines.
function strip_code(s,   p, q, out) {
  if (IN_BLOCK) {
    p = index(s, "*/")
    if (p == 0) return ""
    s = substr(s, p + 2); IN_BLOCK = 0
  }
  gsub(/"([^"\\]|\\.)*"/, "\"\"", s)
  if (LANG == "py" || LANG == "js") gsub(/'([^'\\]|\\.)*'/, "''", s)
  else gsub(/'([^'\\]|\\.)'/, "''", s)
  gsub(/`[^`]*`/, "``", s)
  if (LANG == "py") { p = index(s, "#"); if (p) s = substr(s, 1, p - 1); return s }
  out = ""
  while (1) {
    p = index(s, "//"); q = index(s, "/*")
    if (p && (!q || p < q)) return out substr(s, 1, p - 1)
    if (!q) return out s
    out = out substr(s, 1, q - 1) " "
    s = substr(s, q + 2)
    p = index(s, "*/")
    if (p == 0) { IN_BLOCK = 1; return out }
    s = substr(s, p + 2)
  }
}

function idshape(t) {
  if (length(t) < 2 || t ~ /^[0-9]/) return 0
  if (t ~ /^(id|ID|uuid|UUID|guid|email|ssn|SSN|token|password|passwd|secret|pan|PAN|iban|IBAN|phone|username|userName|dob)$/) return 1
  if (t ~ /[a-z0-9](Id|ID|Ids|IDs|Uuid|UUID|Guid|Email|Ssn|SSN|Token|Password|Secret|Pan|PAN|Iban|IBAN|Phone)$/) return 1
  if (t ~ /(account|card|phone|routing|tax|social)Number$/) return 1
  if (t ~ /_(id|ids|uuid|guid|email|ssn|token|password|secret|pan|iban|phone)$/) return 1
  return 0
}

# ---- catch blocks (brace languages and Go's `if err != nil {`) ----

function catch_start(code) {
  if (LANG == "go") {
    if (code !~ /^[ \t]*(\}[ \t]*else[ \t]+)?if[ \t]/) return 0
    return match(code, /(^|[^A-Za-z0-9_])(err[A-Za-z0-9_]*|e)[ \t]*!=[ \t]*nil/)
  }
  return match(code, /(^|[^A-Za-z0-9_])catch[ \t]*[({]/)
}

function catch_var(rest,   p, inner, n, toks) {
  if (LANG == "go") { sub(/[ \t]*!=.*/, "", rest); sub(/^[^A-Za-z_]+/, "", rest); return rest }
  p = index(rest, "(")
  if (p == 0 || p > index(rest "{", "{")) return "error"
  inner = substr(rest, p + 1)
  if (!index(inner, ")")) return ""
  sub(/\).*/, "", inner)
  if (index(inner, ":")) { sub(/:.*/, "", inner); inner = trim(inner); sub(/^(val|var|let)[ \t]+/, "", inner); return inner }
  n = split(trim(inner), toks, /[ \t|]+/)
  return n ? toks[n] : ""
}

function propagates(text, v) {
  if (LANG == "go") return has_word(text, "panic") || match(text, /log\.Fatal/) || (has_word(text, "return") && has_word(text, v))
  return has_word(text, "throw") || has_word(text, "reject")
}

function close_catch(   text, start, v, compact) {
  text = CS_TEXT[TOP]; start = CS_LINE[TOP]; v = CS_VAR[TOP]
  compact = text; gsub(/[ \t\r\n;]/, "", compact)
  if (range_added(start, NR)) {
    if (compact == "") hit("R2", start, "empty " (LANG == "go" ? "error branch" : "catch") (v != "" ? " (" v ")" : ""))
    else if (!propagates(text, v)) hit("R2", start, (LANG == "go" ? "error branch does not return or panic with " : "catch does not rethrow ") (v != "" ? v : "the exception"))
  }
  TOP--
  if (TOP > 0) CS_TEXT[TOP] = CS_TEXT[TOP] "{" text "}"
}

function brace_line(code,   cpos, v, len, i, c) {
  cpos = 0
  if (catch_start(code)) { cpos = RSTART; v = catch_var(substr(code, RSTART)) }
  len = length(code)
  for (i = 1; i <= len; i++) {
    if (i == cpos) { PEND = 1; PEND_VAR = v; PEND_LINE = NR }
    c = substr(code, i, 1)
    if (c == "{") {
      DEPTH++
      if (PEND) { TOP++; CS_LEVEL[TOP] = DEPTH; CS_LINE[TOP] = PEND_LINE; CS_VAR[TOP] = PEND_VAR; CS_TEXT[TOP] = ""; PEND = 0; continue }
    } else if (c == "}") {
      if (TOP > 0 && DEPTH == CS_LEVEL[TOP]) { close_catch(); DEPTH--; continue }
      DEPTH--
    }
    if (TOP > 0) CS_TEXT[TOP] = CS_TEXT[TOP] c
  }
  if (TOP > 0) CS_TEXT[TOP] = CS_TEXT[TOP] "\n"
}

function brace_scope(code,   s, k) {
  s = " "
  for (k = 1; k <= TOP; k++) s = s CS_VAR[k] " "
  if (catch_start(code)) s = s catch_var(substr(code, RSTART)) " "
  return s
}

# ---- Python except blocks (indentation) ----

function py_close(   compact) {
  PY_OPEN = 0
  if (!range_added(PY_LINE, PY_LAST)) return
  compact = PY_TEXT; gsub(/[ \t\r\n;]/, "", compact)
  if (compact == "" || compact == "pass" || compact == "...") hit("R2", PY_LINE, "empty except" (PY_VAR != "" ? " (" PY_VAR ")" : ""))
  else if (!has_word(PY_TEXT, "raise")) hit("R2", PY_LINE, "except does not re-raise " (PY_VAR != "" ? PY_VAR : "the exception"))
}

function py_line(code,   t, ind, p) {
  t = trim(code)
  if (t == "") return
  match(code, /^[ \t]*/); ind = RLENGTH
  if (PY_OPEN && ind <= PY_IND) py_close()
  if (!PY_OPEN && t ~ /^except([ \t(:]|$)/) {
    PY_OPEN = 1; PY_IND = ind; PY_LINE = NR; PY_LAST = NR; PY_TEXT = ""; PY_VAR = ""
    if (match(t, /[ \t]as[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) { PY_VAR = substr(t, RSTART, RLENGTH); sub(/^[ \t]as[ \t]+/, "", PY_VAR) }
    p = index(t, ":")
    if (p && trim(substr(t, p + 1)) != "") PY_TEXT = substr(t, p + 1) "\n"
    return
  }
  if (PY_OPEN) { PY_TEXT = PY_TEXT t "\n"; PY_LAST = NR }
}

# ---- sinks (R1, R4) ----

function sink_scan(code, scope) {
  if (SB_OPEN) {
    SB_TEXT = SB_TEXT " " code
    SB_BAL += paren_delta(code)
    if (SB_BAL <= 0 || NR - SB_LINE >= 15) sink_eval()
    return
  }
  SB_KIND = ""
  if (match(code, SINK_LOG)) SB_KIND = "log"
  else if (match(code, SINK_STD)) SB_KIND = "std"
  else if (match(code, SINK_EXC)) SB_KIND = "exc"
  if (SB_KIND == "") return
  SB_OPEN = 1; SB_LINE = NR; SB_TEXT = substr(code, RSTART); SB_SCOPE = scope
  SB_BAL = paren_delta(SB_TEXT)
  if (SB_BAL <= 0) sink_eval()
}

function sink_eval(   text, call, p, args, nv, vars, i, done, n, toks, t, ids, seen) {
  SB_OPEN = 0
  if (!range_added(SB_LINE, NR)) return
  text = SB_TEXT
  call = text; sub(/[ \t]*[({].*/, "", call); sub(/^[^A-Za-z_.]+/, "", call); sub(/^\./, "", call)
  p = index(text, "("); if (p == 0) p = index(text, "{")
  args = substr(text, p + 1)
  if (SB_KIND != "exc") {
    done = 0
    nv = split(SB_SCOPE, vars, " ")
    for (i = 1; i <= nv && !done; i++)
      if (vars[i] != "" && has_word(args, vars[i])) { hit("R1", SB_LINE, "caught " vars[i] " reaches sink " call "(...)"); done = 1 }
    if (!done && call ~ /printStackTrace/) { hit("R1", SB_LINE, "stack trace printed to stderr"); done = 1 }
    if (!done && LANG == "py" && SB_SCOPE ~ /[^ ]/ && call ~ /\.exception$/) hit("R1", SB_LINE, "active exception logged via " call "(...)")
  }
  ids = ""
  n = split(args, toks, /[^A-Za-z0-9_]+/)
  for (i = 1; i <= n; i++) {
    t = toks[i]
    if (idshape(t) && !(t in seen)) { seen[t] = 1; ids = ids (ids == "" ? "" : ", ") t }
  }
  if (ids != "") hit("R4", SB_LINE, "identifier-shaped argument(s) in sink " call "(...): " ids)
}

# ---- input-bearing parses (R3) ----

function parse_scan(code,   kind, start, len, what, pre, recv, rest, a) {
  if (!(NR in ADDED)) return
  kind = 0
  if (match(code, PARSE_DOT)) kind = 1
  else if (LANG == "py" && match(code, PARSE_PY)) kind = 1
  else if (match(code, PARSE_BARE)) kind = 2
  if (!kind) return
  start = RSTART; len = RLENGTH
  what = substr(code, start, len)
  sub(/[ \t]*\($/, "", what)
  sub(/^[^A-Za-z.]+/, "", what)
  if (kind == 1) {
    pre = substr(code, 1, start - 1); recv = ""
    if (match(pre, /[A-Za-z0-9_]+$/)) recv = substr(pre, RSTART, RLENGTH)
    if (what ~ /valueOf/ && recv ~ /^(String|Boolean|Objects|Arrays|Character|Optional|List|Set|Map|EnumSet|Stream|Collections|Math)$/) return
    what = recv what
  }
  rest = substr(code, start + len)
  a = rest; sub(/\).*/, "", a)
  if (index(rest, ")") && a ~ /^[ \t]*(""|''|[0-9][0-9._]*[lLfFdD]?|true|false)?[ \t]*$/) return
  hit("R3", NR, "input-bearing parse: " what "(...)")
}

BEGIN {
  LANG = lang
  n = split(added, parts, ",")
  for (i = 1; i <= n; i++) {
    if (parts[i] == "") continue
    if (split(parts[i], ab, "-") == 2) { for (j = ab[1] + 0; j <= ab[2] + 0; j++) ADDED[j] = 1 }
    else ADDED[parts[i] + 0] = 1
  }
  SINK_LOG = "(^|[^A-Za-z0-9_])(log|logger|LOG|LOGGER|Log|Logger|_log|_logger|logging|console|Timber|audit|AUDIT|auditLog|securityLog|slog|zap)[ \t]*(\\?)?\\.[ \t]*(trace|debug|info|warn|warning|error|fatal|severe|exception|critical|log|Print|Printf|Println|Fatal|Fatalf|Errorf|Warnf|Infof|Debugf|Errorw|Warnw|Infow|Debugw|Error|Warn|Info|Debug)[ \t]*[({]"
  SINK_STD = "(System\\.(out|err)\\.print[a-z]*[ \t]*\\(|\\.printStackTrace[ \t]*\\(|fmt\\.(Print|Fprint)[a-z]*[ \t]*\\()"
  SINK_EXC = "(new|throw|raise)[ \t]+[A-Z][A-Za-z0-9_]*(Exception|Error)[ \t]*\\("
  PARSE_DOT = "\\.(parse[A-Za-z]*|valueOf|fromString|readValue|readTree|convertValue|fromJson|parseFrom|decode|toInt|toLong|toDouble|toFloat|toBigDecimal|Unmarshal|Atoi|ParseInt|ParseUint|ParseFloat|ParseBool|ParseDuration)[ \t]*\\("
  PARSE_PY = "\\.(loads?|safe_load|literal_eval|fromisoformat|strptime)[ \t]*\\("
  PARSE_BARE = "(^|[^A-Za-z0-9_.])(parseInt|parseFloat|BigInt|URI\\.create|new[ \t]+(BigDecimal|BigInteger|URI|URL))[ \t]*\\("
}

{
  LINES[NR] = $0
  code = strip_code($0)
  if (LANG == "py") { py_line(code); scope = (PY_OPEN ? " " PY_VAR " _" : " ") }
  else scope = brace_scope(code)
  sink_scan(code, scope)
  parse_scan(code)
  if (LANG != "py") brace_line(code)
}

END {
  if (SB_OPEN) sink_eval()
  if (PY_OPEN) { NR_SAVE = NR; py_close() }
}
