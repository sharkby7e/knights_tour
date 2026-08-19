# Context

The `/tours` index (`ToursController#index`, `app/views/tours/index.html.erb`) renders one flat list of every saved tour, newest first, in a responsive grid (1 column mobile, 2 at `min-[70rem]`, 3 at `min-[104rem]`, 6 per page via `pagy(..., limit: 6)` — steps 1–2 below, already shipped). There is also no way to narrow the list to just Complete or just Incomplete tours; the Complete/Incomplete pill (`tour.moves.size == 64`) is purely a per-card label today.

This plan adds two independent, small changes to that same page:

- **A wider, responsive grid.** Done — see steps 1–2.
- **Filtering by status.** A `?status=complete` / `?status=incomplete` query param on `GET /tours`, driven by two new `Tour` scopes (`Tour.complete`, `Tour.incomplete`) built as `WHERE (subquery move count) = / < 64` rather than `GROUP BY`/`HAVING` — a grouped relation's `.count` returns a Hash instead of an Integer, which breaks pagy's own count query. A filter row above the grid (`All` / `Complete` / `Incomplete`) is styled as a segmented pill track — prototyped and picked over a plain text-link nav and over a semantic-colored-pill alternative (see step 5).

No migrations, no JS, no route changes — `resources :tours, only: [:index, :create, :show]` and the existing `Tour`/`Move` schema already cover this.

# Progress

- [x] 1. Desktop 4-column grid (`lg:grid-cols-4`)
- [x] 2. Resize pagination: pagy `limit` 2 → 8
- [x] 3. `Tour.complete` / `Tour.incomplete` scopes
- [x] 4. `ToursController#index` filters by `params[:status]`
- [x] 5. Filter row UI (All / Complete / Incomplete segmented pills)

# Plan

### 1. Responsive grid — shipped

Landed as `grid-cols-1 min-[70rem]:grid-cols-[repeat(2,32rem)] min-[70rem]:justify-center gap-10 min-[104rem]:grid-cols-[repeat(3,32rem)]` (fixed-width `32rem` columns rather than a fractional `lg:grid-cols-N`, so cards stay a consistent size and the grid re-centers instead of stretching). See `5005051`.

### 2. Resize pagination — shipped

`pagy(Tour.includes(:moves).order(created_at: :desc), limit: 6)` — 6 rather than the drafted 8, sized to the fixed-column grid (2 rows of 3 at the widest breakpoint). See `0563092` / `5005051`.

### 3. `Tour.complete` / `Tour.incomplete` scopes — shipped

`app/models/tour.rb`, built from AR/Arel rather than a raw SQL string:
```ruby
FULL_TOUR_LENGTH = 64

scope :complete, -> {
  where(id: Move.group(:tour_id).having(Move.arel_table[:id].count.eq(FULL_TOUR_LENGTH)).select(:tour_id))
}
scope :incomplete, -> { where.not(id: complete) }
```
`complete`'s subquery groups `moves`, not `tours` — the outer `Tour.where(id: …)` stays a plain non-grouped `SELECT`, so pagy's own `.count` call on it still returns a plain Integer. `incomplete` is just "not complete" (`where.not`), which covers zero-move tours for free since they never appear in the grouped subquery at all. `FULL_TOUR_LENGTH` is a deliberate seam for the deferred variable-board-size refactor — see `docs/` history / memory on that — it should eventually derive from board width × height rather than stay a literal `64`.

**Spec first (red)** — add to `spec/models/tour_spec.rb`:
- `"Tour.complete returns only 64-move tours"` — `complete = create(:tour, :complete)`; `create(:tour)` (0 moves) → `Tour.complete` → `to eq([complete])`.
- `"Tour.incomplete returns tours with fewer than 64 moves, including zero-move tours"` — `create(:tour, :complete)`; `partial = create(:tour); create(:move, tour: partial, square: "a1", position: 1)`; `empty = create(:tour)` → `Tour.incomplete` → `to contain_exactly(partial, empty)`.

**Verify**: `bundle exec rspec spec/models/tour_spec.rb` green; `bin/rubocop` clean.

### 4. `ToursController#index` filters by `params[:status]` — shipped

```ruby
def index
  @status = (params[:status] in "complete" | "incomplete") ? params[:status] : nil
  scope = Tour.includes(:moves).order(created_at: :desc)
  scope = scope.complete if @status == "complete"
  scope = scope.incomplete if @status == "incomplete"
  @pagy, @tours = pagy(scope, limit: 6)
end
```
Anything other than exactly `"complete"` or `"incomplete"` (missing, blank, garbage) falls back to the unfiltered list — no 500s on a bad query string. Note the parens around the `in` pattern-match expression: `x in pattern ? a : b` is a syntax error (the `?`/`:` get parsed as part of the pattern), so the boolean has to be parenthesized before the ternary can apply to it.

