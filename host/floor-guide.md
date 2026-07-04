# Floor Guide — Build Time (6:20–9:30 PM)

You are not presenting. You are triage. Walk the room, watch for stuck faces, and work the decision tree below when someone flags you.

## Conduct rules

- **Float.** Walk the room. Don't stand at the front.
- **Don't interrupt flow.** If someone has headphones on and is typing, leave them alone.
- **Do not make announcements during build time.** No "halfway check-in." No "how's everyone doing." Zero interruptions between 6:20 and 9:15.
- **Near 9:15, do one quiet lap:** "Demos in 15 minutes if you want to show something. No pressure. Also, fill out your loop journal before you leave." Table by table, not from the front.

## The highest-leverage intervention is verifier review

When someone says "my loop is running," ask to see their verifier. If it's `exit 0`, or it uses the model to judge its own output, that's the teaching moment. A verifier must: exit 0 pass / non-zero fail, run in under 30 seconds, require no human judgment, and test the actual outcome, not the process. Most of the value you deliver tonight is catching verifiers that always pass or never pass — send them to `verifiers/anti-patterns.md` and `verifiers/good-vs-bad.md`.

## Triage decision tree

```
"What are you stuck on?"
├── "I don't know what to loop on"
│   → Ask: "What's the most boring task in your project right now?"
│   → Ask: "Is there a failing test suite or a migration you've been putting off?"
│   → If no project: point to no-project.md
│
├── "My loop isn't stopping" / "It keeps going"
│   → Check their verifier. 90% of the time it's a verifier that never returns 0.
│   → Point to safety/kill-switches.md
│   → Check their cost dashboard
│
├── "My loop stopped but the work isn't done"
│   → Check: did the verifier pass prematurely? (Too lenient — tighten it)
│   → Check: did the context window exhaust? (Long session → suggest /goal or background agent)
│   → Check: did the agent give up? (Bad goal framing → rewrite the goal to be more specific)
│
├── "I want to run multiple agents"
│   → Point to patterns/06-parallel-agents.md
│   → Make sure they understand worktree isolation
│   → If ambitious: point to hypergraph/
│
├── "Setup issues"
│   → Run preflight.sh, fix what it flags
│   → API key issues: help them check their dashboard
│   → Claude Code version: must be ≥ 1.0.34 for /goal
│
└── "I finished" (loop is running, verifier works)
    → "Great. Fill out your loop journal. Then pick another task or help someone else."
```

## Most common issues, in order

1. **Bad verifier** — always passes or never passes. See above; this is your main job.
2. **Setup problems** — preflight.sh output tells you what's wrong. Version floor is 1.0.34 (current stable is 2.1.x, so a failure here means an ancient install — reinstall, don't debug).
3. **"I don't know what to work on"** — boring task or dreaded migration, or `no-project.md`.

## 9:30 — Demos

Opt-in, 2–3 minutes each, no slides, screen share only. Prompt the room: *"Anyone want to show what they got running? Doesn't have to be done — 'here's where I got stuck' is a valid demo."*

Per demo, ask:
1. What's the project?
2. What loop pattern did you use?
3. What's your verifier? (This is the interesting part — press on it.)
4. Is it still running? What do you expect to see at breakfast?

Collect loop journals — anyone who hasn't posted theirs to the channel, remind them now. These are what we check at breakfast (see `breakfast-prompt.md`).

Close, 30 seconds: *"Loops are running. Check the channel in the morning. See what shipped. Night."*
