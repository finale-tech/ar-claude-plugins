# Career Playbook

*The general plan from Senior to Staff. Your own `playbook.md` holds your context: what you know so far and your relationship map.*

### What Differentiates Senior from Staff
This is the gap to close visibly:


| Dimension | Senior |  Staff |
| ----------|-------- | ------ |
| Scope |  Executes within a team |  Drives impact across teams |
| Design  | Implements designs | Authors designs others implement |
| Ambiguity  | Works on well-scoped tickets | Defines the tickets from ambiguous problems |
| Influence | Respected by teammates | Sought out by people outside the team |
| Communication | Updates manager | Aligns stakeholders, writes proposals |
| Ownership | Owns a feature or service | Owns a domain or system boundary |
| Mentoring | Helps when asked | Actively elevates others' output |
| Technical judgment | Makes good decisions | Makes decisions others trust without review |

Everything in this playbook maps to closing that gap.

---

## Week-by-Week Execution Plan

### Communication with Your Manager

| When | What | Channel |
|------|------|---------|
|Week 1 | Orientation, 30-day expectations, communication preferences | In-person |
|Weekly | 1:1 (established by Week 2) | In-person |
|Daily  | Standup — 3 sentences | Team standup |
| As needed | If blocked: "Waiting on X — should I do Y in the meantime?" | Slack, keep it short |
| Week 1 only | End-of-day brief progress updates | Slack |
| Week 4 | "How do you feel things are going? Where should I focus next?" | 1:1 |
| Week 8 | Share thinking on technical risks/priorities for next quarter | 1:1 |
|Week 12 | Share growth goals: "I'd like to grow toward a Staff-level role — what would that take here?" | 1:1 |

### Week 1 (Days 1–7): Set up

**Theme:** Listen more than you talk. Earn the right to have opinions. Get the machine working.

**Top 3**

1. Get the dev environment fully working: IDE, repo access, builds, tests passing locally, the app running with a health check.
   *Done looks like:* you can build, run and test from a clean checkout, and every step the docs missed is written down. That list is your first doc PR.
2. Meet every team member, and have the first 1:1 with your own answers ready.
   *Done looks like:* you have used each teammate's name at least twice. Your manager has heard how you like feedback and your 3-month and 1-year goals. You have written down, in their exact words, what success looks like at 30 days, their preferred communication style, which area of the code to start in, and who to lean on for context.
3. Take the team's onboarding sequence seriously: tools, training, shadowing a peer, the must-read docs.
   *Done looks like:* the sequence is done or scheduled, you have requested a 15–20 minute architecture walkthrough from the senior IC your manager points you to, and you can name the core services and how they connect.

**Optional:** read every architecture doc, wiki page and README you can find; read recent PRs for coding standards and review culture; identify the senior ICs, the informal leaders and who owns which areas; go to every team lunch and social moment.

**Manager touchpoints:** arrival orientation, mid-week check-in if natural, end-of-week brief update on progress.

**Checkpoint:** Environment works end to end. Every team member knows your name. Your manager's 30-day answer is written down. Your manager hasn't had to chase you for anything.

---

### Weeks 2–4 (Days 8–30): Learn, then deliver

**Theme:** Understand the system before changing it, then prove the pipeline works for you. Ship consistently once it does. Start having opinions, framed as questions.

**Top 4**

1. Read the team's must-read architecture docs and trace one request end to end while pairing with a teammate.
   *Done looks like:* a list of about ten lines, one per hop (what runs there, which repo, who owns it), that you could redraw from memory. At each layer note the patterns and naming, and map code modules to product features.
2. Run listening 1:1s with teammates, the PM, support and one adjacent team, and write each up within the hour.
   *Done looks like:* eight to twelve five-line notes: who and when, what they would change, what they would keep, what surprised you, who to talk to next. Ask long-tenured people why the major architecture decisions were made.
3. Ship your first PR through the normal review and deploy path, then keep a rhythm.
   *Done looks like:* one merged change that reached production, a doc fix or a small bug. Address review feedback quickly and gracefully: "Good catch, updated." Never defend; learn. Then one ticket in review and one in progress, with the next ticket aligned to "What's the most important thing for the team this sprint?"
