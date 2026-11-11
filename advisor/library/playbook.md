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

### Week 1: Absorb

**Theme:** Listen more than you talk. Earn the right to have opinions.

**Technical:**
- Get dev environment fully functional (IDE, repo access, builds, tests passing locally)
- Trace one full request end-to-end through the primary service — from API entry to database/downstream
- Read 10+ recent PRs to learn coding standards, test patterns, review culture, and what's actively changing
- Read every architecture doc, wiki page, and README you can find
- Map the system: core services, how they connect, dependencies (databases, queues, external APIs)
- Get first ticket assigned by mid-week; submit first PR by end of week
- First PR must be: small, well-scoped, well-tested, follows existing conventions exactly — self-review before submitting

**Relationship:**

- Meet every team member by name. Use their name at least twice in conversation.
- Ask your manager: "What does success look like for me in the first 30 days?" — write down their exact words
- Ask your manager: preferred communication style, in-office days, which area of codebase to focus on first, who to lean on for context
- Identify who the senior ICs are, who the informal leaders are, who owns which areas
- Request 15–20 min architecture walkthrough from the senior IC your manager points you to
- Go to every team lunch. No exceptions.

**Manager touchpoints:** Arrival orientation, mid-week check-in if natural, end-of-week brief Slack update on progress.
**Checkpoint:** Can explain the system architecture without notes. 1 PR submitted. Every team member knows your name. Your manager hasn't had to chase you for anything. Identified the team's biggest pain point or tech debt area.

---

### Week 2: Contribute

**Theme:** Ship consistently. Build review credibility. Find the pain nobody owns.

**Technical:**
- Address first PR feedback quickly and gracefully. "Good catch, updated." Never defend — learn.
- Pick up second and third tickets. Establish rhythm: one in review, one in progress.
- Start reviewing other people's PRs. Leave substantive comments — edge cases, test suggestions, readability. Not just "LGTM."
- Identify one small, visible tech debt item (flaky tests, inconsistent error handling, missing logging, outdated dependency)
- Get permission to fix it: "I noticed [X] while reading the code — would it be useful if I cleaned that up?"
- Ship the fix. Unsolicited improvement creates disproportionate impression.

**Relationship:**
- Establish regular 1:1 with your manager if not already set: "Would it be useful to do a weekly 1:1? Even 15 minutes."
- In 1:1, ask: "Any feedback on how the first week went? Anything you'd like me to adjust?"
- Ask: "What's the most important thing for the team to deliver this sprint?" Align your next ticket to that answer.
- Continue joining all team lunches and social moments.

**Checkpoint:** 3–4 PRs merged. 2+ meaningful code reviews given. 1:1 cadence established with your manager. One unsolicited tech debt improvement shipped. Teammates starting to tag you in discussions or ask your opinion.

### Week 3: Accelerate

**Theme:** Take harder work. Start having opinions. Become a go-to person.

**Technical:**
- Volunteer for a complex ticket: multi-service, design decision required, or performance work
- Before coding complex work, write a brief approach (Slack or doc): "Here's how I'm thinking about [ticket]. Does this approach make sense, or am I missing context?" — this shows architectural thinking
- Share knowledge naturally: Slack TILs ("TIL: [thing about the system]. Documenting in [wiki page] in case it helps"), wiki updates, doc improvements
- Start learning the production environment: dashboards, alerts, runbooks, deploy process, rollback procedures
- Shadow on-call or review recent incident reports
- **Find 2–3 design docs the team has written.** Study their format, depth, and structure. These become your template for Weeks 5–8 when you'll author your own. Ask the senior IC or your manager: "Is there a good example of a design doc or technical proposal from the team I could look at?"

**Relationship:**
- Midpoint 1:1 with your manager: "We're about halfway through the first month. How am I tracking against your expectations?"
- If feedback is positive: "What would you like to see me take on next — is there an area where you need more senior ownership?"
- If feedback includes adjustments: "That's helpful — I'll adjust." Then adjust immediately and visibly.
- If a junior engineer is stuck on something, help by pointing them in the right direction — don't take over
- Begin participating in design discussions. Frame contributions as questions: "Have we considered X?" rather than "We should do Z."

**Checkpoint:** 6–8 PRs merged including at least one complex ticket. Active in design discussions and reviews. Contributed to documentation. Positive midpoint feedback from your manager. At least one teammate has come to you for help. Understand production and monitoring.

