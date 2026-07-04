# Intro Script — 5 Minutes, Hard Stop

Runs 6:15–6:20 PM. The room is already seated and cloning. Do not run long: build time starts at 6:20 and every minute you keep talking is a minute nobody is looping.

## Before you start (set up during arrival, 6:00–6:15)

- Your laptop is mirrored to the main screen. Terminal font large enough to read from the back row.
- A **real repo** is open in Claude Code — a project with actual Express handlers in `src/routes/`, or whatever matches the demo command you're going to run. Not this event repo. Not a toy. The demo lands because the repo is real.
- The `/goal` command below is sitting in a scratch file, ready to paste. Do not type it live.
- The repo URL and Wi-Fi are already on the wall screen. You don't need to read them out.

## Script

**(0:00–0:30) The thesis.**

> "The argument is over. Boris Cherny, the guy who built Claude Code — he doesn't prompt it anymore. His job is to write loops. Huntley left one running for three months on a single prompt and got a compiled programming language. `/loop` and `/goal` are built in. Background agents push draft PRs while you sleep. We write loops now."

**(0:30–1:30) Live demo.**

Your laptop on screen. The real repo open in Claude Code. Paste:

```
/goal "Migrate all API handlers in src/routes/ from Express to Hono. Exit when: `npm run typecheck` passes AND `npm test` passes AND no Express imports remain in src/."
```

Hit enter. The agent starts. **Don't wait for it to finish — that's the point.** Let it run one visible iteration on screen behind you and move on. If it stalls or errors, do not debug on stage — say "it'll be running when we check back" and keep going. Starting it and walking away *is* the demo.

**(1:30–3:00) Point to resources.**

> "The repo is `vibecodingnights/loop-engineering`. Two entry points. If you've never written a loop before, start in `patterns/` — there are six patterns from a one-line bash loop to parallel background agents. Copy-paste the one that fits your project. The hard part is not the loop — it's the verifier. The `verifiers/` directory has templates: test-pass, type-check, coverage threshold, API conformance, custom eval. Copy one, edit the exit condition to fit your project. If you're already running loops, the `hypergraph/` directory has the full task-hypergraph skill for decomposing your project into parallel agent waves."

**(3:00–4:00) The assignment.**

> "You're working on your own project tonight. Pick one task from it. Write the loop. Write the exit condition. Set it running. The goal is to walk out at 10 with something still going. We check what shipped at breakfast. Before you leave, post your loop in the channel — goal, verifier, cost cap, repo URL — so we know what to look for tomorrow."

**(4:00–4:15) Go.**

> "The repo README has everything. Hosts are floating — flag us. Go."

## After

Step away from the front. Leave your demo loop running on the wall screen if the room setup allows — a live loop iterating in the background is better ambiance than a slide. Switch to floor mode: see `floor-guide.md`.
