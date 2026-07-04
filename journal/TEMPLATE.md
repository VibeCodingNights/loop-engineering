# Loop Journal

Copy to `entries/your-name.md`, fill it out, post it in the channel before you leave.

This is the overnight accountability layer. If it's not in a journal, nobody knows to check it at breakfast.

---

## Tonight

**Name:**

**Project:**
<!-- Repo name plus one line on what it is. -->

**Goal (one line):**
<!-- State the exit condition as a checkable fact. "All tests in packages/api pass" is a goal. "Improve the code" is not — the loop never knows when to stop. -->

**Verifier:**
<!-- Paste the actual script or command — not a description of it. It must: exit 0 on pass / non-zero on fail, run in under 30 seconds, need no human judgment, and test the outcome, not the process. Templates in /verifiers/templates/. -->

```bash

```

**Loop pattern:**
<!-- Which one, linked. One of:
     /patterns/01-ralph-loop.sh
     /patterns/02-slash-loop.md
     /patterns/03-slash-goal.md
     /patterns/04-background-agent.md
     /patterns/05-codex-goal.md
     /patterns/06-parallel-agents.md -->

**Cost cap:**
<!-- Dollar amount AND where it's enforced (Anthropic console / OpenAI dashboard / watchdog.sh). $5 covers the evening; $10–20 for overnight. See /safety/cost-caps.md. -->

**Start time:**

**Repo URL:**
<!-- Where the output lands: branch, draft PR, or commit stream we can look at without asking you. -->

**Expected outcome at breakfast:**
<!-- One line. What exists in the morning if this worked. Be specific enough that "did it happen" is a yes/no question. -->

---

## Morning After

Fill this out at breakfast. Post the update in the channel, even if — especially if — the loop failed.

**What shipped:**
<!-- What the loop actually produced. Link the PR, branch, or diff. -->

**Iterations:**
<!-- How many times the loop ran. -->

**Actual cost:**
<!-- Dollars, from your provider dashboard. Compare against your cap. -->

**Did the verifier hold up?**
<!-- The important question. Did it exit 0 only when the work was actually done? If it lied, which way — passed too early, or never passed at all? A verifier that failed overnight is the most useful thing you can post. -->