---

### Week 4: Own

**Theme:** Act like an owner. Make yourself hard to replace.

**Technical:**
- Take clear ownership of the area where you've done the most work. Proactively improve it: better error handling, logging, test coverage, documentation.
- When questions come up about that area in standup or Slack, answer them. This is how informal ownership forms.
- Propose a small forward-looking initiative: CI improvement, integration tests for a critical path, runbook for a common failure mode, module refactor. Frame to your manager: "I've noticed [problem]. I think we could address it with [approach]. It would take about [time]. Worth doing?"
- If work touches another team's service, engage directly with them. Build cross-team rapport.

**Relationship:**
- Mentor naturally: offer to pair with juniors on their PRs ("Want to walk through this together?"), share learnings at standup
- Don't force mentoring — it should feel organic. Be generous with time and knowledge.
- Month-end 1:1 with your manager: "It's been a month. How do you feel things are going? Where should I focus next?"
- Write private 30-day retrospective: what you shipped, what you learned, where to improve, team's biggest challenge ahead.

**Checkpoint:** 10+ PRs merged across varying complexity. Informal ownership of at least one service or area. Trusted code reviewer. At least one unsolicited initiative proposed/shipped. Multiple teammates would advocate for you. Can debug production incidents.

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

### Weeks 5–8: Establish Staff-Level Behaviors

**Theme:** Shift from executing tasks to shaping technical direction.

**Technical — start operating at the system level:**
- Identify a systemic issue (not just a bug — a pattern of problems, an architectural gap, a scalability bottleneck, a missing abstraction)
- Write a short design doc or tech proposal: problem statement, options considered, recommended approach, tradeoffs, rollout plan. 1–3 pages max. Share with your manager first, then broader team.
- This is the single biggest signal of Staff-level work. Anyone can close tickets. Staff engineers define what the tickets should be.
- Take on work that spans multiple services or requires coordination across components
- Start thinking about: "If this system needs to handle 10x load in 2 years, what breaks first?" Bring these observations to design discussions.
- Volunteer to lead a sprint planning session or backlog grooming if the opportunity arises

**Operational ownership:**
- Join the on-call rotation if there is one. If not, be the person who's always available to help during incidents.
- After an incident, write or contribute to the postmortem. Identify systemic fixes, not just patches.
- Own the monitoring and alerting for your area. Set up dashboards if they don't exist. Tune alerts if they're noisy.

**Cross-team influence:**
- When your work depends on another team, don't just file a ticket — schedule a 15-minute sync. Understand their constraints. Propose solutions that work for both sides.
- If there's a broader engineering meeting, attend. Listen first. Contribute when you have genuine insight.
- If you solved an interesting problem, write a brief internal post or share in an engineering Slack channel. Visibility beyond your immediate team matters for Staff.

**Checkpoint:** At least one design doc or technical proposal authored. Participating in or leading cross-team conversations. Your manager starts deferring technical questions to you. Team treats you as a tech lead on your area. Have a clear opinion on the system's biggest architectural challenges.

---

### Weeks 9–12: Build the Staff Case

**Theme:** Make your Staff-level impact visible.

**Technical — drive outcomes, not just output:**

- By now you should own a meaningful area. The question shifts from "what should I work on?" to "what should the team work on in my area?"
- Propose the next quarter's technical priorities for your area. Not waiting for your manager to assign — proactively defining what matters.
- If there's a major initiative or project starting, volunteer to lead the technical design. This is Staff-level scope.
- Mentor consistently: pair programming, PR reviews that teach, helping juniors break down complex tickets. The multiplier effect is how Staff engineers justify their level.

**Make the invisible visible:**

- In 1:1 with your manager: "I've been thinking about where the biggest technical risks are for us next quarter. Can I share my thoughts?" This opens the door for your manager to see you as a technical leader, not just a strong IC.
- Keep a private log of impact: PRs merged, incidents resolved, tech debt eliminated, docs written, people mentored, cross-team collaborations. This becomes your promotion packet.

**Checkpoint:** Viewed as the technical authority for your area. Have authored at least one initiative that shaped the team's roadmap. Your manager has proactively discussed your future (or you have clear evidence they would advocate for you). Multiple people outside your immediate team know your name and work. Have a private impact log ready if a promotion conversation happens.
