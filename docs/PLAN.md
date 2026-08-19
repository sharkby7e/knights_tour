# Context

`tours#show` (`app/views/tours/show.html.erb`) is currently a static page: a full path drawn all at once over the board (`_board.html.erb` + `_board_path.html.erb`, shared with the index cards), a move count, and a status pill. There's no way to watch a saved tour unfold move by move.

A design prototype for this was built as a Claude artifact ("Tour Playback") and reviewed with the user. It mocks a scrubber, transport buttons (start/prev/play-pause/next/end), a sliding "moves ticker" that keeps the current move centered and is click-to-seek, a speed toggle, and a path-line show/hide toggle. The mockup also included two other views (a redesigned tours index and a live-play redesign) — **those are out of scope here**; only the interactive show/playback page and one small piece of the live `/` play page change in this plan.

Decisions made with the user before planning this:
- **Scope**: `tours#show` gets the full playback UI (scrubber, transport, ticker+count). The live `/` play page (`app/views/tours/new.html.erb`, driven by `tour_controller.js`) gets *only* its "Visited Squares" box swapped for the same ticker+count combo — no other changes there.
- **Initial state**: opening a saved tour's show page starts **fully drawn at the end** (matches what's shipped today), not empty at step 0 like the mockup. Scrubbing/rewinding from there is how you replay it.
- **Path styling**: keep the already-shipped animated cyan/magenta pulsing path line (`_board_path.html.erb`, also used on index cards) rather than the mockup's flat muted-green line — but make it more prominent: brighter cyan, stronger pulse.

# Progress

- [x] 1. Extract `KNIGHT_SVG` into a shared module
- [x] 2. Brighten/strengthen the path-line pulse
- [x] 3. `TourPlayer` — step-cursor over an ordered list of squares
- [x] 4. `ticker_view.js` + `playback_view.js` — pure view-model layer
- [x] 5. Show page playback UI — partial, CSS, controller, `show.html.erb`
- [ ] 6. Wire ticker+count into the live `/` play page

# Plan

### 1. Extract `KNIGHT_SVG` into a shared module — shipped

Pure refactor, no behavior change. Moved the inline `KNIGHT_SVG` template literal out of `app/javascript/controllers/tour_controller.js` into `app/javascript/game/knight_svg.js`, exporting it; `tour_controller.js` imports it. `tour_playback_controller.js` (step 8) will need the same SVG, so this avoids a second copy. No new spec — existing `node --test` (25 examples) and `bundle exec rspec` (43 examples) stayed green throughout, proving no regression. `pin_all_from "app/javascript/game", under: "#game"` in `config/importmap.rb` already covers new files in that directory, so no importmap changes were needed. See `4b23b9d`.

### 2. Brighten/strengthen the path-line pulse — shipped

`_board_path.html.erb`'s base polyline is cyan and wider (`stroke-width="4.5"`); the pulsing magenta polyline on top of it is narrower (`3.5`) — so cyan is only ever meant to show as a thin rim around the magenta, never across the full stroke. Bumped the cyan hex from `#22d3ee` to a brighter `#3df3ff`. In `app/assets/tailwind/application.css`, first pass dropped the pulse's opacity floor to `0.3` and sped the cycle up to `1.4s` — too strong: transparent enough for the cyan underneath to show across its full width instead of just the rim, and too frantic. Settled on a `0.65` opacity floor (still a punchier dip than the original `0.85`) at the original `3s` cycle speed — stronger without over-exposing the cyan or feeling rushed. Confirmed visually via `bin/dev`. No spec (pure CSS/color tweak).

### 3. `TourPlayer` — step-cursor over an ordered list of squares — shipped

