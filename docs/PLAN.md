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
- [ ] 4. `ticker_view.js` + `playback_view.js` — pure view-model layer
- [ ] 5. Show page playback UI — partial, CSS, controller, `show.html.erb`
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

### 4. `ticker_view.js` + `playback_view.js` — pure view-model layer

Two small pure modules, built and specced together since `playback_view.js` calls straight into `ticker_view.js` and neither is independently interesting to verify on its own (no UI exists yet to render either against — that's step 5).

`app/javascript/game/ticker_view.js`: e.g. `tickerView(notations, currentIndex)` → array of `{ notation, current }`. Shared by both the show page's ticker (click-to-seek, `currentIndex` can be mid-array) and the live-play ticker (passive, `currentIndex` always the last tile, or `-1` pre-game).

`app/javascript/game/playback_view.js`, analogous to the existing `board_view.js` + `tour_presenter.js` pattern but for a `TourPlayer` instead of a `KnightTourGame`. Given `(tourPlayer, showPath)`, returns:
- per-square board view (dark/light + a `trail` flag for visited-but-not-current, matching the pattern in `board_view.js` but **not** reusing `bg-board-visited`, since that color is reserved for the live-play dead-end signal per the existing CSS comment — this needs its own "trail wash" treatment, step 5)
- step-readout fields: current notation (or `—`), `step`, `total`
- ticker tiles, via `ticker_view.js`
- scrubber value/percent
- transport button disabled states (`atStart`, `atEnd`)
- path-line points (only when `showPath`)

**Spec first (red)**, kept to essentials per this repo's minimal-JS-testing convention:
- `spec/javascript/game/ticker_view.test.js`: marks the right tile `current`; no tile marked current when index is `-1`
- `spec/javascript/game/playback_view.test.js`: trail flag set on visited-non-current squares but not the current one; button disabled states at both boundaries; path points empty when `showPath` is false

**Verify**: `node --test` red → implement → green. `bundle exec rspec`/`bin/rubocop` untouched (no Ruby/Rails in this step).

### 5. Show page playback UI — partial, CSS, controller, `show.html.erb`

The full "build it and look at it" step — a shared ticker partial and new CSS components have no independent way to verify until something renders and drives them, so they land together with the controller and page rewrite, verified with one manual `bin/dev` pass at the end.

- **`app/views/tours/_move_ticker.html.erb`**: parameterized by a `target_prefix` local so it can emit `data-#{target_prefix}-target="tickerTrack"` etc. — reused here by `show.html.erb` (via `tour_playback_controller`) and later by `new.html.erb` (step 6, via `tour_controller`). Just the empty-shell markup (window + track container, matching the mockup's `.move-ticker`/`.move-ticker-track`); JS fills in tiles.
- **CSS**: add to `app/assets/tailwind/application.css` `@layer components` (mirroring the existing `.pagy-nav` pattern, since `::-webkit-slider-thumb` etc. aren't reachable via Tailwind utilities alone): `.scrubber`, `.transport button` (+ `.play` variant), `.move-ticker`/`.tick`, `.speed-btn`, `.toggle`. Reuse existing tokens (`--color-accent`, `--color-board-current`, zinc palette) rather than inventing new ones, except one new token: a muted "trail wash" for playback's visited-but-not-current squares — add e.g. `--color-board-trail` alongside the existing board palette comment block, applied as an `inset box-shadow` wash (like the mockup's `.trail`) rather than a solid fill, so the underlying light/dark checker still shows through.
- **`app/javascript/controllers/tour_playback_controller.js`** (new Stimulus controller): the board root element carries the tour's moves as a JSON data attribute (server-rendered, e.g. `data-tour-playback-moves-value="[...]"`, using a Stimulus JSON value rather than hand-parsing an attribute). On `connect()`: build `Square[]` + a `TourPlayer` starting at `step = total` (agreed default — fully drawn). Wire: transport buttons (start/prev/play-pause/next/end, reusing the mockup's structure/SVGs), scrubber `input`, ticker tile click → seek (stops autoplay first), speed group click (0.5×/1×/2×/4×), path-line toggle, keyboard (←/→/space) scoped to while connected, and a `disconnect()` that clears any running `setInterval` (Turbo navigation must not leak a timer). `render()` applies `playback_view.js`'s output to the DOM: square classes + knight SVG (shared module from step 1) on the current square, path SVG polyline (step 2's pulse, sliced to the current step), step-readout text, scrubber value, ticker tiles, transport button `disabled` attributes.
- **`show.html.erb` rewrite**: the mockup's layout — back link to `tours_path`, header meta (`Tour #<id>` + the existing unchanged `_status_pill` partial), `board-wrap` (64-square grid + path SVG overlay, replacing `_board.html.erb`/`_board_path.html.erb` for this page only — those partials keep serving the index cards unchanged), and the panel (step-readout, scrubber, transport, `_move_ticker` partial, speed group, path toggle).

Scrubber `max` and `TourPlayer.total` come from `tour.moves.size`, **not** a hardcoded `64` — an incomplete/stuck tour's playback should only scrub across its actual moves (`Tour::FULL_TOUR_LENGTH` isn't relevant here, that's for the complete/incomplete *scope*, not this page).

**Spec first (red)** — extend `spec/requests/tours_spec.rb`'s `GET /tours/:id` block:
- the board root's moves data attribute contains the tour's notations in order
- scrubber's `max` equals `tour.moves.size` for both a complete and an incomplete tour
- the back link points to `tours_path`
- the existing "shows move count and Complete/Incomplete pill" specs still pass (selectors may need updating for the new layout)

No controller-behavior spec (matches this repo's existing convention — `tour_controller.js` itself has no test file; only the pure logic modules under `app/javascript/game/` get node:test coverage).

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb` green; `bin/rubocop` clean; manual `bin/dev` pass at desktop and mobile widths — start/prev/play-pause/next/end, scrubber drag, ticker click-to-seek, speed switching mid-play, path toggle, keyboard arrows/space, an **incomplete** tour's scrubber stopping at its real move count (not 64), and no leaked interval after navigating away mid-autoplay (Turbo back/forward). Not covered by automated specs — flagged explicitly in this step's status report.

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