4. Around Day 30, play back one or two themes you heard to your manager and the team, and write a private 30-day retrospective.
   *Done looks like:* a theme is a pattern several people raised, phrased about the future, not a complaint about the past. A short message or five minutes in a team meeting: "Here's what I heard in my first month. Did I get that right?" The retrospective covers what you shipped, what you learned, where to improve, and the team's biggest challenge ahead.

**Technical, as capacity allows**
- Read recent PRs to learn the coding standards, test patterns and review culture. Start reviewing others' PRs with substantive comments: edge cases, test suggestions, readability. Not just "LGTM".
- Before coding anything non-trivial, post a brief approach: "Here's how I'm thinking about [ticket]. Does this make sense, or am I missing context?" This shows architectural thinking before you have authority.
- Learn the production environment: dashboards, alerts, runbooks, deploy and rollback. Shadow on-call or read recent incident reports.
- Find two or three design docs the team has written. They become your template for Days 31–60.
- Share what you learn: short TIL posts, wiki fixes, doc PRs for every gap you hit during setup.
- Write down the tech debt you notice. It is raw material for Days 31–60, not this month's work.

**Relationship**
- Weekly 1:1 with your manager, established by Week 2. Midpoint: "How am I tracking against your expectations?" If the answer includes adjustments, adjust immediately and visibly.
- Join design discussions as a listener; contribute as questions ("Have we considered X?"), not positions ("We should do Z").
- Help a stuck junior by pointing the way; don't take over. Pair when asked; don't force mentoring.
- Month-end 1:1: "It's been a month. How do you feel things are going? Where should I focus next?"

**Checkpoint:** First PR merged and a steady rhythm since. The ten-line map and the 1:1 notes exist. Active in reviews and design discussions. Positive midpoint feedback. At least one teammate has come to you for help. Your manager has heard the Day 30 playback, and the 30-day retrospective is written.

---

### Weekly Reflection Protocol

Every Friday, spend 15 minutes answering these four questions. Write the answers in a private note — not from memory, not in your head. The written record is the point.

**1. What did I ship or move forward this week?**
List concrete outputs: PRs merged, reviews given, docs written, conversations that unblocked work. If the list is short, ask why — were you blocked, or were you busy without being productive?

**2. What signals did I receive?**
Feedback from your manager, PR review comments, how teammates interacted with you, whether anyone sought your opinion. Note both explicit signals ("great catch on that PR") and absence of expected signals ("nobody tagged me in the design discussion"). Don't interpret — just record.

**3. What would I do differently?**
One specific behavior or decision, not a vague aspiration. "I should have posted my approach in Slack before coding the auth refactor" — not "I should communicate more." If the answer is "nothing" for three consecutive weeks, you're either perfect or not being honest.

**4. What is my single most important priority for Monday?**
Not a list. One thing. The thing that, if it's the only thing you accomplish Monday, still makes it a productive day. Write it down. Start Monday by doing it.

**Recalibration Signals — check monthly:**

These help you distinguish "on track" from "drifting" without waiting for formal feedback.

| Signal | Ahead of Schedule | On Track | Behind — Adjust |
|--------|-------------------|----------|-----------------|
| Work assignment | Your manager gives you ambiguous/hard problems unprompted | You pick appropriately scoped tickets | Still getting assigned basic tickets |
| PR feedback | Reviewers approve with minimal comments | Normal back-and-forth, no repeated issues | Same feedback patterns recurring |
| Team interaction | People outside your team know your name | Teammates seek your opinion | You're still mostly asking, rarely asked |
| Design involvement | Invited to design discussions | Aware of design decisions being made | Learning about decisions after the fact |
| Manager's behavior | Defers technical questions to you | Regular productive 1:1s | 1:1s feel like status updates, not strategy |

---

### Days 31–60: Contribute

**Theme:** Own something end to end. Shift from executing tasks to shaping technical direction. Find the pain nobody owns.

**Top 3**

1. Own one meaningful unit of work, neither the hardest nor the easiest.
   *Done looks like:* roughly two to four weeks of work that touches more than one part of the system and reaches users. You wrote the short plan, did most of the code, drove review and rollout, and posted the result to the team. Ask your manager: "What's a medium-sized piece of work I could own end to end?"
