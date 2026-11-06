# PR Review Checks

Loaded in Step 8 and passed to every review agent, together with the user's own
`EXTRA_CHECKS` file (if configured) and the Step 7b pre-scan output.

Two layers:

- **Universal obligations (01-05)** bind every agent on every PR. They are about *how*
  a finding is established, not what it is about.
- **Check categories (R1-R4, C1-C6)** say *what* to look for. R1-R4 match the pre-scan's
  hit types: every pre-scan hit is an obligation that must end in the ledger. C1-C6 have
  no pre-scan; agents cover them by reading.

The ownership table at the end assigns each pre-scan hit type to one agent.

---

## Universal obligations

### 01 — Read the whole changed file, from the worktree

Read every changed file in full under `<WORKTREE>/`, not just the hunks. A hunk shows what
changed; the surrounding method, class and callers show whether the change is correct.
Never reconstruct file content from `gh pr diff` or `git show`.

### 02 — Read the implementation, not the call site

Never clear a check from a call site, a method name or a signature. `logger.warn(msg, e)`,
`sanitize(id)` or `@Transactional` tells you what the author *meant*; only the implementation
tells you what happens. Follow the call into the implementation: the project's own code, a
shared library, or the dependency JAR / published sources **for the exact version in the
diff's build file**. A name like `safeLog` or `maskedId` is a claim to verify, not evidence.

When the implementation cannot be reached (closed source, not on disk, version not
published), the obligation is UNVERIFIED, and the ledger names what was missing.

### 03 — Precedent comparison

Every finding class carries at least one comparison with how the same thing is already done
elsewhere in this codebase (file:line). Precedent separates "this PR deviates from house
practice" from "this is how the whole service does it". The two lead to very different
comments. If the precedent is itself wrong, say so: the finding stands, and the comment
notes that the pattern exists elsewhere.

### 04 — Evidence ledger

Every agent returns a ledger alongside its findings: one row per obligation (every assigned
pre-scan hit, plus any check the agent cleared or could not settle).

```
| # | Obligation | Verdict | Evidence (what was read) | Finding |
|---|------------|---------|--------------------------|---------|
| 3 | R1 Svc.java:42 — caught e reaches log.warn | CONFIRMED | Read LogWrapper#warn (common-logging 4.2.1, LogWrapper.java:88): appends e.toString(), which includes the request URL with the token | [1155-2] |
| 4 | R3 Svc.java:57 — Integer.parseInt(raw) | CLEARED | raw is validated by @Pattern("\\d{1,9}") on RequestDto.raw (RequestDto.java:19); controller has @Valid (FooController.java:33) | - |
| 5 | R4 Svc.java:61 — orderId in log.info | UNVERIFIED | Masking config lives in the platform logback appender, not on disk | - |
```

- `#` is the pre-scan hit number (`[k]` from Step 7b), or `-` for an agent's own checks.
- **Evidence** names files, methods, line numbers and versions that were actually read.
  "Looks fine", "standard pattern" and "handled upstream" are not evidence.
- **Finding** is the `[<N>-<n>]` ID when the row led to a finding, else `-`.

### 05 — Verdicts

- **CONFIRMED**: the shape is a real problem. It becomes a finding (or joins one).
- **CLEARED**: not a problem, *and the evidence cell shows why*, per 02. A CLEARED row
  without concrete evidence is downgraded to UNVERIFIED by the Step 8 gate.
- **UNVERIFIED**: could not be settled. The evidence cell states what would settle it.
  These rows become the review file's **Verification gaps** and the first obligations of
  the next round.

A pre-scan hit may never be left out of the ledger, and never dismissed as a "false positive"
without naming what was read.

---

## Check categories covered by the pre-scan

### R1 — Caught exception reaches a logging sink

Shape: inside a catch block (or Go `if err != nil`), the caught exception or error is passed to
a log call, stdout/stderr, or `printStackTrace`.

Read the **sink implementation** (02), then answer:
- What does the sink actually write: message only, `toString()`, full stack trace, causes?
- Can the exception text carry request data, credentials, tokens, SQL, file paths or PII?
  (HTTP client exceptions often include URLs and bodies; validation exceptions include the
  rejected value.)
