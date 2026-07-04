# Kill Switches

Every loop you start tonight needs a way to die. Know yours before you start it, not while it's committing garbage at 2 AM.

## Runaway signs

Pull the switch when you see any of these:

- [ ] The same commit message, over and over
- [ ] Cost ticking up, but `git log` shows nothing new in the last 20 minutes
- [ ] The same error in the output every iteration, same fix attempted every iteration
- [ ] Your verifier has never exited 0 and the loop has no iteration cap
- [ ] Hundreds of malformed tool calls in minutes — the 400-broken-tool-calls failure mode, see [../verifiers/anti-patterns.md](../verifiers/anti-patterns.md)

Ordered from gentle to nuclear:

## 1. Esc — inside Claude Code

`Esc` interrupts the current response or tool call mid-turn. Work done so far is kept; you get the prompt back and can redirect. `Ctrl+C` also interrupts; a second press exits Claude Code entirely. If a `/loop` is driving the session, interrupt it the same way, then tell it to stop.

`Ctrl+X Ctrl+K` (press twice within 3 seconds) stops all background subagents running in the session. `/tasks` shows what's running.

## 2. Ctrl-C — the foreground bash loop

A Ralph loop running in your terminal dies with `Ctrl+C`. The signal hits the whole foreground job — the `while true` and the `claude -p` inside it. If an iteration is mid-flight and the loop respawns, press it again.

## 3. Kill a background or tmux loop

Find it first:

```bash
pgrep -fl claude          # list matching processes with their PIDs
```

Kill headless loops:

```bash
pkill -f 'claude -p'      # kills every claude running in print mode — all of them
```

If it lives in tmux:

```bash
tmux ls                        # find the session name
tmux kill-session -t <name>    # kill it, and everything inside it
```

If the loop keeps respawning children faster than you can kill them, kill the process group, not the process:

```bash
ps -o pgid= -p <PID>      # get the group id
kill -TERM -- -<PGID>     # note the leading minus: the whole group
kill -KILL -- -<PGID>     # if TERM was ignored
```

## 4. Claude Code background agents

Sessions started with `claude --bg` are managed from the agent view:

```bash
claude agents             # open the background session manager; stop sessions from there
claude agents --json      # list active sessions for scripting
```

## 5. Cloud sessions

Sessions running on Anthropic's servers don't care about your terminal. Stop them from the session view at [claude.ai/code](https://claude.ai/code). This works from your phone at breakfast.

## 6. Revoke the API key

The true kill switch. It works when you've lost track of what's running where — tmux on a box you can't reach, a background session you forgot, three worktrees deep.

- **Anthropic:** `console.anthropic.com` → API Keys → disable or delete the key.
- **OpenAI:** `platform.openai.com` → API keys → revoke.

Every in-flight request starts failing. No loop survives it. If you authenticated with a subscription instead of a key, run `/logout` in Claude Code or revoke the session from your claude.ai account settings.

This is why tonight's loop should run on its own key: revoking it kills the loop without killing everything else you own.

## Cleaning up after

The loop is dead. Now look at what it left behind:

```bash
git status                     # uncommitted changes?
git log --oneline -20          # what did it commit?
git stash -u                   # park the uncommitted mess without losing it
git worktree list              # did it leave worktrees behind?
gh pr list --author "@me"      # did it open PRs?
```

Do not `git reset --hard` until you've read the diff. Runaway loops sometimes leave good work in the wreckage — the runaway was the stopping, not necessarily the writing. Close or mark draft any PRs you don't trust yet.

Then fix the reason it ran away — 90% of the time it's a verifier that never returns 0. See [../verifiers/good-vs-bad.md](../verifiers/good-vs-bad.md) before you relaunch.
