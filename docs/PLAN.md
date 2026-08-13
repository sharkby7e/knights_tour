# Progress

- [x] 1. Seed a few example tours (complete + incomplete) for local/dev data
- [x] 2. `GET /tours` index route + controller + spec'd list view (status, move count, ordering)
- [ ] 3. Visual pass: title bar + mini-board path-line cards, matching the prototyped design

---

# Tours index page

## Context

Continuing from the dead-code cleanup (see history below): `ToursController#show`/`show.html.erb` are now a bare read-only scaffold with nowhere that links to them, and there's no way to browse saved tours at all. This branch was originally scoped as a fuller "tour show page" (step-through/auto-play/line-view playback for a single tour), but that's been split off — **this branch is index-page-only**. The playback/show screen and the `POST /tours` "Save Tour" endpoint (needed to produce *real* saved-tour data instead of seeds) are both deferred to their own future branches.

The visual/interaction design was prototyped first as a Claude Artifact (iterated live with the user — colors, line thickness, the title bar, community framing, complete/stuck status) before writing this plan: https://claude.ai/code/artifact/5a3887bb-9358-415f-ba27-86f51ecae266. Key decisions carried over from that prototype:

- **Not personalized** — this is a community index (anyone's saved tours), not a per-user "your tours" list. No auth/scoping exists yet anyway.
- **Complete vs incomplete status**: derived purely from `moves.count == 64` — no reintroduced move-legality logic. A tour with fewer than 64 moves is labeled "Incomplete" (not "Stuck" — we can't cheaply verify a genuine dead-end without duplicating knight-move-legality logic, and that distinction doesn't matter yet since there's no in-progress-save feature to produce a merely-abandoned tour anyway).
- **Vertical list**, not a grid — each row: a small board tracing the tour's full path-so-far as a line (thicker, dark green `#4f7a2e`, matching the accent family but darker so it doesn't compete with the "Complete" status pill's use of the same green), tour id, move count, status pill (green "Complete" / amber "Incomplete"), relative timestamp.
- **Title bar**: brand wordmark (no icon — deferred, "we can design a new icon later") + "Play"/"Tours" nav. "Play" should point at `/` (the existing live game) but stays inert for now since only the index is being built this branch.
- Visited-square color semantics from live play (red/green legal-move highlighting) were deliberately dropped for this read-only context — there's no legality signal to show, just history. Board colors reuse the app's real `--color-board-*`/`--color-accent`/`--font-title` tokens throughout, not new ones.

Pagination ("3 per page" or similar) explicitly deferred — out of scope until there's enough real seed/saved data to make it matter.

## Plan

### 1. Seed a few example tours (complete + incomplete)

`db/seeds.rb` hardcodes 5 legal knight paths (3 complete 64-square tours from different starting squares, 2 genuinely dead-ended partial tours from a naive non-Warnsdorff greedy walk, 36 and 42 squares) as literal move arrays — no generator/service added to the app itself, since this is fixture data, not application logic, and "a few" tours don't justify a reusable path-generation abstraction. `Tour.destroy_all` at the top keeps re-running seeds idempotent for local dev.

**Verify**: `bin/rails db:seed`, confirmed via `bin/rails runner` — 5 tours, 3 with 64 moves, 2 with 36/42. No RSpec for this step (fixture data, not logic) — same precedent as prior visual-only steps.

**Done.**

### 2. `GET /tours` index route + controller + spec'd list view

Add `:index` to the existing `resources :tours, only: [ :create, :show ]` → `[ :index, :create, :show ]`. `ToursController#index` loads `Tour.includes(:moves).order(created_at: :desc)` (or `id: :desc`, since seeded `created_at` will tie). A minimal `index.html.erb` — no styling polish yet, just correct structure/content — renders one row per tour with its id, `moves.count`, and "Complete"/"Incomplete" text derived inline from `moves.count == 64` (no new model method needed for one call site; promote to a `Tour#complete?` method if a second caller shows up).

**Spec first (red)**: `spec/requests/tours_spec.rb` — `GET /tours` is successful, renders one row per seeded tour, shows "Complete" for the 64-move ones and "Incomplete" for the others, newest-first ordering.

**Verify**: spec suite green, `bin/rubocop`/`bin/brakeman` clean.

**Done.** Ordering ended up keyed on `created_at` alone (ties are fine — no seeded data relies on stable tiebreaking yet). Added a `:complete` trait to the `:tour` factory (builds all 64 moves via `Square.all`) so specs needing a full tour don't hand-roll square lists — reused across the Complete/Incomplete and ordering specs.

### 3. Visual pass: title bar + mini-board path-line cards

Port the settled Artifact design into real Tailwind v4 + ERB, reusing the tokens already established on `main` (`--color-board-*`, `--color-accent`/`--color-accent-hover`, `--font-title`) — no new tokens except whatever the status pill and path-line need (darker green `#4f7a2e` for the line; pill colors likely small enough to be inline-arbitrary Tailwind values rather than new named tokens, unless a second use shows up).

- `app/views/tours/_titlebar.html.erb`: wordmark + inert "Play"/"Tours" nav, included at the top of `index.html.erb` only (not added to `new.html.erb`'s existing layout — out of scope for this branch).
- Each tour row: an inline SVG (viewBox `0 0 100 100`, `vector-effect="non-scaling-stroke"` on the polyline so line thickness stays constant regardless of the small board's rendered size, matching the Artifact) tracing `move.square` centers in position order, over an 8×8 checker grid using the real `--color-board-light`/`--color-board-dark` tokens. Point-position math (`Square#x`/`#y` → SVG coordinate) is small enough to stay inline in the partial unless it turns out fiddly enough to warrant its own spec'd helper.
- Status pill, move count, relative timestamp per the prototype.

**Verify**: `bin/dev` manual pass (visual polish, same precedent as the board-visuals branch) — checker pattern, line rendering/thickness, pill colors, title bar, responsive at both breakpoints. `bin/rubocop` clean.

---

# Board visuals: color + motion pass (complete, kept for history)

Pure visual pass on the (then server-rendered) game board: real `@theme` color tokens replacing placeholder Tailwind defaults (chess.com "blue" board direction — cream/dusty-blue squares, warm gold current-square, seafoam legal-move, coral visited, charcoal stuck), self-hosted Poppins title font, motion (state-change transitions, knight-landing pop, legal-move hover), and styled Undo/Restart buttons. Many rounds of hand-tested live iteration (palette, knight SVG, landing animation, two real layout-shift bugs). Superseded in spirit by this branch's dropped-legality-color-semantics decision for the read-only index, but the token system itself (`--color-board-*`, `--color-accent`, `--font-title`) carries forward unchanged. Final user reaction at the time: "wow okay i love it."

---

# Client-side game logic (steps 1-6 shipped, Save Tour deferred; dead code since removed)

Moved knight-move legality/game state into JS (`app/javascript/game/*.js`, `node:test`-covered) so play runs with zero network round trips, replacing the previous Turbo-Frame-per-move approach. `GET /` became a DB-free static skeleton. Steps 7-11 (Save Tour, simplifying `#show`, `MovesController` cleanup) were deferred at the time; the **cleanup half** of that deferral shipped at the start of this branch — `MovesController`, the Ruby `KnightTourGame`/`MoveFinder` services (now-redundant duplicates of the JS port), and the old server-rendered `#show`/board/control partials were all deleted, since nothing referenced them once client-side play existed. **Save Tour itself remains deferred** to a future branch.

---

# Rewrite game logic: Square model → Tour/Move model, Turbo Streams (complete, superseded)

Replaced a single-global-shared-board `Square` AR table with a proper `Tour`/`Move` model (restart creates a new `Tour`, old ones kept for future history features) and real move-legality enforcement server-side. Turbo Streams with manual per-square diffing were tried first, then dropped mid-branch for one Turbo Frame wrapping the whole tour UI (simpler, imperceptible re-render cost, avoided a Streams staleness bug on restart). Deployed live via Kamal; superseded by the client-side rewrite once per-move network RTT (~250-400ms) still didn't feel snappy even with the frame in place.

---

# Rebuild Knight's Tour as a new Rails 8 app, deployed via Kamal to Hetzner (original bring-up, complete)

Rebuilt from an older, messier Rails 7.1.3 app (no `Game`/session concept, split win/stuck logic, dead code, CDN Tailwind, no CI/deploy) into a fresh Rails 8 app: Postgres (Solid Queue/Cache/Cable included), RSpec+FactoryBot, ported `MoveFinder`/game logic, Dockerized and deployed to a Hetzner Cloud VPS via Kamal 2 (secrets in 1Password after an early plain-env-export mistake). Fixed two real Postgres-vs-SQLite bugs (board ordering, Turbo 8 hover-prefetch resetting the board). Went live 2026-08-11; switched from local commits/merges on `main` to a GitHub PR workflow after this point.
