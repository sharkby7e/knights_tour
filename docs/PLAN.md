# Context

Two small play-page fixes bundled together: (1) the Restart button is currently always clickable, even before the first move — doesn't make sense to "restart" a game that hasn't started, so it should be disabled at the same time Undo/Save already are (`state.atStart`). (2) A "How to Play" link near the controls opens a modal with brief rules, mirroring the existing Warnsdorff-helper info modal pattern.

# Progress

- [x] 1. Disable Restart at `atStart`, matching Undo/Save
- [x] 2. "How to Play" link + modal

---

## Step 1 — Disable Restart at atStart

Mirrors the existing `prevButtonTarget`/`saveButtonTarget` disabling already in `tour_controller.js`'s `render()`. No new pure-logic behavior (`state.atStart` already exists in `renderState`), so this is a controller-wiring change only — no new spec, consistent with this repo's existing no-coverage-on-Stimulus-controllers posture.

## Step 2 — How to Play link + modal

A small text-link row (styled like the other controls-column rows) opens a third `<dialog>` with plain-language rules, reusing the scroll-lock/unlock pattern already wired for the save and hint dialogs.

# Verification

`node --test` and `bundle exec rspec` green, `bin/rubocop` clean. Hand-tested in the browser (no automated Stimulus-controller coverage, per existing convention).

---

# History

- **Add Warnsdorff's-Rule Helper Toggle** — client-side "Show move counts" toggle on the play page, with an info modal explaining the rule. See PR #28.
- **Restore Undo/Restart/Save Row** — Save moved back to an always-visible row with a real "name your tour" popup; ticker removed to free up space. See PR #27.
- **Hide Save Until Game Over, Redesign as a Pill (superseded)** — gated Save behind game-over as a pill; later reversed by the entry above. See `fa1cf3f` (#25).
- **Consolidate Live-Play and Playback Controls** — live play gained the playback page's transport row, ticker, path-toggle, and real undo/redo scrubbing. See `0ea6d56` (#24).
- **SEO: Meta Tags, Sitemap, and Search Console Verification** — per-page OG/description meta tags, `sitemap.xml`, Google/Bing site-verification files. See `7e97bdc` (#23), `0d5bc77`, `739fdfa`/`2bf0dd6`.
- **Tour Playback UI** — scrubber, transport, click-to-seek ticker, speed toggle, and path-line toggle added to `tours#show`, reused on the live play page. See `963f8fe`.
- **Filter Tours By Completion Status** — responsive 3-column `/tours` grid with `?status=complete`/`incomplete` filter pills. See `85bf5ab`.
- **Enable Saving Tours** — `Move`/`Tour` models, save endpoint, and the read-only `tours#show` playback page. See the initial save-tour commits.