- Is the level right? Expected client errors at ERROR page people at night; real failures at
  DEBUG disappear.
- Is it logged *and* rethrown, so the same failure is logged twice up the stack?

The ledger row names the sink implementation that was read (class#method, library and
version), not the call site.

### R2 — Empty or swallowing catch

Shape: a catch/except/error branch that is empty, or that does not rethrow, raise, return the
error, or panic.

- What does the caller see afterwards: a default, null, partial state, a success response?
- Is the failure recorded anywhere a person or alert will see it?
- Is swallowing deliberate and documented (best-effort cleanup, `InterruptedException` with
  `Thread.currentThread().interrupt()`, optional enrichment)? Then CLEARED with that reason.
- Does it catch too broadly (`Exception`, `Throwable`, bare `except:`) and hide bugs?

### R3 — Input-bearing parse

Shape: a parse or conversion of a value that may come from outside: `Integer.parseInt`,
`UUID.fromString`, `LocalDate.parse`, `Enum.valueOf`, `objectMapper.readValue`,
`JSON.parse`, `json.loads`, `strconv.Atoi`, `new BigDecimal(...)`, `URI.create`, `toInt()`.

- Trace the argument back to its source. Is it user, partner, queue, file or DB data?
- On bad input, what happens: exception type, HTTP status, retry loop, poison message, 500?
- Is it validated before the parse (bean validation, schema, regex)? Read the validator (02).
- Locale, time zone, overflow and precision: `parseDouble` for money, `LocalDate.parse` with
  an implicit format, `Integer` for IDs that can exceed 2^31.

### R4 — Identifier-shaped argument in a sink call

Shape: an argument named like an identifier or secret (`*Id`, `email`, `token`, `ssn`,
`accountNumber`, `password`...) passed to a log call or into an exception message.

- Is the value personal data, a credential, or an internal ID that policy forbids in logs?
- Does the sink mask it? Read the masking implementation or appender config (02); a field
  name in a "masked fields" list only counts if the value is logged through that path.
- Exception messages travel further than logs: into API error bodies, alerts and tickets.

---

## Check categories without a pre-scan

- **C1 — Contract and compatibility.** API, event and schema changes: removed or renamed
  fields, changed types or defaults, new required fields, enum values consumers don't know.
  Who consumes this, and are they deployed in lockstep?
- **C2 — Data and transactions.** Transaction boundaries, partial writes, idempotency of
  retried operations, migrations that lock or rewrite large tables, missing indexes for new
  queries.
- **C3 — Concurrency and state.** Shared mutable state, caches without invalidation,
  check-then-act races, thread-pool or connection-pool exhaustion, timeouts and retries
  without backoff.
- **C4 — Security.** Authorization on new endpoints and new code paths (not just
  authentication), injection (SQL, log, header, path), secrets in code or config, unsafe
  deserialization.
- **C5 — Tests.** Do the tests exercise the changed behaviour, including the failure path
  each R2/R3 hit implies? A test that mocks the code under review proves nothing.
- **C6 — Operability.** Feature flags and their default, config added to every environment,
  metrics and logs that will let someone debug this at 3am, rollback safety.

---

## Ownership table

Each pre-scan hit type has exactly one owning agent from `pr-review-toolkit:review-pr`. The
owner must resolve every hit of that type in its ledger. Other agents may comment, but do
not own.

| Hit type | Owning agent | Why this agent |
|----------|--------------|----------------|
| R1 — caught exception reaches a logging sink | `silent-failure-hunter` | error-path behaviour; must read the sink |
| R2 — empty or swallowing catch | `silent-failure-hunter` | error-path behaviour |
| R3 — input-bearing parse | `code-reviewer` | input handling and validation |
| R4 — identifier-shaped argument in a sink call | `code-reviewer` | data exposure in logs and messages |
| C5 — tests for every R2/R3 failure path | `pr-test-analyzer` | test coverage |
