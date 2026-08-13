# Progress

- [x] 1. JS `Square` port + `node:test` harness bootstrap
- [x] 2. JS `MoveFinder` port
- [x] 3. JS `KnightTourGame` port
- [x] 4. JS `boardView` pure render-state helper
- [x] 5. `tours#new` skeleton route + view; retire `Tour.current`/`#current`
- [ ] 6. Stimulus `TourController`: client-side play, no persistence yet
- [ ] 7. `POST /tours` Save Tour endpoint: server-side replay validation
- [ ] 8. Wire the Save button to the real endpoint
- [ ] 9. `#show` simplified to a read-only saved-tour view
- [ ] 10. Cleanup: delete `MovesController`/specs/routes, dangling references, fold this plan's "complete" summary in
- [ ] 11. (Optional/stretch) One Capybara+Cuprite end-to-end system spec

---

# Client-side game logic, deferred save

## Context

Even after the Turbo Frame rewrite, every move still costs a full server round trip (~250-400ms measured against the live Hetzner `eu-central` deploy, dominated by network RTT, not server processing which is ~20ms). Making that feel instant requires removing the round trip from the play loop entirely, not just hiding it — so this branch moves knight-move legality and game state (`Square`/`MoveFinder`/`KnightTourGame`) into JavaScript and runs play fully client-side. The DB is touched exactly once, when the player explicitly clicks **Save Tour** — decided over auto-save-on-completion because it lets partial/abandoned attempts be saved too, and matches "we only create moves when we save" literally. Refresh-resilience (localStorage) was explicitly decided against for v1 — a refresh mid-play loses progress, same cost already accepted for other trade-offs on this app.

Known, accepted trade-off: today `/` shows one shared *live* tour — any visitor mid-play sees the same in-progress board. After this change, unsaved play only exists in the browser that's playing it; "shared" only applies to tours after they're saved. Intentional, discussed with the user, not something to design around.

Out of scope: accounts/auth, per-user scoping, the visited-squares-heatmap feature, deploy/infra config changes.

## Summary of what changes

| Today | After |
|---|---|
| `root "tours#current"` — lazily creates/reuses `Tour.current` | `root "tours#new"` — static skeleton, no DB write |
| `ToursController#current` | Removed |
| `ToursController#show` | Kept, simplified to read-only (no legal-move links, no Undo/Restart) |
| `ToursController#create` ("Restart") | Repurposed as **Save Tour**: accepts ordered `squares[]`, replays server-side through real `KnightTourGame`, persists transactionally |
| `MovesController`, `resources :moves` | Deleted entirely — no more per-move network round trip |
| `Tour.current` | Deleted |
| `Square`, `MoveFinder`, `KnightTourGame` (Ruby) | Unchanged code, new role: server-side authority used only to validate a Save |
| `spec/requests/moves_spec.rb` | Deleted |
| `spec/requests/tours_spec.rb` | Rewritten for new `/`, `/tours/:id`, `POST /tours` behavior |
| JS engine (`app/javascript/game/*.mjs`) | New — 1:1 port of `Square`/`MoveFinder`/`KnightTourGame`, unit tested via Node's built-in `node:test` (no new deps, no bundler, no `package.json`) |
| `Stimulus TourController` | New — owns in-memory game state, wires clicks/undo/restart/save, re-renders whole board each change |

## Plan

### 1. JS `Square` port + test harness

**Goal**: establish the JS test convention on the smallest class first. Use Node's built-in `node:test`/`node:assert` — zero install, nothing for Dependabot/`bin/importmap audit` to track, given this repo has no `package.json`/npm at all today.

**Files**:
- `app/javascript/game/square.mjs` — port of `app/models/square.rb`
- `app/javascript/game/square.test.mjs` — mirrors `spec/models/square_spec.rb`
- `bin/jstest`: `#!/usr/bin/env sh` + `exec node --test app/javascript/game` (chmod +x, matches `bin/rubocop` convention)
- `config/importmap.rb`: explicit `pin "game/square", to: "game/square.mjs"` (not `pin_all_from`, for a predictable logical name)

