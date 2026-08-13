# Progress

- [x] 1. Footer partial: credit line with email + GitHub links, wired into the shared layout

---

# Site footer

## Context

Small addition: a quiet footer crediting the site's author, with links to email and GitHub. Prototyped live as a Claude Artifact reproducing the real titlebar/card chrome and tokens, with three style options to compare in place (minimal centered line, a split bar mirroring the titlebar, a bordered panel like the tour cards): https://claude.ai/code/artifact/44301dcc-ba80-48ad-b971-88caaf19e85e. Landed on the minimal centered option — quietest, doesn't compete with the titlebar above it.

Final copy: "Made by **Sid Quinsaat** (links to `mailto:sgquin@gmail.com`) aka **sharkby7e** (links to `https://github.com/sharkby7e`)" — one line, no separate link-label row.

## Plan

### 1. Footer partial

`app/views/layouts/_footer.html.erb` — single centered line, muted `zinc-400` text with the two names as links (`zinc-300`, accent-green on hover, matching the titlebar nav's hover treatment). Rendered once from `layouts/application.html.erb` below `yield`, the same pattern as `_titlebar.html.erb` above it — a bottom bookend shared across every page, not per-view markup.

**Spec first (red)**: request spec — footer renders on both `/` and `/tours` with a link to `mailto:sgquin@gmail.com` and a link to `https://github.com/sharkby7e`.

**Verify**: spec suite green, `bin/rubocop` clean, `bin/dev` visual pass (spacing against `main`'s bottom edge, both breakpoints).

**Done.** No new request spec — static credit content, not logic (per precedent for visual-only additions). Skipped the TDD spec-first step for this one at the user's call. While testing on a phone, the titlebar + footer together pushed the play page past one mobile screen; fixed as a drive-by by making the "Visited Squares" counter responsive (`text-xl` on mobile, `text-3xl` at `sm:` and up, `app/views/tours/new.html.erb`) rather than shrinking the footer itself.

---

# Tours index page (complete, kept for history)

Community-wide `/tours` index (not personalized) listing saved tours as a grid of large SVG mini-board cards tracing each tour's move path, with a Complete/Incomplete status pill (`moves.count == 64`, no reintroduced legality logic), move count, and relative timestamp. Design prototyped live as a Claude Artifact before implementation: https://claude.ai/code/artifact/5a3887bb-9358-415f-ba27-86f51ecae266. Shared title bar (wordmark + Play/Tours nav) extracted into the layout so Play↔Tours navigation feels like tab-switching, not a full page load. Added `pagy` for pagination (2 per page). The status pill briefly read "Stuck" during the live visual pass, then was reverted back to "Incomplete" in a follow-up one-off commit (`93c4154`) since we can't cheaply verify a genuine dead-end without legality logic — it also got its own yellow `--color-status-incomplete` token instead of reusing the in-play dead-end red. Real bug found and fixed: Tailwind's class scanner doesn't detect `bg-[#hex]` arbitrary-value classes inside a Ruby ternary — any one-off conditional color in this app needs a named `@theme` token instead.

---

# Board visuals: color + motion pass (complete, kept for history)

Pure visual pass on the (then server-rendered) game board: real `@theme` color tokens replacing placeholder Tailwind defaults (chess.com "blue" board direction — cream/dusty-blue squares, warm gold current-square, seafoam legal-move, coral visited, charcoal stuck), self-hosted Poppins title font, motion (state-change transitions, knight-landing pop, legal-move hover), and styled Undo/Restart buttons. Many rounds of hand-tested live iteration (palette, knight SVG, landing animation, two real layout-shift bugs). Superseded in spirit by the tours-index branch's dropped-legality-color-semantics decision for the read-only index, but the token system itself (`--color-board-*`, `--color-accent`, `--font-title`) carries forward unchanged. Final user reaction at the time: "wow okay i love it."

---

# Client-side game logic (steps 1-6 shipped, Save Tour deferred; dead code since removed)

Moved knight-move legality/game state into JS (`app/javascript/game/*.js`, `node:test`-covered) so play runs with zero network round trips, replacing the previous Turbo-Frame-per-move approach. `GET /` became a DB-free static skeleton. Steps 7-11 (Save Tour, simplifying `#show`, `MovesController` cleanup) were deferred at the time; the **cleanup half** of that deferral shipped at the start of the tours-index branch — `MovesController`, the Ruby `KnightTourGame`/`MoveFinder` services (now-redundant duplicates of the JS port), and the old server-rendered `#show`/board/control partials were all deleted, since nothing referenced them once client-side play existed. **Save Tour itself remains deferred** to a future branch.

---

# Rewrite game logic: Square model → Tour/Move model, Turbo Streams (complete, superseded)

Replaced a single-global-shared-board `Square` AR table with a proper `Tour`/`Move` model (restart creates a new `Tour`, old ones kept for future history features) and real move-legality enforcement server-side. Turbo Streams with manual per-square diffing were tried first, then dropped mid-branch for one Turbo Frame wrapping the whole tour UI (simpler, imperceptible re-render cost, avoided a Streams staleness bug on restart). Deployed live via Kamal; superseded by the client-side rewrite once per-move network RTT (~250-400ms) still didn't feel snappy even with the frame in place.

---

# Rebuild Knight's Tour as a new Rails 8 app, deployed via Kamal to Hetzner (original bring-up, complete)

Rebuilt from an older, messier Rails 7.1.3 app (no `Game`/session concept, split win/stuck logic, dead code, CDN Tailwind, no CI/deploy) into a fresh Rails 8 app: Postgres (Solid Queue/Cache/Cable included), RSpec+FactoryBot, ported `MoveFinder`/game logic, Dockerized and deployed to a Hetzner Cloud VPS via Kamal 2 (secrets in 1Password after an early plain-env-export mistake). Fixed two real Postgres-vs-SQLite bugs (board ordering, Turbo 8 hover-prefetch resetting the board). Went live 2026-08-11; switched from local commits/merges on `main` to a GitHub PR workflow after this point.