`app/javascript/game/tour_player.js`. Wraps a fixed `Square[]` (the tour's moves, already validated/persisted — no legality checking needed, unlike `KnightTourGame`) with a `step` cursor from `0` to `total`: `total`, `step`, `current` (the `Square` at `step - 1`, or `null` at step 0), `visited(square)`, `atStart`/`atEnd`, `goTo(n)` (clamps to `[0, total]`), `notations` (full ordered notation list, for the ticker).

**Spec** (kept to essentials per this repo's minimal-JS-testing convention, not a boundary-by-boundary matrix) — `spec/javascript/game/tour_player.test.js`: `current`/`visited` reflect the step cursor mid-tour; `goTo` clamps at both ends and flips `atStart`/`atEnd` accordingly.

**Verify**: `node --test` red (module not found) → implement → green (27 examples). `bundle exec rspec` (43) and `bin/rubocop` stayed green throughout — no Ruby/Rails touched by this step.

### 4. `ticker_view.js` + `playback_view.js` — pure view-model layer — shipped

Built as planned: `ticker_view.js`'s `tickerView(notations, currentIndex)` and `playback_view.js`'s `playbackView(tourPlayer, showPath)`, the latter built around a local `playbackSquareView` parallel to `board_view.js`'s `squareView` but adapted to `TourPlayer`. No deviations from the plan's design. `node --test` red → green (32 examples); `bundle exec rspec`/`bin/rubocop` untouched.

### 5. Show page playback UI — partial, CSS, controller, `show.html.erb` — shipped

Built as planned, then hand-tested and tuned with the user through several rounds: fixed a missing `.transport { display: flex }` rule (buttons were stacking vertically); the board grid switched from relying on each square's own `w-10/lg:w-24` to size the grid intrinsically (works fine on the plain interactive board, but broke — non-square cells, misaligned path line — once an absolutely-positioned SVG sibling entered the picture) to a definite `w-80 lg:w-[48rem]` + `aspect-square` container, matching the sizing technique `_board.html.erb` already uses elsewhere; transport buttons, scrubber, ticker, and speed/path toggles all sized up from the initial pass; speed buttons switched from `flex-1` to fixed `w-10 h-10` squares; the ticker shrunk and given a `backdrop-filter: blur` + `mask-image` edge taper (a "wheel" look, beyond the mockup's plain gradient fade). Request specs green (6 examples covering the moves data attribute, scrubber max, back link, and the updated move-count/pill assertions); `bin/rubocop` clean. No automated coverage of the interactive controller (matches this repo's convention — `tour_controller.js` has no test file either); verified entirely by hand in the browser. Followup refactor: `show.html.erb` split into `_playback_board.html.erb` and `_playback_controls.html.erb` partials (thin composition, one `render` each) ahead of step 6's `tour_controller.js` reuse; the ticker's DOM-rendering (tile building + centering-transform math) pulled out of `tour_playback_controller.js` into a shared `app/javascript/game/ticker_dom.js` (`renderTicker(trackEl, windowEl, tiles, onSeek = null)`) so step 6 doesn't duplicate it — no spec, matching the existing no-test convention for controller-level DOM code.

### 6. Wire ticker+count into the live `/` play page

`app/views/tours/new.html.erb`: replace the `#visited_count` box with the `_move_ticker` partial (passive — no seek handler, matching the mockup's "empty ticker until first move" behavior) plus a small `N / 64` count readout next to it. `tour_controller.js`: extend `render()` to call `ticker_view.js` (step 4) with `game.notationPath()` and the last index, and populate the ticker/count targets. `renderState` in `tour_presenter.js` grows a `ticker`/`notations` field.

**Spec first (red)**:
- `spec/javascript/game/tour_presenter.test.js`: `renderState` includes ticker data reflecting the current moves
- `spec/requests/tours_spec.rb`'s root-page block: the ticker partial is present on `GET /`; any existing assertion on "Visited Squares" text is removed/updated

**Verify**: `node --test` and `bundle exec rspec` green; `bin/rubocop` clean; manual `bin/dev` pass — ticker grows as you play, count updates, undo/restart/save still work.

---

Each step lands as its own commit once its spec is green (per this repo's TDD-step-by-step convention) — no batching multiple steps into one commit.

---

# Filter Tours By Completion Status (complete, kept for history)

Widened the `/tours` index grid to a responsive 3-column layout and added `?status=complete`/`?status=incomplete` filtering.

- **Responsive grid**: fixed-width `32rem` columns via `grid-cols-1 min-[70rem]:grid-cols-[repeat(2,32rem)] min-[104rem]:grid-cols-[repeat(3,32rem)]`, so cards stay a consistent size and the grid re-centers instead of stretching.
- **Pagination resize**: `pagy(..., limit: 6)`, sized to 2 rows of 3 at the widest breakpoint.
- **`Tour.complete`/`Tour.incomplete` scopes**: built from AR/Arel against a grouped `Move` subquery rather than `GROUP BY`/`HAVING` on `Tour` directly, so pagy's own `.count` call still sees a plain Integer. `incomplete` is `where.not(complete)`, covering zero-move tours for free. `Tour::FULL_TOUR_LENGTH = 64` is a deliberate seam for the deferred variable-board-size refactor.
- **`ToursController#index` filtering**: `params[:status]` constrained to exactly `"complete"`/`"incomplete"` via pattern match before use — anything else (missing, garbage) falls back to the unfiltered list. Dispatched via two independent `if` reassignments rather than `public_send`/`send`, since Brakeman flags any `params`-derived value reaching those.
- **Filter row UI**: `nav.pill-filters` — a single segmented pill track (`bg-zinc-900/60` rounded-full container, `bg-accent` active segment), picked over separate status-colored pills after prototyping both, since it doesn't compete visually with the status pills already on the cards below it and extends full-width on mobile for a bigger tap target.

See `85bf5ab` and its constituent commits for the full history.

---

# Enable Saving Tours (complete, kept for history)

Added the ability to save a tour (complete, stuck, or abandoned partway) from the client-side game. `Move` gained a legal-knight-delta-from-previous-move validation (in-memory previous-move lookup, so it works before the tour is persisted); `Tour` gained an `on: :save_tour`-scoped `moves` presence validation so existing zero-move factories elsewhere stay unaffected. `ToursController#create` builds fresh `Move`s from a plain JSON array of square notations and saves in one call (no partial writes on failure), rendering `{ redirect_url: }` or a 422 with Rails' own error JSON. `_status_pill.html.erb` extracted so the index card and the new real `tours#show` playback page (board path, move count, pill, "Play again") render identical markup. JS: `renderState` grew a `saveDisabled` field; the Save button POSTs `game.notationPath()` with the CSRF token from the layout's meta tag and `Turbo.visit`s the redirect on success, or shows a status message on failure.