```js
const FILES = ["a","b","c","d","e","f","g","h"]

export class Square {
  constructor(x, y) {
    if (!Number.isInteger(x) || x < 1 || x > 8) throw new RangeError(`x out of bounds: ${x}`)
    if (!Number.isInteger(y) || y < 1 || y > 8) throw new RangeError(`y out of bounds: ${y}`)
    this.x = x; this.y = y
    Object.freeze(this)
  }
  static fromNotation(notation) {
    const match = /^([a-h])([1-8])$/.exec(String(notation))
    if (!match) throw new RangeError(`invalid square: ${notation}`)
    return new Square(FILES.indexOf(match[1]) + 1, Number(match[2]))
  }
  static all() {
    if (!Square._all) {
      const squares = []
      for (let y = 8; y >= 1; y--) for (let x = 1; x <= 8; x++) squares.push(new Square(x, y))
      Square._all = squares
    }
    return Square._all
  }
  get notation() { return `${FILES[this.x - 1]}${this.y}` }
  get domId() { return `square_${this.notation}` }
  equals(other) { return other instanceof Square && this.x === other.x && this.y === other.y }
}
```

Test cases (mirror `square_spec.rb`): notation round trip; `all()` order `a8..h8, ..., a1..h1` (64 total); out-of-bounds/malformed → throw; `.equals()` used for array membership since JS has no structural `.includes()`.

**Verify**: `bin/jstest` green.

### 2. JS `MoveFinder` port

```js
import { Square } from "./square.mjs"
const MOVE_SET = [[1,2],[2,1],[2,-1],[1,-2],[-1,-2],[-2,-1],[-2,1],[-1,2]]
export class MoveFinder {
  constructor(square) { this.square = square }
  legalMoves() {
    return this.moveCandidates()
      .filter(([x, y]) => x >= 1 && x <= 8 && y >= 1 && y <= 8)
      .map(([x, y]) => new Square(x, y))
  }
  moveCandidates() { return MOVE_SET.map(([dx, dy]) => [this.square.x + dx, this.square.y + dy]) }
}
```
Pin `game/move_finder`. Tests mirror `move_finder_spec.rb`: 8 deltas from center; corner (`a1`) filters to `{b3, c2}`.

**Verify**: `bin/jstest`.

### 3. JS `KnightTourGame` port

Deliberate shape difference from Ruby: Ruby's version wraps a DB-backed `tour:`; the JS version *is* the tour — holds its own in-memory ordered `moves` array (nothing persisted until Save).

```js
import { Square } from "./square.mjs"
import { MoveFinder } from "./move_finder.mjs"
export class IllegalMoveError extends Error {}
export class KnightTourGame {
  constructor() { this.moves = [] }
  get currentSquare() { return this.moves.length ? this.moves[this.moves.length - 1] : null }
  get lastMove() { return this.currentSquare }
  visited(square) { return this.moves.some(m => m.equals(square)) }
  get legalMovesFrom() {
    if (this.moves.length === 0) return Square.all()
    return new MoveFinder(this.currentSquare).legalMoves().filter(sq => !this.visited(sq))
  }
  visit(square) {
    if (!this.legalMovesFrom.some(sq => sq.equals(square))) throw new IllegalMoveError(`${square.notation} is not legal`)
    this.moves.push(square)
    return square
  }
  undo() { this.moves.pop() }
  get visitedCount() { return this.moves.length }
  get won() { return this.visitedCount === 64 }
  get stuck() { return this.visitedCount > 0 && !this.won && this.legalMovesFrom.length === 0 }
  notationPath() { return this.moves.map(sq => sq.notation) }
}
```
Pin `game/knight_tour_game`. Tests mirror `knight_tour_game_spec.rb` 1:1, including fabricating state directly (`game.moves = Square.all()`) to test `won`/`stuck` the same way the Ruby spec bypasses `visit!` via factories, and the exact dead-end sequence `c2→d4→b3→a1` for `stuck`.

**Verify**: `bin/jstest`.

### 4. JS `boardView` — pure per-square render state

Ports the derived-state math in `squares/_square.html.erb`. Note: in the current partial, the visible color priority (once you account for the `link_to_if legal` emerald overlay sitting on top of `bg_class`) is **`stuck > legal > current > visited > dark/light`** — collapses cleanly since a legal square can never simultaneously be current or visited.

