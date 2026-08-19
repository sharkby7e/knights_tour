# Context

The `/tours` index (`ToursController#index`, `app/views/tours/index.html.erb`) currently renders one flat list of every saved tour, newest first, 2 per page (`pagy(..., limit: 2)`), in a grid capped at `sm:grid-cols-2` — so even on a wide desktop screen it never shows more than two cards per row. There is also no way to narrow the list to just Complete or just Incomplete tours; the Complete/Incomplete pill (`tour.moves.size == 64`) is purely a per-card label today.

This plan adds two independent, small changes to that same page:

- **A wider desktop grid.** `lg:grid-cols-4` on top of the existing `grid-cols-1 sm:grid-cols-2` (mobile/tablet unchanged). Paired with bumping the pagy page size from 2 to 8, so a full desktop page fills two 4-wide rows instead of leaving the grid mostly empty.
- **Filtering by status.** A `?status=complete` / `?status=incomplete` query param on `GET /tours`, driven by two new `Tour` scopes (`Tour.complete`, `Tour.incomplete`) built as `WHERE (subquery move count) = / < 64` rather than `GROUP BY`/`HAVING` — a grouped relation's `.count` returns a Hash instead of an Integer, which breaks pagy's own count query. A filter row above the grid (`All` / `Complete` / `Incomplete`) reuses the existing titlebar nav's active-link pattern (`current_page?` → `text-accent font-semibold` vs `text-zinc-300`) rather than inventing a new tab/pill component.

No migrations, no JS, no route changes — `resources :tours, only: [:index, :create, :show]` and the existing `Tour`/`Move` schema already cover this.

# Progress

- [x] 1. Desktop 4-column grid (`lg:grid-cols-4`)
- [x] 2. Resize pagination: pagy `limit` 2 → 8
- [ ] 3. `Tour.complete` / `Tour.incomplete` scopes
- [ ] 4. `ToursController#index` filters by `params[:status]`
- [ ] 5. Filter row UI (All / Complete / Incomplete links)

# Plan

### 1. Desktop 4-column grid (`lg:grid-cols-4`)

`app/views/tours/index.html.erb`: the `<ul>`'s class goes from `grid grid-cols-1 sm:grid-cols-2 gap-10` to `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-10`. Mobile (1-col) and tablet (2-col) behavior is unchanged; only the `lg:` (1024px+) breakpoint changes.

**Spec first (red)** — add to the existing `describe "GET /tours"` block in `spec/requests/tours_spec.rb`:
- `"lays out the grid at 4 columns on desktop"` — `get tours_path`, `doc.at_css("ul")["class"]` includes `"lg:grid-cols-4"`.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` green; `bin/rubocop` clean; `bin/dev` visual check at a desktop width (4 cards/row) and confirm mobile/tablet are unchanged.

### 2. Resize pagination: pagy `limit` 2 → 8

`app/controllers/tours_controller.rb`: `pagy(Tour.includes(:moves).order(created_at: :desc), limit: 2)` → `limit: 8`. Purely a constant change tied to step 1 — 8 fills exactly two rows of 4 on desktop (and 4 rows of 2 on tablet, 8 rows of 1 on mobile).

**Spec first (red)** — add to `spec/requests/tours_spec.rb`:
- `"paginates at 8 tours per page"` — `create_list(:tour, 9)`, `get tours_path`, `doc.css("li").count == 8`.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` green; `bin/rubocop` clean.

### 3. `Tour.complete` / `Tour.incomplete` scopes

`app/models/tour.rb`:
```ruby
MOVE_COUNT_SQL = "(SELECT COUNT(*) FROM moves WHERE moves.tour_id = tours.id)"

scope :complete, -> { where("#{MOVE_COUNT_SQL} = 64") }
scope :incomplete, -> { where("#{MOVE_COUNT_SQL} < 64") }
```
A correlated subquery in `WHERE`, not `GROUP BY`/`HAVING` — keeps the relation a plain non-grouped `SELECT`, so pagy's own `.count` call on it still returns a plain Integer. Covers zero-move tours under `incomplete` for free (`0 < 64`).

