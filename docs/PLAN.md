# Progress

- [ ] 1. Design tokens: board palette as Tailwind v4 `@theme` custom properties
- [ ] 2. Apply the new palette to board squares + state colors (legal/current/visited/stuck)
- [ ] 3. Motion: transition square state changes, knight-landing animation, legal-square hover
- [ ] 4. Style Undo/Restart buttons and status/visited-count text to match
- [ ] 5. Cross-check responsive breakpoints + full playthrough via `bin/dev`

---

# Board visuals: color + motion pass

## Context

The board works end to end (client-side play shipped in the prior branch, see history below) but looks like placeholder Tailwind defaults — `bg-emerald-400`/`bg-red-400`/`bg-slate-500`/`bg-[#e0cf9c]` picked for correctness, not cohesion, and the Undo/Restart buttons currently have zero styling at all (bare native `<button>`s). This branch is a pure visual pass: a real color palette plus motion (transitions, a landing animation, hover states) — no behavior changes. Scoped to "color pass" + "motion & polish" together, per the user.

Out of scope: Save Tour (steps 7-11 of the prior plan, deferred to its own future branch — see history below), per-user theming (this branch just gets the palette off inline Tailwind defaults and onto named tokens, which makes theming *easier* later, but doesn't build theming itself).

## Plan

### 1. Design tokens: board palette as Tailwind v4 `@theme` custom properties

**Goal**: one source of truth for board colors, instead of the ad hoc Tailwind utility classes duplicated across `board_view.js`'s `BG` map and the dark/light inline ternary in `new.html.erb`.

This app uses Tailwind v4 (`app/assets/tailwind/application.css` is just `@import "tailwindcss";`, no `tailwind.config.js`), where a `@theme { --color-x: ... }` block auto-generates matching utilities (`--color-board-light` → `bg-board-light`, `text-board-light`, etc). Add a `@theme` block there defining: `--color-board-light`, `--color-board-dark`, `--color-board-current`, `--color-board-legal`, `--color-board-visited`, `--color-board-stuck`.

**Verify**: `bin/dev`, confirm the new utility classes apply (even with placeholder values first) before touching the actual palette in step 2.

### 2. Apply the new color palette

Starting direction (adjust after a visual gut-check, not precious about exact values): the page background is already `bg-zinc-800`, so lean into that rather than dropping a generic grey/white checkerboard on top of it —

- Light squares: warm ivory (`#ede4d3`-ish) instead of `slate-100`
- Dark squares: deep plum-slate (`#3d3a52`-ish) instead of `slate-500` — echoes the page background so the board reads as one integrated object
- Current square (knight's position): refined warm gold (`#e0b95c`-ish, tightened from the existing `#e0cf9c`)
- Legal move: soft teal (`#5eead4`-ish) instead of neon `emerald-400`
- Visited: muted rose (`#c76b7a`-ish) instead of `red-400` (softer — visited isn't an error state)
- Stuck (whole-board grey-out): keep desaturated but warm it slightly to match the new palette instead of stock `zinc-700`

Update `board_view.js`'s `BG` map and `new.html.erb`'s inline dark/light class to reference the new `bg-board-*` utilities. **Both places must move together** — they're two independent copies of the same dark/light logic (server-rendered initial paint vs. JS re-render) and already had to be kept in sync before this branch.

**Verify**: `bin/dev` — screenshot for a gut-check before moving on to motion.

### 3. Motion: transitions, landing animation, hover

- Every square gets `transition-colors duration-200 ease-out` so state changes animate instead of snapping (today `render()` fully replaces `className` with zero transition).
- A small "landing" animation (scale pop via a `@theme` `--animate-*` keyframe or a plain Tailwind `animate-` utility) on the square that becomes `current` after a move.
- Legal-move squares get a hover affordance (`hover:brightness-110` + subtle `hover:scale-105`, transformed) to invite clicking.

**Verify**: `bin/dev` — move around the board, confirm transitions read as smooth (not janky) and don't cause layout shift; confirm the win/stuck states (which recolor all 64 squares at once) don't feel chaotic with transitions applied to every square simultaneously.

### 4. Style Undo/Restart buttons + status/visited-count text

Undo/Restart are currently bare unstyled native `<button>` elements. Give them real styling matching the new palette: rounded, hover/active states, a visibly greyed `disabled` state for Undo. Give the status text (`won`/`stuck` message) a color treatment tied to state. Consider rounding the board's outer corners / a subtle container shadow so the 64 squares read as one board rather than a loose grid.

**Verify**: `bin/dev` — full manual check of button states (Undo disabled at start, enabled after first move, hover/active feel right).

### 5. Cross-check + full playthrough

Manual `bin/dev` pass across both breakpoints (`w-10 h-10` mobile vs `sm:w-24 sm:h-24` desktop) and a full playthrough: legal moves, undo, restart, a real dead end (stuck — all 64 recolor), and a completed 64/64 tour (win). No automated spec for this branch — it's a pure visual pass, same "manual verification" precedent as the prior Stimulus-controller step.

**Verify**: `bin/rubocop`/`bin/brakeman` clean (no Ruby logic changed, but touched files); hand-tested by the user in-browser per usual.

---

# Client-side game logic (steps 1-6 shipped, Save Tour deferred)

## Context

Even after the Turbo Frame rewrite, every move cost a full server round trip (~250-400ms on the live Hetzner deploy, dominated by network RTT). This branch moved knight-move legality and game state (`Square`/`MoveFinder`/`KnightTourGame`) into JavaScript so play runs fully client-side with zero network activity per move. Merged via [PR #7](https://github.com/sharkby7e/knights_tour/pull/7) and deployed live.

## What shipped (steps 1-6)

1. JS port of `Square`/`MoveFinder`/`KnightTourGame`/`boardView` (`app/javascript/game/*.js`), unit tested via Node's built-in `node:test` (`spec/javascript/`) — no bundler, no external deps.
2. `GET /` became a DB-free static skeleton (`tours#new`); `Tour.current`/`ToursController#current` deleted.
3. Stimulus `TourController` + a pure `tour_presenter.js` module wire up full client-side play — move/undo/restart/win/stuck — with zero persistence.
4. Established the `#game/*` bare-specifier pattern (`package.json`'s `imports` field + `config/importmap.rb`'s `pin_all_from ... under: "#game", to: "game"`) so new shared JS modules need zero manual importmap/package.json bookkeeping, mirroring how Stimulus controllers already auto-register.
5. Surfaced and fixed two real bugs only visible once this was actually loaded in a browser (not just `node:test`): Propshaft not knowing the `.mjs` MIME type, and fingerprinted asset URLs breaking relative cross-module imports.

## Deferred to a future branch (steps 7-11, not done)

The Save Tour endpoint (`POST /tours` with server-side replay validation), wiring a Save button to it, simplifying `#show` to a read-only saved-tour view, and the `MovesController`/dead-code cleanup that depends on Save existing. The Save button that existed mid-branch was removed entirely (not shipped disabled) since it was already wired to the old `#create` stub and would've silently created empty `Tour` rows — see `git log` on `main` for the removal commit. Full original step-by-step detail for 7-11 lives in this file's git history on the `client-side-game-logic` branch/PR if picked back up.

---

# Rewrite game logic: Square model → Tour/Move model, Turbo Streams (complete, kept for history)

## Context

The app was previously ported and deployed with the board persisted as a single global 64-row `Square` table — every move did a board-wide `Square.update_all` plus a row update, and moves were full-page GET navigations. This branch (`new-game-logic`) replaced that: `Square` became a plain value object (no DB row), `Tour` became a first-class model representing one played-through attempt (restart creates a **new** `Tour`, old tours kept on purpose for future tour-history features), and `Move` became a first-class model (`belongs_to :tour`) rather than a value crammed into an array column. Per-user/session scoping was explicitly out of scope, but the route shape (`resources :tours` with real ids) was chosen up front to avoid a breaking URL change once accounts land.

## What happened

1. `Square` became a `Data.define` value object, replacing the AR-backed model.
2. `MoveFinder` adapted to return `Square` instances instead of raw `[x, y]` pairs.
3. New `tours`/`moves` tables via migration (`square` stored as algebraic notation, unique indexes on `(tour_id, position)` and `(tour_id, square)`); `squares` table dropped.
4. `Tour`/`Move` AR models added (`Tour.current`, `Move` validations scoped to `tour_id`).
5. `KnightTourGame` rewritten to operate over a `Tour`'s `Move`s instead of the `Square` table, enforcing move legality server-side (new behavior vs. the old app, which only relied on the UI never rendering illegal links).
6. Routes/controllers wired up plain-HTML first (full reload per click) to verify the request/response plumbing before layering Turbo on top.
7a. Real board partials (stable DOM ids) replaced the placeholder view, still full-reload.
7b. Turbo Streams with manual per-square diffing were tried first (commit `da077c2`), shipped and fully tested — then dropped mid-branch for a single Turbo Frame wrapping the whole tour UI, after manual `bin/dev` testing found the diffing bookkeeping (four pieces of transient state per action) was real complexity, and that Streams never updating the browser URL caused a staleness bug on restart (refresh/bookmark/share after restart would land on stale state). The Frame approach re-renders the whole board per move (~10-20ms after an earlier N+1 fix, imperceptible) instead of diffing — judged the right trade at this app's scale.
8. Cleanup: deleted the old `Square`/`SquaresController`/views/specs and the now-unused `rails-controller-testing` gem.

**Result**: moves/undo/restart all happened via a single Turbo Frame with no full-page navigation and no stale URLs. Deployed live via Kamal on Hetzner. This is the version superseded by the client-side rewrite above, once manual testing on the live deploy showed per-move network round trips (~250-400ms, dominated by RTT) still didn't feel snappy even with the frame in place.

---

# Rebuild Knight's Tour as a new Rails 8 app, deployed via Kamal to Hetzner (original bring-up, complete)

The app was rebuilt from scratch and deployed to production before this branch's work began — kept here for history/reference.

## Context

The old app (`~/lab/knights_tour_ruby`, Rails 7.1.3) worked, but the user didn't feel good about its modeling and wanted a clean start rather than an in-place refactor. The whole board was persisted as 64 mutable `Square` rows with no `Game`/session concept (one global board shared by every visitor), move-legality logic was correctly isolated in a `MoveFinder` PORO but "already visited" filtering and win/stuck detection were split across the controller and the ERB view, and there was a fair amount of dead code (a broken hardcoded `Square#legal_moves` stub, an unrouted `HomeController`, a static unrelated chessboard view, an unused Stimulus scaffold, stray scratch files). Tailwind was loaded via a CDN `<script>` tag with no build pipeline, and two test frameworks (RSpec + vestigial Minitest) existed side by side. There was a working Dockerfile but nothing wired up deployment — no Kamal, no fly.toml, no CI.

The priority: **get something genuinely deployed and reachable in a browser first**, ahead of code-quality polish. The full data-model redesign (per-session/per-user game scoping, and the Turbo/Tour/Move rewrite tracked above) was explicitly deferred to a later session — this pass intentionally carried forward the single-global-shared-board limitation.

Decisions made:
- **Deploy target**: Hetzner Cloud VPS via Kamal (not Fly, not a PaaS).
- **Domain**: none yet — raw server IP; TLS/domain is a later add-on.
- **Initial scope**: port the existing game logic, lightly cleaned up — reuse `MoveFinder`'s correct move-delta logic, drop dead code, consolidate the split visited/win/stuck logic into one place. Not the full remodel.
- **Repo**: `~/lab/knights_tour`, fresh `git init`, public GitHub repo `sharkby7e/knights_tour`.
- **Tests**: RSpec only, no Minitest.
- **Database**: Postgres, all-Postgres (Solid Queue/Cache/Cable too), deployed as Kamal accessory containers.
- **Local dev Postgres**: Homebrew `postgresql@16` service, not Docker — local Rails runs directly via `bin/dev`.

## What happened (summary — see git history for full detail)

1. **Local toolchain** — Ruby 4.0.6 via mise, Rails 8.1.3, Docker Desktop.
2. **Generated the Rails app** — `rails new . --database=sqlite3 --css=tailwind --skip-test`, added RSpec + FactoryBot.
3. **Git + GitHub** — `sharkby7e/knights_tour`, public, pushed to `main`.
4. **Switched to Postgres** — `bin/rails db:system:change --to=postgresql`, four databases (primary/cache/queue/cable) matching the Solid stack. Fixed generated `database.yml` to add `host`/`port` for the Kamal accessory, renamed the password env var to match the official `postgres` image's own naming. Hit and fixed an unrelated dependabot-introduced boot failure (`image_processing` bump dropped an implicit `ruby-vips` dependency).
5. **Ported the game logic** — `Square` AR model (x, y, has_knight, has_been_visited), `MoveFinder` moved to `app/services/`, new `KnightTourGame` consolidating visited/win/stuck logic, thin `SquaresController#index`. Fixed two real bugs surfaced by Postgres (not present in the old SQLite app): board rendering in the wrong position because `Square.all` had no `ORDER BY` and Postgres doesn't preserve insertion order like SQLite did (fixed with an explicit `.order`), and hovering "Restart" resetting the board due to Turbo 8's link-prefetch-on-hover (fixed with `data-turbo-prefetch: false`).
6. **Docker verification** — confirmed `docker build`/`run` against a local Postgres container works before touching Hetzner; resolved the multi-database bootstrap question (`bin/rails db:prepare` handles creating all four databases + seeding on first boot, no init script needed).
7. **Hetzner VPS** — after some detours through DigitalOcean and Hetzner's ARM line (capacity/cost friction), landed on a Hetzner CPX12 (x86, 2GB, `eu-central`), IP `62.238.111.24`.
8. **Kamal 2 config** — `config/deploy.yml` with `ghcr.io` registry, Postgres 17 accessory, secrets moved to 1Password (`kamal secrets` + `op` CLI) after an early plain-env-export approach accidentally exposed credentials in a terminal transcript (GHCR PAT rotated afterward).
9. **End-to-end verification** — confirmed live and playable at `http://62.238.111.24/`.

**The app went live** on 2026-08-11. This closed out the initial-bring-up phase — per standing preference, future feature work switches to a GitHub PR workflow (`gh pr create`) instead of local commits/merges to `main`.
