# Breakfast Prompt — Morning Channel Message

Post this in the shared channel the morning after. This is the real feedback loop: the event isn't over until the overnight results are in.

## The message

> Loops ran overnight. What shipped? Post: what your loop produced, how many iterations it ran, what it cost, and whether your verifier held up.

## Follow-up prompts for the thread

As replies come in, press with these — one per reply, matched to what they posted:

1. **Did the verifier hold up?** Did it exit 0 only when the work was actually real — or did it pass on something you wouldn't merge? If it lied, which direction: passed too early, or never passed?
2. **What did it cost?** Iterations, dollars from the provider dashboard, and wall-clock time. Post the numbers next to your cost cap from last night's journal.
3. **What would you tighten?** If you ran the same loop again tonight, what's the one check you'd add to the verifier?

## Note for the host

The verifiers that failed overnight are the most interesting data points. A loop that shipped a clean PR confirms what we already believe; a verifier that passed on garbage, or never passed at all, is new information. Collect the failures — cross-reference against the journals in `journal/entries/`, and fold the good ones into `verifiers/anti-patterns.md` for the next event.
