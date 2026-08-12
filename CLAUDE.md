# Working on this repo

## Plan doc: `docs/PLAN.md`

This repo tracks work as a living, version-controlled plan in `docs/PLAN.md` — not scratch notes, not something that only lives in a chat transcript. Read it first when picking up work here, especially at the start of a session.

- **Starting a new branch for a new chunk of work**: overwrite `docs/PLAN.md` so the new branch's plan (a fresh `Progress` checklist + full per-step detail) becomes the primary content at the top of the file. Fold the just-finished plan down into a condensed "complete, kept for history" section below it (title, context, a short summary per step — not the original full prose). Do this as soon as the new plan is agreed with the user, in-branch, not deferred to later cleanup.
- **While working a plan**: update the `Progress` checklist and the relevant step's detail as part of the normal commit flow for the work it describes — not a separate bookkeeping step done afterward. It's correct for the doc on a feature branch to be ahead of `main` while the branch is in flight.
- **Multi-session continuity is the point**: because the plan and its progress are committed to git, work should be resumable from `docs/PLAN.md` + `git log` alone, even if a session's context is cleared or a fresh session picks up the branch later. If you're resuming work here, read `docs/PLAN.md` before assuming you need to ask the user what's next.

## TDD, step by step

Work through a plan's steps one at a time, each following the same cadence:

1. Write the spec(s) for the step first.
2. Run them and confirm they fail for the right reason (red) — don't skip straight to green, actually show the failure.
3. Implement the minimum code to make them pass.
4. Run again and confirm green.
5. Check off that step's box in `docs/PLAN.md`.
6. Report a short status — what's green, what's still expected to be broken because later steps haven't landed yet — and stop there.

Don't batch multiple plan steps together or race to finish the whole plan in one turn. Small, verified, checkpointed steps are the goal, not speed — they're what make it safe to clear context and resume later. Commit boundaries are usually one step (or a small, explicitly-agreed group of steps), not the whole plan at once.
