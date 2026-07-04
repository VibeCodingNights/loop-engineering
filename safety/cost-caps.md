# Cost Caps

A loop spends money while you sleep. Set a hard cap before you leave, not after you check your dashboard at breakfast.

Event guidance: **$5 is plenty for the evening. $10–20 for an overnight run.** Huntley's three-month loop cost $297. Your eight-hour loop should not cost more than dinner.

## The three layers

| Layer | What | Enforced by | Survives your laptop closing? |
|---|---|---|---|
| Hard | Provider spend limit | The billing system | Yes |
| Soft | [`watchdog.sh`](../verifiers/watchdog.sh) | A process on your machine | No |
| Belt | `MAX_ITERATIONS` in the loop script | Your own bash | No |

Set all three. Only the first one works when everything else is confused. The watchdog kills the loop on spend, runtime, or no-progress; the iteration counter stops a loop that respawns faster than you expected. The provider cap is the one that holds when the other two don't.

## Anthropic (API key)

Console: `console.anthropic.com` (redirects to `platform.claude.com`).

Two mechanisms:

1. **Prepaid credits, auto-reload off.** This is the simplest hard cap. Buy $5 (or $20 for overnight), leave auto-reload disabled. The loop stops when the money does. Nothing to configure.
2. **Spend limit.** Console → Settings → Limits → the *Spend limits* section → set or change the limit. Requests are refused once you cross it. If you use Workspaces, each workspace has its own Limits tab — you can give tonight's loop a workspace with a $10 cap and keep your main key untouched. A workspace limit can be lower than your org limit, never higher.

The Usage page in the same console shows spend close to real time. Check it once before you leave.

## OpenAI (API key)

Platform: `platform.openai.com` → Settings → Limits (organization or per-project). Set a *monthly budget* and an alert threshold below it.

One honest caveat: as of early 2026, multiple reports say the monthly budget behaves as an alert, not a guaranteed hard stop — traffic can keep flowing past it. The reliable cap on OpenAI is the same as on Anthropic: **prepaid credits with auto-recharge turned off.** Do that, and treat the budget setting as your early warning.

## Claude subscription (Pro / Max)

If you authenticate Claude Code with a Pro or Max subscription instead of an API key, there is no dollar cap to set — you have rate limits instead: a 5-hour rolling window plus a **weekly cap**, pooled across Claude Code and claude.ai chat.

Say it plainly: **an overnight loop can eat your week.** The loop doesn't know your weekly cap exists. It will burn through hours of usage while you sleep, and you'll hit the wall on Tuesday with no loop to show for it. The exact hour allowances shift by plan and promotion; the shape doesn't.

If you're running overnight on a subscription:

- Accept that tomorrow's interactive usage is the price, or
- Use an API key for the loop instead — $10–20 prepaid, auto-reload off. The loop stops when the money does, not when your week does.

## Before you leave tonight

1. Provider cap set (credits capped or spend limit configured).
2. Loop wrapped in [`watchdog.sh`](../verifiers/watchdog.sh) if it runs on your machine.
3. `MAX_ITERATIONS` in the loop script.
4. Cap posted in the channel with your loop, so we know what "over budget" means at breakfast.

If it runs away anyway: [kill-switches.md](kill-switches.md).
