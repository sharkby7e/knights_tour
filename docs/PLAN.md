# Progress

- [x] 1. `Square` value object (replaces AR-backed `Square`)
- [x] 2. `MoveFinder` adapted to return `Square` objects
- [x] 3. `Tour`/`Move` schema + migrations
- [x] 4. `Tour`/`Move` models
- [x] 5. `KnightTourGame` rewritten around `Tour`/`Move`
- [x] 6. Routes + controllers (plain HTML first, no Turbo Streams yet)
- [x] 7a. Real board partials, still full-reload
- [ ] 7b. Turbo Streams for moves (create/destroy)
- [ ] 7c. Turbo Streams for restart (tours#create)
- [ ] 8. Cleanup (delete old Square/SquaresController/views, seeds, gems)

---

# Rewrite game logic: Square model → Tour/Move model, Turbo Streams

## Context

The app was previously ported and deployed (Rails 8.1.3 + Postgres, live via Kamal on Hetzner at `http://62.238.111.24/`) with the board persisted as a single global 64-row `Square` table. Every move did `Square.update_all(has_knight: false)` (touches all 64 rows) plus a second row update — absurd for what's fundamentally a single-value change. Moves were also full-page GET navigations (`params[:location]`), so every click reloaded the entire page.

Branch `new-game-logic` is a deliberate rewrite of the game logic, not a patch. Through discussion, the design that emerged:
- The 8×8 board itself is static/computable — no need to persist it as rows at all. `Square` becomes a plain Ruby value object, not an AR model.
- A `Tour` represents one played-through attempt. Restarting creates a **new** `Tour` row rather than wiping the current one — old tours are kept on purpose, because future features are expected to build on tour history (e.g. "most visited squares across saved tours," creatively displaying past tours). Not building those features now, but not designing something that forecloses them either.
- A `Move` is a first-class model (`belongs_to :tour`), not a value crammed into an array column — moves are independently interesting (cross-tour queries like "most visited squares"), and capped at 64 rows per tour so there's no row-count cost concern.
- Moves persist to the DB (one small write each — an `INSERT`/`DELETE` on `moves`, never a board-wide update), but the page must not reload or re-render the whole 64-square grid per move — solved with Turbo Streams (targeted DOM patches), not Frames or full-page nav.
- Per-user/per-session scoping is explicitly **out of scope this pass** — there's still one current global tour, same shared feel as before. But tours are expected to eventually belong to a user (to list "all of a user's solved tours"), so the route/URL shape already carries real tour ids (`resources :tours`, not a singular `resource :tour`) to avoid a breaking URL change when accounts land.

This replaces `Square`/`KnightTourGame`/`SquaresController` and their specs/views entirely. It does not add accounts, does not build tour-history display features, and does not change deploy/infra (Kamal, Postgres, etc. are untouched — this is app-layer only).

**Working style for this branch**: test-drive (TDD: write the failing spec first, then the minimum code to pass it) each phase below, and clear context between phases freely — each phase is self-contained (states its own goal, files, and TDD spec-first steps) and ends with its own verification checkpoint and a natural commit boundary. Update this file's checkboxes and add narrative as phases complete, same living-plan convention as the rest of this doc.

## Plan

### 1. `Square` value object

**Goal**: replace the AR-backed `Square` with a plain Ruby value object representing a board coordinate. No DB involved yet.

**TDD**: `spec/models/square_spec.rb` first, covering: `.from_notation("e4")` / `#notation` round-trip; `.all` returns 64 unique squares in rank8→1, file a→h order (matches the current `Square.order(y: :desc, x: :asc)` render order — this exact ordering assumption caused a real bug once already, see step 5 of the original bring-up plan below, worth pinning with a test); out-of-bounds coordinates and malformed notation both raise `ArgumentError`; equality (`==`) works for `.include?`/`.uniq` on arrays of squares.

```ruby
class Square < Data.define(:x, :y)
  FILES = ("a".."h").to_a.freeze

  def self.from_notation(notation)
    match = notation.to_s.match(/\A([a-h])([1-8])\z/)
    raise ArgumentError, "invalid square: #{notation.inspect}" unless match
    new(x: FILES.index(match[1]) + 1, y: match[2].to_i)
  end

  def self.all
    @all ||= 8.downto(1).flat_map { |y| (1..8).map { |x| new(x:, y:) } }.freeze
  end

  def initialize(x:, y:)
    raise ArgumentError, "x out of bounds" unless (1..8).cover?(x)
    raise ArgumentError, "y out of bounds" unless (1..8).cover?(y)
    super
  end

  def notation = "#{FILES[x - 1]}#{y}"
  def dom_id   = "square_#{notation}"
end
```

Overwrites the existing AR-backed `app/models/square.rb`. `Data.define` gives immutable value semantics (`==`/`hash`/readable `inspect`) for free — needed since later phases rely on `.include?`/`.uniq` over arrays of squares.

**Verify**: `bundle exec rspec spec/models/square_spec.rb` green. (Rest of the suite breaks until later phases — expected.)

### 2. `MoveFinder` adapted to `Square`

**Goal**: `MoveFinder#legal_moves` returns `Square` instances instead of raw `[x, y]` pairs.

**TDD**: update `spec/services/move_finder_spec.rb` — construct `Square.new(x:, y:)`, assert `legal_moves` returns `Square` instances. Keep existing delta-math cases (8 knight-move deltas, off-board filtering) unchanged.

```ruby
def legal_moves
  move_candidates
    .select { |x, y| (1..8).cover?(x) && (1..8).cover?(y) }
    .map { |x, y| Square.new(x:, y:) }
end
```

`initialize(square:)` already duck-types on `.x`/`.y`, so it accepts the new `Square` unchanged.

**Verify**: `bundle exec rspec spec/services/move_finder_spec.rb` green.

### 3. `Tour`/`Move` schema + migrations

**Goal**: new tables in, old `squares` table dropped. Schema only, no model behavior yet.

New migrations (never edit the already-deployed `create_squares` migration):

```ruby
# drop_squares.rb
def up = drop_table :squares
def down  # recreate the current squares table, for reversibility

# create_tours.rb
create_table :tours do |t|
  t.timestamps
end

# create_moves.rb
create_table :moves do |t|
  t.references :tour, null: false, foreign_key: true
  t.string  :square, null: false
  t.integer :position, null: false
  t.timestamps
end
add_index :moves, [ :tour_id, :position ], unique: true
add_index :moves, [ :tour_id, :square ], unique: true
```

`square` stores algebraic notation (`"e4"`) directly — enables `GROUP BY square` for future "most visited squares" queries; `Move` never needs numeric coordinate math itself (that happens off the *current* position via `Square`/`MoveFinder` at request time).

Empty out `db/seeds.rb` — it currently seeds 64 `Square` rows and will raise once the `squares` table is gone; tours/moves are created lazily instead.

**Verify**: `bin/rails db:migrate`; `db/schema.rb` shows `squares` gone, `tours`/`moves` present; `bin/rails db:rollback STEP=3` + re-migrate to check `drop_squares`'s reversibility.

### 4. `Tour`/`Move` models

**Goal**: AR models with the validations/associations the rest of the app needs.

**TDD**: `spec/models/tour_spec.rb` (`Tour.current` returns latest or creates one; a new `Tour` leaves a prior tour's `Move`s intact) and `spec/models/move_spec.rb` (`square` format validation; `position`/`square` uniqueness scoped to `tour_id`) first. Update `spec/factories.rb`: drop `:square`, add `:tour` and `:move` factories.

```ruby
# app/models/tour.rb
class Tour < ApplicationRecord
  has_many :moves, -> { order(:position) }, dependent: :destroy, inverse_of: :tour

  def self.current
    order(id: :desc).first || create!
  end
end

# app/models/move.rb
class Move < ApplicationRecord
  belongs_to :tour

  validates :square, presence: true, format: { with: /\A[a-h][1-8]\z/ }
  validates :square, uniqueness: { scope: :tour_id }
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 },
                        uniqueness: { scope: :tour_id }

  def to_square = Square.from_notation(square)
end
```

No `finished_at`/`outcome` column on `Tour` this pass — `won?`/`stuck?` stay derived live from `moves`.

**Verify**: `bundle exec rspec spec/models/` green.

### 5. `KnightTourGame` rewritten

**Goal**: game-logic service object operates over a `Tour`'s `Move`s instead of the `Square` table.

**TDD**: rewrite `spec/services/knight_tour_game_spec.rb` first: first move on an empty tour accepts any square; illegal square raises `IllegalMoveError` and creates no `Move`; `legal_moves_from` excludes visited squares; `won?`/`visited_count` via 64 fabricated `Move` rows; `stuck?` via a position where every knight-move destination is visited; `undo!` removes the last move and reverts `current_square`, no-ops on an empty tour.

```ruby
class KnightTourGame
  class IllegalMoveError < StandardError; end

  attr_reader :tour

  def initialize(tour:) = @tour = tour

  def current_square
    last = tour.moves.order(:position).last
    last && Square.from_notation(last.square)
  end

  def visited?(square) = tour.moves.exists?(square: square.notation)

  def legal_moves_from
    return Square.all if tour.moves.none?
    MoveFinder.new(square: current_square).legal_moves.reject { |sq| visited?(sq) }
  end

  def visit!(square)
    raise IllegalMoveError, "#{square.notation} is not legal" unless legal_moves_from.include?(square)
    tour.moves.create!(square: square.notation, position: next_position)
  end

  def undo! = tour.moves.order(:position).last&.destroy

  def visited_count = tour.moves.count
  def won?           = visited_count == 64
  def stuck?         = visited_count.positive? && !won? && legal_moves_from.empty?

  private

  def next_position = (tour.moves.maximum(:position) || 0) + 1
end
```

`visit!` enforces legality server-side (new behavior vs. the old app, which only relied on the UI never rendering illegal links) — worth keeping now that moves are a real mutating endpoint.

**Verify**: `bundle exec rspec spec/services/` green.

### 6. Routes + controllers (plain HTML first, no Turbo Streams yet)

**Goal**: a working, clickable (still full-page-reload) version of the game on the new models, verifying the request/response plumbing before layering Turbo Streams on top in step 7.

**TDD**: `spec/requests/tours_spec.rb` (`GET /` redirects to `/tours/:id`, lazily creating one; `POST /tours` creates a new tour and redirects, leaving the previous tour's moves queryable) and `spec/requests/moves_spec.rb` (legal `POST` creates a `Move` and redirects; illegal square → 422, no `Move`; `DELETE` destroys the move and redirects) first, asserting plain HTML-redirect behavior only.

```ruby
# config/routes.rb
root "tours#current"

resources :tours, only: [ :show, :create ] do
  resources :moves, only: [ :create, :destroy ]
end
```

Plural with real ids (not a singular `resource :tour`) specifically because tours are expected to eventually belong to a user — this URL shape won't need to change when that lands, only how `Tour.current` resolves.

```ruby
# app/controllers/tours_controller.rb
class ToursController < ApplicationController
  def current
    redirect_to tour_path(Tour.current)
  end

  def show
    @tour = Tour.find(params[:id])
    @game = KnightTourGame.new(tour: @tour)
  end

  def create
    @tour = Tour.create!   # old tour's moves untouched — history preserved
    redirect_to tour_path(@tour)
  end
end

# app/controllers/moves_controller.rb
class MovesController < ApplicationController
  before_action :set_game

  def create
    @game.visit!(Square.from_notation(params[:square]))
    redirect_to tour_path(@tour)
  rescue ArgumentError, KnightTourGame::IllegalMoveError
    head :unprocessable_entity
  end

  def destroy
    @game.undo!
    redirect_to tour_path(@tour)
  end

  private

  def set_game
    @tour = Tour.find(params[:tour_id])
    @game = KnightTourGame.new(tour: @tour)
  end
end
```

Views: a minimal `app/views/tours/show.html.erb` reusing the existing Tailwind grid markup style, iterating `Square.all` and reading state off `@game`. OK to be visually rough — step 7 restructures partials anyway.

**Verify**: `bundle exec rspec spec/requests/` green; `bin/dev` manual click-through — moves/undo/restart work, full reload per click expected/fine at this stage.

### 7a. Real board partials, still full-reload

**Goal**: replace the `tours/show.html.erb` placeholder with the real board, still via ordinary full-page navigation — get the partials and their markup/DOM ids right before layering Turbo Streams on top in 7b/7c.

**TDD**: extend `spec/requests/tours_spec.rb`'s `GET /tours/:id` case to assert real markup is present — 64 rendered squares, a visited-count element, a control (Restart) link — instead of just `be_successful`.

Partials with stable DOM ids (these ids are what 7b/7c will target with Turbo Stream replaces, so get them right now):
- `tours/_board` — `<div id="board">`, iterates `Square.all`, renders `squares/_square` for each.
- `squares/_square` — `<div id="<%= square.dom_id %>">`, checkerboard via `(square.x + square.y).odd?`, current/visited/legal states styled off `@game`, `link_to "", tour_moves_path(game.tour, square: square.notation), data: { turbo_method: "post", turbo_prefetch: false }` for legal squares.
- `tours/_visited_count` — `<div id="visited_count">`.
- `tours/_control` — Undo + Restart/Congrats, `<div id="tour_control">`.

`tours/show.html.erb` becomes a thin wrapper rendering these four partials with `game: @game`.

**Verify**: `bundle exec rspec spec/requests/` green. `bin/dev` manual click-through — moves/undo/restart work and render correctly, full reload per click still expected/fine at this stage.

### 7b. Turbo Streams for moves (create/destroy)

**Goal**: move/undo stop doing full-page navigation — only changed parts of the page get patched in place.

**TDD**: extend `spec/requests/moves_spec.rb` with Turbo Stream assertions: `text/vnd.turbo-stream.html` content type with `turbo-stream` tags targeting the right DOM ids; win/stuck renders (fabricated `Move` rows) show Congrats / full-board gray-out; a short real sequential-`POST` happy path (~5 moves); undo un-grays the board out of a stuck state. Use `Nokogiri::HTML5.fragment(response.body)` for assertions (transitive dependency already, no new gem).

`MovesController` gains `respond_to { |f| f.turbo_stream; f.html { redirect_to ... } }`, computing what changed before/after mutating (previous square, new square, legal-move squares before/after) into `@squares_to_refresh`.

```erb
<%# app/views/moves/create.turbo_stream.erb %>
<% if @game.stuck? %>
  <%= turbo_stream.replace "board", partial: "tours/board", locals: { game: @game } %>
<% else %>
  <% @squares_to_refresh.each do |square| %>
    <%= turbo_stream.replace square.dom_id, partial: "squares/square", locals: { square:, game: @game } %>
  <% end %>
<% end %>
<%= turbo_stream.replace "visited_count", partial: "tours/visited_count", locals: { game: @game } %>
<%= turbo_stream.replace "tour_control", partial: "tours/control", locals: { game: @game } %>
```

`moves/destroy.turbo_stream.erb` mirrors this using `@was_stuck` (undo always resolves a stuck state).

Whole-board replace on stuck-entry/exit is required, not optional: the `_square` partial grays out *every* square when stuck, not just the current one — a pure per-square diff can't reproduce that.

**Verify**: `bundle exec rspec spec/requests/` green. Manual browser check via `bin/dev`: devtools Network tab shows only a `turbo-stream` fetch per move (no full navigation); undo restores the previous square as clickable; stuck/win states render correctly.

### 7c. Turbo Streams for restart (tours#create)

**Goal**: Restart stops doing full-page navigation too, consistent with 7b.

**TDD**: extend `spec/requests/tours_spec.rb`'s `POST /tours` case with a Turbo Stream assertion — response replaces `board`, `visited_count`, and `tour_control`, and the new board reflects the fresh (empty) tour, not the old one's moves.

`ToursController#create` gains the same `respond_to` pattern. `tours/create.turbo_stream.erb` always full-replaces `board` + `visited_count` + `tour_control` (a restart is a wholesale swap to a new `Tour`, no partial diffing needed).

**Verify**: `bundle exec rspec spec/requests/` green. Manual browser check via `bin/dev`: Restart button no longer triggers full navigation; Restart creates a genuinely new `Tour` row while the old tour's `Move`s remain (check via Rails console).

### 8. Cleanup

**Goal**: remove everything the rewrite made dead, and log what happened.

- Delete `app/views/squares/index.html.erb`, `app/controllers/squares_controller.rb`, `spec/requests/squares_spec.rb` (superseded by `tours_spec.rb`/`moves_spec.rb`).
- Remove `rails-controller-testing` from the `test` group in the Gemfile — no longer needed once no specs use `assigns[:...]`.
- Grep for lingering references to the old AR `Square` semantics (`has_knight`, `has_been_visited`, `SquaresController`, `squares_path`).

**Verify**: `bundle exec rspec` full suite green. `docker build` succeeds. Full manual playthrough via `bin/dev`.

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