Originally dispatched with `scope.public_send(@status)`, which is exactly as safe here (`@status` is already constrained above) but Brakeman's static analysis can't see that guarantee and flags/fails CI on any `params`-derived value reaching `public_send`/`send`. Two independent `if @status == ...` reassignments read as more idiomatic Rails than a `case` that reassigns `scope` through itself, and only one line can ever fire.

**Spec first (red)** — add to `spec/requests/tours_spec.rb`:
- `"filters to only Complete tours when status=complete"` — one `:complete` tour, one plain tour → `get tours_path(status: "complete")` → one `li`, pill text `"Complete"`.
- `"filters to only Incomplete tours when status=incomplete"` — same setup → `get tours_path(status: "incomplete")` → one `li`, pill text `"Incomplete"`.
- `"ignores an invalid status value and shows everything"` — one `:complete` tour, one plain tour → `get tours_path(status: "bogus")` → both `li`s present.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` green; `bin/rubocop` clean.

### 5. Filter row UI (All / Complete / Incomplete segmented pills) — shipped

Prototyped two directions as an artifact (desktop + mobile mockups of each) before coding: **A**, three separate pills where the active color previews the status color it filters to (borrowing `bg-board-legal`/`bg-status-incomplete` directly); and **B**, a single segmented pill track — one `bg-zinc-900/60` rounded-full container, accent-filled active segment — mirroring the existing pagy pagination pills (`.pagy-nav a[aria-current="page"]` → `bg-accent font-semibold text-zinc-950`). **B was picked**: it doesn't compete visually with the status-color pills already on the cards below it, and it extends full-width on mobile for a bigger tap target rather than stacking three separate touch targets.

New row above the `<ul>` in `app/views/tours/index.html.erb`, `nav.pill-filters` (the class exists so the spec can scope to it, since the titlebar also has `<nav>`/`<a>` elements):
```erb
<nav class="pill-filters inline-flex w-full sm:w-auto gap-1 rounded-full border border-zinc-700/60 bg-zinc-900/60 p-1 mb-6">
  <% { nil => "All", "complete" => "Complete", "incomplete" => "Incomplete" }.each do |status, label| %>
    <%= link_to label, status ? tours_path(status:) : tours_path,
          class: "flex-1 sm:flex-none rounded-full px-4 py-1.5 text-sm font-semibold text-center transition-colors duration-150 " +
                 (@status == status ? "bg-accent text-zinc-950" : "text-zinc-400 hover:text-zinc-100") %>
  <% end %>
</nav>
```
`flex-1 sm:flex-none` is what makes the segments equal-width (full-bleed) on mobile and shrink-to-content on desktop, matching the two device mockups.

**Spec first (red)** — added to `spec/requests/tours_spec.rb`:
- `"highlights All by default and Complete/Incomplete when filtered"` — `get tours_path` → within `nav.pill-filters`, the `"All"` link has class including `"bg-accent"`, `"Complete"`/`"Incomplete"` do not; `get tours_path(status: "complete")` → `"Complete"` has `"bg-accent"`, `"All"` does not.

**Verify**: `bundle exec rspec` (43 examples) green; `bin/rubocop` clean. Still worth a manual `bin/dev` visual pass clicking All/Complete/Incomplete at both mobile and desktop widths — not covered by the request spec.

---

# Enable Saving Tours (complete, kept for history)

Added the ability to save a tour (complete, stuck, or abandoned partway) from the client-side game. `Move` gained a legal-knight-delta-from-previous-move validation (in-memory previous-move lookup, so it works before the tour is persisted); `Tour` gained an `on: :save_tour`-scoped `moves` presence validation so existing zero-move factories elsewhere stay unaffected. `ToursController#create` builds fresh `Move`s from a plain JSON array of square notations and saves in one call (no partial writes on failure), rendering `{ redirect_url: }` or a 422 with Rails' own error JSON. `_status_pill.html.erb` extracted so the index card and the new real `tours#show` playback page (board path, move count, pill, "Play again") render identical markup. JS: `renderState` grew a `saveDisabled` field; the Save button POSTs `game.notationPath()` with the CSRF token from the layout's meta tag and `Turbo.visit`s the redirect on success, or shows a status message on failure.
