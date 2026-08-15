# Context

Play is entirely client-side (`KnightTourGame` in `app/javascript/game/knight_tour_game.js`); there is no fetch/network code anywhere in the JS codebase yet, and `ToursController#create` is an unused stub that always creates an empty `Tour` and redirects to root. This plan adds the ability to save a tour — complete, stuck, or just abandoned partway — reusing the `Tour`/`Move` schema and validations that already exist.

Design decisions made while planning:

- **No completion gate.** The app already displays both Complete and Incomplete tours (the index's pill), so saving is never required to be a full 64-move solve. The Save button is available at all times during play, not gated on won/stuck — same treatment as Undo/Restart.
- **Minimum-safety server validation, not a full legality port.** Rather than reintroducing the deleted Ruby `MoveFinder`, `Move` gets one lightweight validation: each move (except a tour's first) must be a legal knight's-move delta from the *previous* move by `position` — `[dx.abs, dy.abs].sort == [1, 2]`. No-duplicate-squares is already free via the existing unique validation/index on `(tour_id, square)`.
- **No `accepts_nested_attributes_for`.** The client sends a plain ordered array of square notations (`game.notationPath()`, e.g. `["e4","f6",...]`) as JSON; the controller builds fresh `Move`s itself via `tour.moves.build(square:, position: i + 1)` in a loop. Every save is a brand-new `Tour` + brand-new `Move`s, never editing existing records.
- **Empty-tour rejection is a real model validation, scoped via a Rails validation context** (`validates :moves, presence: true, on: :save_tour`), not a controller `if` check and not an unconditional validation. Scoping it to a custom context means it only fires when the controller explicitly calls `tour.save(context: :save_tour)` — every existing spec/factory that does `create(:tour)` with zero moves (a normal, pre-existing pattern in this suite) is completely unaffected, since that uses Rails' implicit `:create` context, not `:save_tour`.
- **This is the first JS→Rails request in the app.** JSON in (`{"moves": [...]}`), JSON out. CSRF token read from the existing `<meta name="csrf-token">` tag (emitted by `csrf_meta_tags` in the layout) and sent as `X-CSRF-Token`. Rails' default forgery protection is untouched (`allow_forgery_protection = false` already exists in `config/environments/test.rb`, so request specs need no CSRF handling).
- **Errors use Rails' own JSON serialization** — `render json: tour.errors, status: :unprocessable_entity` — no custom error shape.
- **Post-save redirect goes to the tour's own show page** (`/tours/:id`), which is currently a bare stub and gets built out here: board path (reusing the existing `_board_path.html.erb` SVG partial), move count, a Complete/Incomplete pill, and a "Play again" link back to `/`.
- **The Complete/Incomplete pill is extracted into one shared partial** (`_status_pill.html.erb`) so the index card and the new show page render identical pill markup instead of duplicating `tour.moves.size == 64` + badge classes. Positioning (the index card's `absolute top-2.5 right-2.5` wrapper) stays in `_tour.html.erb`, not in the shared partial, so the same pill drops into the show page's normal document flow too.

No route changes needed — `resources :tours, only: [:index, :create, :show]` already covers both endpoints this touches.

# Progress

- [x] 1. `Move`: legal-knight-delta-from-previous-move validation
- [x] 2. `Tour`: reject an empty moves list via `on: :save_tour` validation context
- [x] 3. `ToursController#create`: JSON save endpoint
- [x] 4. Extract shared `_status_pill` partial
- [x] 5. `tours#show`: real playback page
- [x] 6. JS: `renderState` exposes `saveDisabled`
- [ ] 7. JS: wire the Save button

# Plan

### 1. `Move`: legal-knight-delta-from-previous-move validation

`app/models/move.rb` gets a conditional validation that only runs when `position > 1` and `square` already matches the existing format validation (so it never calls `Square.from_notation` on garbage). It looks up the previous move as the in-memory association member with `position == self.position - 1`, via `tour.moves.to_a.find { ... }` — **not** a DB query. This is deliberate: it must work identically whether `tour` is already persisted, or is a brand-new unsaved `Tour` whose `Move`s were just added via `tour.moves.build` in a loop (exactly what Step 3's controller does, before anything is saved). Compares `to_square` deltas: `[dx.abs, dy.abs].sort == [1, 2]`.

**Spec first (red)** — append to `spec/models/move_spec.rb` (flat `it` blocks, matching existing style):
- `"rejects a move that is not a legal knight's-move from the previous move"` — `create(:move, tour:, position: 1, square: "e4")`, then `build(:move, tour:, position: 2, square: "e5")` → `not_to be_valid`.
- `"accepts a move that is a legal knight's-move from the previous move"` — same setup, `square: "f6"` → `to be_valid`.
- `"does not require the first move in a tour to be a knight's-move from anything"` — `build(:move, tour:, position: 1, square: "a1")` on an otherwise-empty tour → `to be_valid`.
- `"validates legality against an in-memory previous move that hasn't been saved yet"` — `tour = Tour.new`; `tour.moves.build(square: "e4", position: 1)`; `second = tour.moves.build(square: "e5", position: 2)` → `expect(second).not_to be_valid`. Pins the in-memory-lookup design decision Step 3 depends on.

**Verify**: `bundle exec rspec spec/models/move_spec.rb` green; `bin/rubocop` clean.

### 2. `Tour`: `on: :save_tour` validation context

```ruby
class Tour < ApplicationRecord
  has_many :moves, -> { order(:position) }, dependent: :destroy, inverse_of: :tour
  validates :moves, presence: true, on: :save_tour
end
```

**Spec first (red)** — add to `spec/models/tour_spec.rb`:
- `"is invalid in the :save_tour context with no moves"` — `build(:tour).valid?(:save_tour)` → `to be false`.
- `"remains valid by default with no moves"` — `build(:tour)` → `to be_valid` (pins that existing `create(:tour)` usage elsewhere is unaffected).

**Verify**: `bundle exec rspec spec/models/tour_spec.rb` green (including the pre-existing "leaves a prior tour's moves intact" spec, unchanged); `bin/rubocop` clean.

### 3. `ToursController#create`: JSON save endpoint

```ruby
def create
  tour = Tour.new
  create_params.each_with_index { |square, i| tour.moves.build(square:, position: i + 1) }

  if tour.save(context: :save_tour)
    render json: { redirect_url: tour_path(tour) }
  else
    render json: tour.errors, status: :unprocessable_entity
  end
end

private

def create_params
  params.permit(moves: []).fetch(:moves, [])
end
```

`tour.save(context: :save_tour)` runs the normal `Move` validations (Step 1) via the `has_many` autosave path *and* the new presence-of-moves check (Step 2) in one call. On failure nothing is persisted (no partial writes). This step **replaces** the existing `POST /tours` describe block in `spec/requests/tours_spec.rb` wholesale — the old "always creates an empty tour, redirects to root" contract is gone.

**Spec first (red)** — replace the `POST /tours` block:
- `"creates a tour with the submitted moves in order and responds with a redirect_url to the new tour"` — `post tours_path, params: { moves: ["e4", "f6", "d5"] }.to_json, headers: { "Content-Type" => "application/json" }` → `change(Tour, :count).by(1)`, successful response, `Tour.last.moves.order(:position).pluck(:square) == ["e4","f6","d5"]`, `JSON.parse(response.body)["redirect_url"] == tour_path(Tour.last)`.
- `"rejects a move that is not a legal knight's-move and creates nothing"` — `moves: ["e4", "e5"]` → `not_to change(Tour, :count)`, `response.status == 422`, parsed body has a `"square"` error.
- `"rejects an empty moves array and creates nothing"` — `moves: []` → `not_to change(Tour, :count)`, `response.status == 422`, parsed body has a `"moves"` error.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` green; `bin/rubocop` clean.

### 4. Extract shared `_status_pill` partial

New `app/views/tours/_status_pill.html.erb`:
```erb
<% complete = tour.moves.size == 64 %>
<span class="<the existing badge classes, minus the absolute-positioning ones>">
  <%= complete ? "Complete" : "Incomplete" %>
</span>
```
Update `app/views/tours/_tour.html.erb` to wrap `render "tours/status_pill", tour: tour` in the `absolute top-2.5 right-2.5` positioning div it currently has inline, instead of building the span itself. Pure extract-and-replace — behavior is identical.

**Spec first (red)**: none — refactor only, matching the precedent already set below for visual-only/pure-refactor steps. Run the existing pill spec before and after to confirm it stays green throughout.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb -e "shows Complete"` green before and after; `bin/rubocop` clean.

### 5. `tours#show`: real playback page

Replace the stub `app/views/tours/show.html.erb` with: a heading (`Tour #<%= @tour.id %>`), `render "tours/board_path", tour: @tour` (reused as-is, no duplicated SVG logic), move count text, `render "tours/status_pill", tour: @tour` (Step 4) in normal document flow (no positioning wrapper needed here), and a `link_to "Play again", root_path`. No controller changes needed — `set_tour`/`show` already exist.

**Spec first (red)** — extend the `"GET /tours/:id"` block in `spec/requests/tours_spec.rb`:
- `"shows the move count and a Complete pill for a finished tour"` — `create(:tour, :complete)` → doc text includes `"64 moves"` and `"Complete"`.
- `"shows an Incomplete pill and the move count for a partial tour"` — `tour = create(:tour); create(:move, tour:, position: 1, square: "a1")` → doc text includes the move count and `"Incomplete"`.
- `"renders the tour's board path"` — `doc.at_css("svg polyline")` present.
- `"links back to a fresh game"` — a link with text `"Play again"` and `href == root_path`.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` green; `bin/rubocop` clean; `bin/dev` visual pass on `/tours/:id` for both a complete and an incomplete tour.

### 6. JS: `saveDisabled` in `renderState`

Add one derived field to `app/javascript/game/tour_presenter.js`'s `renderState(game)`, mirroring the existing `undoDisabled: game.visitedCount === 0`: `saveDisabled: game.visitedCount === 0`. Pure logic, no DOM/network.

**Spec first (red)** — add to `spec/javascript/game/tour_presenter.test.js`:
- `test("renderState disables save with no moves", ...)` — fresh `KnightTourGame()`, `renderState(game).saveDisabled` truthy.
- `test("renderState enables save once a move has been made", ...)` — `attemptMove(game, "a1")`, `renderState(game).saveDisabled` falsy.

**Verify**: `bin/jstest` green.

### 7. JS: wire the Save button

- `app/views/tours/new.html.erb`: add a third button to `#tour_control`'s row, styled consistently with Undo/Restart, `data-tour-target="saveButton"`, `data-action="click->tour#save"`, `disabled` by default.
- `app/javascript/controllers/tour_controller.js`: add `"saveButton"` to `static targets`; in `render()`, set `this.saveButtonTarget.disabled = state.saveDisabled`; add:

```js
async save() {
  const response = await fetch("/tours", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
    },
    body: JSON.stringify({ moves: this.game.notationPath() })
  })

  if (!response.ok) {
    this.statusTarget.textContent = "Couldn't save — try again."
    return
  }

  const { redirect_url } = await response.json()
  Turbo.visit(redirect_url)
}
```
(`import { Turbo } from "@hotwired/turbo-rails"` alongside the existing `Controller` import.)

**Spec first (red)**: none — side-effecty DOM/network code, hand-tested per this project's established JS-testing convention. Step 6 already covers the one piece of pure logic it depends on; Step 3's request specs already lock down the server contract.

**Verify**: `bin/dev` — play a partial tour, click Save, confirm navigation to `/tours/:id` showing the right moves and pill; save a stuck dead-end and a full 64-move win too; tamper the CSRF token via devtools to confirm the failure path shows the status message rather than silently doing nothing.

---

# Site footer (complete, kept for history)

Quiet footer crediting the site's author, with `mailto:`/GitHub links, added below `yield` in the shared layout mirroring `_titlebar.html.erb` as a bottom bookend. Design prototyped live as a Claude Artifact comparing three styles (minimal centered line, split bar, bordered panel): https://claude.ai/code/artifact/44301dcc-ba80-48ad-b971-88caaf19e85e — landed on the minimal centered line. Skipped the TDD spec-first step for this one (static content, not logic) at the user's call. Drive-by fix: made the "Visited Squares" counter responsive (`text-xl`/`sm:text-3xl`) after the footer pushed the play page past one mobile screen.

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
