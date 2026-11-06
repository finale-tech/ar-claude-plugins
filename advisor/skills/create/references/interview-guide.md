# Interview Guide — Domain Builder

*This guide defines how to conduct the create interview. Ask questions one at a time. Adapt based on answers.*

---

## Interview Phases

### Phase 1: The Goal (2-3 questions)

Start here. Understand what they want to achieve.

- "What's the goal you want to work toward? Describe it in your own words."
- "What does success look like? How would you know you've achieved it?"
- "What's the timeline? Is there a hard deadline, or is this open-ended?"

**What you're listening for:** Clarity of goal, measurability, urgency. If the goal is vague, probe: "Can you make that more specific? What would be different in your life or work if you achieved this?"

### Phase 2: Current Situation (2-3 questions)

Where are they starting from?

- "Where are you right now relative to that goal? What's the gap?"
- "What have you already tried? What worked and what didn't?"
- "What resources, relationships, or advantages do you have going in?"

**What you're listening for:** Self-awareness, past failure patterns, existing assets. If they mention past failures, dig in: "What specifically went wrong? Was it the approach, the execution, or something else?"

### Phase 3: Behavioral Patterns (3-4 questions)

This is the most important phase. Diagnose their avoidance patterns and tendencies.

- "When you think about this goal, what feels hardest? Not the skills — the behaviors."
- "When you've failed at similar things before, what did the failure look like day-to-day? What did you do instead of the hard thing?"
- "What do you tend to do when you feel behind or overwhelmed?" (Listen for: shame spirals, heads-down avoidance, over-preparation, switching to comfortable tasks)
- "How do you handle criticism or negative feedback related to this domain?"

**What you're listening for:** Avoidance mechanisms, emotional triggers, procrastination patterns. Don't ask "what are your avoidance patterns" — most people can't articulate them. Instead, listen for behavioral signals:

- "I tend to research a lot before starting" → Preparation as procrastination
- "I go quiet when I'm struggling" → Shame spiral / accountability avoidance
- "I document everything thoroughly" → Documentation as avoidance of doing
- "I make sure everything is perfect before showing anyone" → Perfectionism as avoidance of feedback
- "I get stuck deciding the best approach" → Analysis paralysis
- "I focus on the easy stuff first" → Comfort-zone gravitational pull

### Phase 4: Key Relationships (1-2 questions)

Who matters for this goal?

- "Who are the key people who influence your success in this domain? (Mentors, managers, peers, accountability partners)"
- "Are there relationships you need to build or strengthen?"

### Phase 5: Communication & Interaction (1-2 questions)

How do they interact in this domain?

- "When you communicate in this domain (meetings, messages, presentations), what tends to go wrong? What feedback have you received?"
- "Are there specific situations where you consistently react in ways you later regret?"

### Phase 6: Cross-Domain (1 question)

- "Do you have other advisor domains set up? If so, where are they? (I'll link them so advisors can read each other's context.)"

### Phase 7: Commitment Prefix (1 question)

- "For tracking commitments, I'll use a short prefix (like W for work, P for a side project). What letter or short prefix fits this domain?"

---

## Generating Files

After the interview:

1. **Read all templates** from `${CLAUDE_SKILL_DIR}/references/`
2. **Generate personalized versions** — don't copy templates verbatim. Fill them with actual content from the interview:
   - `playbook.md`: Real goals, real timeline, real gap analysis, real recalibration signals
   - `daily-ops.md`: Real tendencies, real trigger/instinct/response scenarios, real habits
   - `patterns.md`: 4-6 diagnosed patterns with specific detection heuristics tailored to their answers
   - `instincts.md`: Start with the universal meta-filter + 1-2 domain-specific instincts from the interview
   - `advisor/commitments.md`: Seed with 2-3 first-week commitments from the playbook
   - `advisor/session-log.md`: Initialization entry summarizing the interview
   - `advisor/status.md`: Initial snapshot with cross-domain paths if provided
   - `weekly-impact-log.md`: Empty template with domain-appropriate section headers
3. **Show summary** to the user: list all files created, key patterns identified, first commitments
4. **Ask for review**: "Take a look at the generated files. Anything you'd change before we start?"

## Pattern Generation

When writing `patterns.md`, each pattern needs:

```markdown
## [N]. [Pattern Name]

**What it looks like:** [Observable behavior — what an advisor would notice in session logs]

**The tell:** [The specific signal that this pattern is active]

**Why it's dangerous:** [How this pattern undermines the goal]

**The counter:** [What to do instead when this pattern is detected]

**Detection questions for the advisor:**
- [Question the PM/retro skill should ask to check for this pattern]
- [Another detection question]
```
