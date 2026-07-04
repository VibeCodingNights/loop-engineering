# Pre-Event Checklist — Day Of

Everything here is done before doors at 6:00 PM. Budget an hour; the preflight and scaffold tests are the only items that can surprise you.

## Infrastructure

- [ ] Clone and push the event repo to `github.com/vibecodingnights/loop-engineering` — verify the public URL loads in an incognito window
- [ ] Test `preflight.sh` on macOS **and** Linux — it must run clean in under 60 seconds on both
- [ ] Verify the Ralph Wiggum plugin installs cleanly: `claude plugin install ralph-loop` — the id in the default official marketplace is `ralph-loop`, not `ralph-wiggum` (`claude plugins` is an alias of `claude plugin` — both work)
- [ ] Verify `/goal` works on your own machine: `claude --version` must be ≥ 1.0.34. Current stable is 2.1.x, so any recent install passes — the floor exists to catch ancient installs
- [ ] Verify the task-hypergraph scaffold works: `bash hypergraph/scripts/scaffold.sh --project test --mode tmpdir`
- [ ] Pre-stage `verifiers/templates/` — every script in it must be working and copy-paste-ready; run each one once
- [ ] Post Wi-Fi credentials and the repo URL on a wall-mounted screen or whiteboard — visible from every seat
- [ ] Set up the shared channel (Discord thread or Telegram group) for the night — loop journals get posted here tonight, overnight results get posted here at breakfast. Have `breakfast-prompt.md` queued for the morning

## Demo prep

- [ ] Pick a real repo for the intro demo (one with actual Express handlers in `src/routes/`, or adjust the demo command in `intro-script.md` to match what you have)
- [ ] Put the `/goal` demo command in a scratch file, ready to paste — see `intro-script.md`
- [ ] Test screen mirroring; terminal font readable from the back row

## Attendee email (send 24h before, via email/Discord)

Must tell them to bring:

- A laptop with Claude Code installed (`claude --version` ≥ 1.0.34) **or** the OpenAI Codex CLI
- An active API key with spending enabled (Anthropic or OpenAI) — minimum $5 credit recommended for the evening; $20+ if running overnight
- A project they want to make progress on — their own repo, a side project, an open-source contribution, anything with a codebase
- Git configured (`git config user.name` / `user.email` set)

Mention that attendees without a project are covered: the repo includes `no-project.md` with pre-selected issues that have mechanically verifiable outcomes.

## Table cards (print, one per table)

Exact text:

```
1. Connect to Wi-Fi: [network] / [password]
2. git clone https://github.com/vibecodingnights/loop-engineering.git
3. cd loop-engineering && bash preflight.sh
4. Open README.md — pick your entry point
```

Fill in the Wi-Fi network and password before printing.