2. Between Days 30 and 45, write a one-page problem-space doc from your listening notes and share it with your manager.
   *Done looks like:* four headings: what I heard (three to five recurring themes), what I think it means (labelled as a hypothesis), what I don't understand yet, where I could help. Share it as a draft and ask "What did I get wrong?"
3. Run one time-boxed experiment on a theme you heard, with the success metric agreed up front.
   *Done looks like:* a five-line proposal to your manager first (the theme, what you'll try, for how long, the one metric, how to undo it), then the result written down, including if it failed. No permanent change yet.

**Technical, as capacity allows**
- Start with the tech debt you noted in your first month: pick one small, visible item (flaky tests, inconsistent error handling, missing logging, outdated dependency). Get permission: "I noticed [X] while reading the code — would it be useful if I cleaned that up?" Ship the fix. Unsolicited improvement creates a disproportionate impression, and by now you know which pain is real.
- Stretch: write a short design doc or tech proposal for a systemic issue (a pattern of problems, an architectural gap, a missing abstraction): problem, options, recommendation, trade-offs, rollout, one to three pages. Share with your manager first. Anyone can close tickets; Staff engineers define what the tickets should be.
- Split big work into the smallest viable parts; turn one-way doors into reversible steps (a feature flag, not a data-format change).
- Join the on-call rotation if there is one. After an incident, contribute to the postmortem with systemic fixes, not patches. Own the monitoring and alerting for your area.

**Relationship**
- Around Day 45, sort your stakeholders into invest / load-bearing / background and set a 1:1 frequency for each.
- Ask your manager how they see you against your current level and which growth areas they notice. Ask how promotions work here and for the written level expectations.
- Mentor naturally: pair on a junior's PR, review to teach. Don't force it.
- When your work depends on another team, schedule fifteen minutes with them rather than filing a ticket. Understand their constraints; propose what works for both sides.

**Checkpoint:** The unit of work shipped and announced. The problem-space doc shared and corrected. One experiment run with a written result. One tech-debt fix merged. Your manager starts deferring technical questions in your area to you.

---

### Days 61–90: Lead

**Theme:** Turn experiments into decisions. Make your Staff-level impact visible.

**Top 3**

1. Draft a year-one plan with three to five commitments and a "not doing" list, and review it with your manager and skip-level.
   *Done looks like:* one page. For each commitment, one line on why it matters and one on how you'll know it worked. Then the not-doing list: things people asked for, each with one line on why not now. The not-doing list is the strongest Day 90 signal, because it shows judgment.
2. Take your first cross-team commitment or on-call rotation.
   *Done looks like:* another team relies on something with your name on it, and you deliver it. Ask your manager which would be most useful.
3. On Day 90, send a written retrospective to your manager and skip-level.
   *Done looks like:* one page: what I got right, what I got wrong, what I'd change, and a short "next 90 days" paragraph pointing at the year-one plan. Build it from your timeline and 1:1 notes so it takes an hour, not a weekend.

**As capacity allows**
- Sort experiment results into themes addressed, metric results, surprises and open questions. For each change you keep, write up what / who / when / why / trade-offs / what you'll keep measuring. A failed experiment is still data.
- Now, not before, put bigger ideas forward with evidence: pros and cons, migration cost, the cost of running two systems at once. Prefer a time-boxed trial and incremental migration over a rewrite.
- Propose the next quarter's technical priorities for your area. If a major initiative is starting, volunteer to lead its technical design. Mentor consistently; the multiplier effect is how Staff engineers justify their level.
- In a 1:1: "I've been thinking about where the biggest technical risks are for us next quarter. Can I share my thoughts?" This opens the door to being seen as a technical leader, not just a strong IC.
- Keep the private impact log current: PRs, incidents, tech debt removed, docs, people mentored, cross-team work. It becomes the promotion packet.

**Checkpoint:** Year-one plan reviewed with manager and skip-level. One cross-team commitment delivered. The Day 90 retrospective sent. Viewed as the technical authority for your area, and people outside the team know your name and work.