```js
import { Square } from "./square.mjs"
const BG = { stuck: "bg-zinc-700", legal: "bg-emerald-400", current: "bg-[#e0cf9c]", visited: "bg-red-400", dark: "bg-slate-500", light: "bg-slate-100" }
export function squareView(game, square) {
  const stuck = game.stuck
  const current = !!game.currentSquare && square.equals(game.currentSquare)
  const visited = game.visited(square)
  const legal = !stuck && game.legalMovesFrom.some(sq => sq.equals(square))
  const dark = (square.x + square.y) % 2 === 1
  const bgClass = stuck ? BG.stuck : legal ? BG.legal : current ? BG.current : visited ? BG.visited : dark ? BG.dark : BG.light
  return { square, stuck, current, visited, legal, dark, bgClass }
}
export function boardView(game) { return Square.all().map(sq => squareView(game, sq)) }
```
Pin `game/board_view`. Tests port the coloring assertions currently in `moves_spec.rb`/`tours_spec.rb`: stuck → all 64 `bg-zinc-700`; one legal move → `c2`/`b3` emerald, `h8` not; current square shows regardless of checkerboard parity.

**Verify**: `bin/jstest`.

### 5. `tours#new` skeleton route + view; retire `Tour.current`

**Goal**: `GET /` becomes a pure, DB-free static page — the biggest behavioral break from today.

Routes: `root "tours#new"`; `resources :tours, only: [ :create, :show ]`.

Remove `Tour.current` from `app/models/tour.rb` (nothing else calls it once `#current` is gone); trim its spec.

Controller gets a bare `def new; end`.

View `app/views/tours/new.html.erb` (sketch, Tailwind classes carried over): a `data-controller="tour"` wrapper, `#board` of 64 divs with `data-tour-target="square"`, `data-square-notation`, `data-action="click->tour#move"`; `#visited_count` and `#tour_control` with Stimulus targets for status/undo/restart/save; a real `form_with url: tours_path, method: :post` for Save (not `fetch`, so CSRF/Turbo navigation come for free). Deliberately **no** `turbo_frame_tag` wrapper — there's no per-move round trip to scope anymore, and Save's redirect needs to be a real full-page navigation to `/tours/:id`.

Spec (`GET /`): `not_to change(Tour, :count)`, skeleton markup present (64 `[data-square-notation]`, `[data-controller='tour']`, disabled save button).

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` (this block only — rest red until later steps, expected); `bin/dev` — `/` loads an inert, correctly-checkerboarded board, no clicks wired yet.

**Done**: also trimmed `tours_spec.rb`'s "makes the fresh tour current" `POST /tours` example — it asserted the old root-reflects-current-tour behavior this step retires. Known, expected collateral: 3 examples in `spec/requests/moves_spec.rb` now fail because they observe move effects via `get root_path`, which no longer reflects any tour state — that file is fully deleted in step 10 along with `MovesController`, so not fixed here.

### 6. Stimulus `TourController` — client-side play

**Goal**: full play (move/undo/restart/win/stuck) works entirely client-side, zero persistence.

```js
import { Controller } from "@hotwired/stimulus"
import { Square } from "game/square"
import { KnightTourGame, IllegalMoveError } from "game/knight_tour_game"
import { boardView } from "game/board_view"

export default class extends Controller {
  static targets = ["square", "visitedCount", "status", "undoButton", "saveButton", "saveForm"]
  connect() { this.game = new KnightTourGame(); this.render() }
  move(event) {
    try { this.game.visit(Square.fromNotation(event.currentTarget.dataset.squareNotation)) }
    catch (e) { if (!(e instanceof IllegalMoveError)) throw e; return }
    this.render()
  }
  undo() { this.game.undo(); this.render() }
  restart() { this.game = new KnightTourGame(); this.render() }
  render() { /* apply boardView(this.game) to squareTargets, visitedCount, status, undo/save button state */ }
  save(event) { /* wired in step 8 */ }
}
```

**Named exception to the TDD cadence**: no automated spec for this controller — it's DOM-wiring glue with nothing left to unit test beyond what steps 1-4 already cover. Verification is manual `bin/dev` click-through, same precedent as this repo's own prior Turbo Frame step. Say so explicitly rather than write a spec that doesn't test anything real.

**Verify**: `bin/dev` — legal (emerald) clicks move the knight instantly with zero network activity (check devtools Network tab); Undo/Restart work; dead end grays the whole board; 64/64 shows a win state.

### 7. `POST /tours` — Save Tour endpoint, server-side replay validation

**Goal**: the only DB write in the whole flow — never trusts the client.

```ruby
class ToursController < ApplicationController
  def new; end

  def create
    squares = Array(params[:squares]).map { |n| Square.from_notation(n) }
    raise ArgumentError, "no moves to save" if squares.empty?

    tour = nil
    ActiveRecord::Base.transaction do
      tour = Tour.create!
      game = KnightTourGame.new(tour: tour)
      squares.each { |square| game.visit!(square) }
    end

    redirect_to tour_path(tour), notice: "Tour saved!"
  rescue ArgumentError, KnightTourGame::IllegalMoveError
    redirect_to root_path, alert: "Could not save — invalid move sequence."
  end