**Spec first (red)** — add to `spec/models/tour_spec.rb`:
- `"Tour.complete returns only 64-move tours"` — `complete = create(:tour, :complete)`; `create(:tour)` (0 moves) → `Tour.complete` → `to eq([complete])`.
- `"Tour.incomplete returns tours with fewer than 64 moves, including zero-move tours"` — `create(:tour, :complete)`; `partial = create(:tour); create(:move, tour: partial, square: "a1", position: 1)`; `empty = create(:tour)` → `Tour.incomplete` → `to contain_exactly(partial, empty)`.

**Verify**: `bundle exec rspec spec/models/tour_spec.rb` green; `bin/rubocop` clean.

### 4. `ToursController#index` filters by `params[:status]`

```ruby
def index
  @status = params[:status] in "complete" | "incomplete" ? params[:status] : nil
  scope = Tour.includes(:moves).order(created_at: :desc)
  scope = scope.public_send(@status) if @status
  @pagy, @tours = pagy(scope, limit: 8)
end
```
Anything other than exactly `"complete"` or `"incomplete"` (missing, blank, garbage) falls back to the unfiltered list — no 500s on a bad query string.

**Spec first (red)** — add to `spec/requests/tours_spec.rb`:
- `"filters to only Complete tours when status=complete"` — one `:complete` tour, one plain tour → `get tours_path(status: "complete")` → one `li`, pill text `"Complete"`.
- `"filters to only Incomplete tours when status=incomplete"` — same setup → `get tours_path(status: "incomplete")` → one `li`, pill text `"Incomplete"`.
- `"ignores an invalid status value and shows everything"` — one `:complete` tour, one plain tour → `get tours_path(status: "bogus")` → both `li`s present.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` green; `bin/rubocop` clean.

### 5. Filter row UI (All / Complete / Incomplete links)

New row above the `<ul>` in `app/views/tours/index.html.erb`, mirroring `_titlebar.html.erb`'s nav-link active-state pattern:
```erb
<nav class="flex gap-6 text-lg mb-6">
  <%= link_to "All", tours_path, class: @status.nil? ? "text-accent font-semibold" : "text-zinc-300" %>
  <%= link_to "Complete", tours_path(status: "complete"), class: @status == "complete" ? "text-accent font-semibold" : "text-zinc-300" %>
  <%= link_to "Incomplete", tours_path(status: "incomplete"), class: @status == "incomplete" ? "text-accent font-semibold" : "text-zinc-300" %>
</nav>
```

**Spec first (red)** — add to `spec/requests/tours_spec.rb`:
- `"highlights All by default and Complete/Incomplete when filtered"` — `get tours_path` → the `"All"` link has class including `"text-accent"`, `"Complete"`/`"Incomplete"` do not; `get tours_path(status: "complete")` → the `"Complete"` link has `"text-accent"`, `"All"` does not.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` green; `bin/rubocop` clean; `bin/dev` visual pass clicking All/Complete/Incomplete.

---

# Enable Saving Tours (complete, kept for history)

Added the ability to save a tour (complete, stuck, or abandoned partway) from the client-side game. `Move` gained a legal-knight-delta-from-previous-move validation (in-memory previous-move lookup, so it works before the tour is persisted); `Tour` gained an `on: :save_tour`-scoped `moves` presence validation so existing zero-move factories elsewhere stay unaffected. `ToursController#create` builds fresh `Move`s from a plain JSON array of square notations and saves in one call (no partial writes on failure), rendering `{ redirect_url: }` or a 422 with Rails' own error JSON. `_status_pill.html.erb` extracted so the index card and the new real `tours#show` playback page (board path, move count, pill, "Play again") render identical markup. JS: `renderState` grew a `saveDisabled` field; the Save button POSTs `game.notationPath()` with the CSRF token from the layout's meta tag and `Turbo.visit`s the redirect on success, or shows a status message on failure.