end
```
A raised exception inside `transaction { }` rolls back and re-raises, so the method-level `rescue` catches it cleanly post-rollback. Add a minimal flash partial to `app/views/layouts/application.html.erb` (none exists yet).

Specs: legal partial sequence saves + redirects to `tour_path`; illegal sequence (e.g. `a1 → h8`) persists nothing, redirects to `/`; malformed notation persists nothing; empty list rejected; a full 64-move legal sequence saves and wins. The 64-move fixture must be a genuine legal open tour — sanity-check it once in the spec by replaying through the real Ruby engine before trusting it as a constant.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb`.

### 8. Wire the Save button to the real endpoint

`TourController#save` injects hidden `squares[]` inputs from `this.game.notationPath()` into the already-rendered form, then lets it submit as an ordinary Rails form POST (Turbo intercepts, follows the redirect as a full navigation since it's outside any frame, disables the button for the duration automatically).

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` (still green, no server change); `bin/dev` — play a partial or full tour, Save, land on `/tours/:id` showing exactly the played path.

### 9. `#show` simplified to a read-only saved-tour view

`MovesController` is going away next step, so `_square.html.erb`'s legal-move link must go regardless — also drop `legal`/`stuck` from the saved view entirely (not meaningful for a static historical record; a saved tour can be incomplete per the save-anytime decision).

`ToursController#show` unchanged in shape. `squares/_square.html.erb` (used only here now) drops to just `current`/`visited`/`dark` coloring, no link. `tours/_control.html.erb` (for show) drops Undo/Restart, shows an outcome line + "New Tour" link back to `/`. `tours/show.html.erb` drops the `turbo_frame_tag` wrapper — nothing swaps into it anymore, it's a plain static page.

Spec: keep board/visited-count/control presence checks; replace "highlights legal squares" (route gone) with "renders no clickable move links" + visited/current coloring off fabricated `Move`s.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb`; `bin/dev` full loop: play → Save → land on `/tours/:id`, confirm static + correctly colored.

### 10. Cleanup

- Delete `app/controllers/moves_controller.rb`, `spec/requests/moves_spec.rb`.
- Grep and remove dangling references: `tour_moves_path`, `tour_move_path`, `Tour.current`, leftover `turbo_frame_tag "tour"`.
- Keep the `:move` FactoryBot factory — still used by `knight_tour_game_spec.rb` and `#show` specs to fabricate persisted state.
- Fold this plan down into "complete, kept for history" in `docs/PLAN.md`, per this repo's own living-plan convention.
- Note, not required for this feature: CI (`.github/workflows/ci.yml`) doesn't run `bundle exec rspec` at all today — a pre-existing gap. If picked up later, wiring `bin/jstest` in alongside a first-time `rspec` CI step is natural but separate work.

**Verify**: `bundle exec rspec` full suite green; `bin/jstest` green; `bin/rubocop`/`bin/brakeman` clean.

### 11. (Optional/stretch) One real-browser system spec

Everything above is covered by JS unit tests + request specs (server replay validation) + manual `bin/dev` verification, not an automated browser test — there's currently zero Capybara/Selenium/Cuprite in the Gemfile, and adding one is a real new dependency (needs a Chrome binary locally/in CI) for a codebase whose CI doesn't even run `rspec` yet. If deeper integration coverage (Stimulus wiring, real clicks, CSRF, the Turbo full-navigation redirect) is wanted later: add `capybara` + `cuprite` (CDP-direct, no Selenium driver-manager layer) to `group :test`, register a `:cuprite` system-spec driver, one spec exercising the full click-through-Save-to-`/tours/:id` path. Flagged optional because it's the one part of this plan adding new infrastructure rather than working within what's already here — not because it lacks value.

## Verification (end to end, once all steps land)

`bundle exec rspec` full suite green; `bin/jstest` green; `docker build` succeeds; full manual playthrough via `bin/dev` — play fully client-side with no network activity per move, Save Tour persists and redirects to a real per-tour URL, `/tours/:id` renders that saved tour read-only.

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
