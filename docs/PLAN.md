# Context

The live-play page (`/`, `new.html.erb`) and the playback/replay page (`/tours/:id`, `show.html.erb`) currently use two visually and structurally different control sets: live play has a plain Undo / Restart / Save row, while playback has a polished 5-button transport row (jump-to-start / prev / play-pause / next / jump-to-end), a click-to-seek ticker, a speed toggle, and a path-line show/hide toggle — all built during the recent Tour Playback UI work.

The goal is to make the two pages feel "pretty much the same": live play gets the same transport row and path-line toggle, with the middle button becoming a red "Restart" (replacing Play/Pause, since live play has no auto-advance concept) so it visually reads as destructive/instructive rather than blending in.

This isn't just a markup change. Playback's transport buttons scrub a `TourPlayer` — a read-only cursor over an already-complete, fixed move list. Live play's `KnightTourGame` is a mutable, legality-checked, append-only move list with no cursor at all. Making prev/next/start/end scrub *live* play's history (confirmed with the user) requires giving `KnightTourGame` real undo/redo-stack semantics: stepping back doesn't destroy moves, it stashes them so stepping forward (or jumping to end) restores them — but making a genuinely new move from a scrubbed-back position discards the stale "future" (standard undo/redo branch-cut behavior).

Decisions made with the user before planning this:
- Prev/next/start/end scrub live play's move history, bounded by what's actually been played; jump-to-end returns to the live position. Undo as a separate button/method goes away — `prev` absorbs its job.
- Save stays a separate button, disabled only when there are zero moves (unchanged from today) — it saves whatever's currently on screen, including a scrubbed-back position if that's where the cursor sits when Save is clicked. This is a deliberate, confirmed choice, not an oversight.
- No new red/danger color exists in the palette today (`--color-board-visited` and `--color-status-incomplete` already carry other meanings) — a new token is needed for the Restart button specifically.
- No speed control is being added to live play — there's no auto-play concept there.

# Progress

- [x] 1. `KnightTourGame` gains undo/redo-stack semantics (`prev`/`next`/`toStart`/`toEnd`/`goTo`/`atStart`/`atEnd`/`fullNotationPath`)
- [x] 2. `tour_presenter.js`: ticker reflects full history, expose `atStart`/`atEnd`
- [x] 3. Extract shared path-line math into `path_svg.js`, refactor playback controller to use it
- [x] 4. CSS: danger token + `.transport button.restart`
- [x] 5. `new.html.erb`: transport row, path toggle, SVG overlay, remove Undo
- [x] 6. `tour_controller.js`: wire new targets/actions, remove Undo, render path

# Plan

### 1. `KnightTourGame` gains undo/redo-stack semantics — shipped

`app/javascript/game/knight_tour_game.js` — add `this.redoStack = []` to the constructor. Add:
- `prev()` — if `moves.length > 0`, `redoStack.push(moves.pop())`. Functionally identical to today's `undo()`, just also stashes the popped square.
- `next()` — if `redoStack.length > 0`, `moves.push(redoStack.pop())`. No legality re-check needed (it's replaying a move that was already legal, popped in exact reverse order).
- `toStart()` / `toEnd()` — repeat `prev()`/`next()` until `moves`/`redoStack` is empty, respectively.
- `goTo(n)` — clamped to `[0, moves.length + redoStack.length]`, implemented via repeated `prev()`/`next()`. `prev`/`next`/`toStart`/`toEnd` can all delegate to `goTo` to cut duplication.
- `atStart` (`moves.length === 0`) / `atEnd` (`redoStack.length === 0`) getters.
- `fullNotationPath()` — `[...moves, ...redoStack.slice().reverse()].map(sq => sq.notation)`, for ticker consumption. `notationPath()` (moves-only) stays unchanged since the path-line must only ever show what's actually been walked.

In `visit(square)`: **after** the existing legality check succeeds (not before — clearing earlier would wipe the redo stack even on a rejected illegal-move attempt, breaking the existing "a failed call mutates nothing" contract), add `this.redoStack = []` alongside the existing `this.moves.push(square)`. This is what makes clicking a new square while scrubbed-back correctly discard the stale redo branch.

Remove `undo()` entirely. `restart()` in the controller is unaffected — it already discards the whole `KnightTourGame` instance and builds a fresh one.

Everything else (`currentSquare`, `visited`, `legalMovesFrom`, `visitedCount`, `won`, `stuck`) is unchanged and derives from `moves` exactly as today — these need no changes and correctly recompute for wherever the cursor currently sits, including while scrubbed back (a redo-stack entry isn't in `visited`, so it stays legal and can't falsely trigger `stuck`).

**Spec** (`spec/javascript/game/knight_tour_game.test.js`): replace the old undo-reverts-`currentSquare` case with `prev()` coverage; add `next()` after `prev()`, `toStart()`/`toEnd()` round-tripping, `goTo(n)` clamping at both ends, `atStart`/`atEnd` truth tables, `fullNotationPath()` ordering, and a case confirming a new `visit()` after `prev()` clears the redo stack (and that a *rejected* illegal `visit()` attempt does not).

Built as planned, no deviations. One test-fixture bug caught and fixed during red→green: the "discards stale redo branch" case originally tried `a1 → c1`, but `c1` isn't a legal knight move from `a1` (delta (2,0), not an L-shape) — switched to `c2` (delta (2,1)).

**Known intermediate state**: `tour_controller.js` still calls the now-removed `game.undo()` — clicking Undo in the browser will throw until Step 6 rewires the controller. Expected/tracked, not a regression to fix now; Stimulus controllers aren't unit-tested in this repo so nothing here shows red for it.

**Redone once**: a `git reset --hard` in a separate terminal wiped this step's first implementation (plus a garbled, accidental commit) before it was ever committed from this session. Reapplied identically, this time going file-by-file with explicit confirmation before each one, and holding off on committing until asked.

**Verify**: `node --test spec/javascript/game/knight_tour_game.test.js` red (`game.prev is not a function`) → implement → green (12 examples). Full `node --test` suite 41/41, `bundle exec rspec` 48/48, `bin/rubocop` clean.

### 2. `tour_presenter.js`: ticker shows full history, expose atStart/atEnd — shipped

`app/javascript/game/tour_presenter.js` — build the ticker from `game.fullNotationPath()` instead of `game.notationPath()`, with `current = game.moves.length - 1`, so redo-buffered tiles render as "future" tiles the same way playback's ticker already does against its fixed total. Replace `undoDisabled` with `atStart: game.atStart` / `atEnd: game.atEnd` for the controller to drive the four scrub buttons' disabled state. `saveDisabled` stays `game.visitedCount === 0`, unchanged.

No changes needed to `board_view.js` or `ticker_view.js` — both only ever consume derived arrays/indices, never `game` internals directly.

**Spec** (`spec/javascript/game/tour_presenter.test.js`): update ticker assertions for the new full-history behavior, add cases for `atStart`/`atEnd` in `renderState`'s output, remove the old `undoDisabled` case.

Built as planned. Two of the new `atStart`/`atEnd` assertions were initially written as `assert.ok(!state.atStart)` — a weak check that passes trivially on `undefined` (pre-implementation) as readily as on a real `false`, so they weren't actually red before the fix. Tightened to `assert.equal(state.atStart, false)` before implementing, which genuinely failed against the unchanged `renderState`.

**Known intermediate state**: `tour_controller.js` still reads `state.undoDisabled` (now always `undefined`) to set the Undo button's `disabled` property — untested Stimulus code, so nothing shows red for it; fixed in Step 6 along with the rest of the controller rewiring.

**Verify**: `node --test spec/javascript/game/tour_presenter.test.js` red (5 failures) → implement → green (13 examples). Full `node --test` suite 43/43, `bundle exec rspec` 48/48, `bin/rubocop` clean.

### 3. Extract shared path-line math into `path_svg.js` — shipped

New `app/javascript/game/path_svg.js`, reused by both controllers instead of a third independent copy of the point math (currently duplicated between `_board_path.html.erb`'s ERB and `tour_playback_controller.js`'s inline `renderPath`):
- `pathPoints(squares)` — pure function, the `(x - 0.5) * 12.5, (8 - y + 0.5) * 12.5` formula, returns the SVG `points` string. Gets a unit spec (pure logic, per this repo's convention).
- `renderPath(svgEl, squares)` — builds/updates the two `<polyline>`s + current-position dot on a target `<svg>`. DOM-painting, not pure — no spec, per the same convention that already leaves `ticker_dom.js` untested.

Refactor `tour_playback_controller.js` to delegate to this module — behavior-preserving only, no playback-facing change. (`_board_path.html.erb`'s ERB-side duplication is a separate runtime with no shared build step; not addressed here.)

Built as planned, no deviations. Confirmed `renderPath`'s output is byte-identical to the inline version it replaced (same template string, same coordinate math), so the refactor carries no risk beyond what the existing full test suite already covers.

**Verify**: `node --test spec/javascript/game/path_svg.test.js` red (module not found) → implement → green (2 examples). Full `node --test` suite 45/45, `bundle exec rspec` 48/48, `bin/rubocop` clean.

### 4. CSS: danger token + `.restart` transport button — shipped

`app/assets/tailwind/application.css` — add theme tokens:
```css
--color-danger: #b5453f;
--color-danger-hover: #963a35;
```
A brick/terracotta red, deliberately distinct from `--color-board-visited` (`#bf7575`, lighter/pinker — "already visited," a gentler signal) and `--color-status-incomplete` (`#d9b23c`, amber — different hue), staying within the app's desaturated palette family. Add `.transport button.restart` (background + hover, sized like `.transport button.play` — larger than the four flanking buttons — but with a single static icon, no play/pause swap).

Built as planned, no deviations. No spec (styling only, per convention). Verified by inspection that `bg-danger`/`bg-danger-hover` follow the exact same `--color-*` → utility-class pattern Tailwind v4 already generates for `bg-accent`/`bg-accent-hover` immediately above it in `@theme`.

### 5. `new.html.erb`: transport row, path toggle, SVG overlay, remove Undo — shipped

Remove the Undo button block (`undoButton` target, its disabled styling, `click->tour#undo`). Add the 5-button transport row, reusing `_playback_controls.html.erb`'s exact markup/icons for the four non-middle buttons (start/prev/next/end — copy verbatim, retarget `tour-playback` → `tour`); the middle button reuses new.html.erb's *existing* Restart icon SVG (already in the file today) with a new `class="restart"` and `data-action="click->tour#restart"` (the `restart()` method itself is unchanged). Add a path-toggle row modeled on `_playback_controls.html.erb`'s toggle block, under the `tour` controller (`data-tour-target="pathToggle"`, `click->tour#togglePath`). Add `relative` to the `#board` container's class list (it currently lacks it; `_playback_board.html.erb`'s otherwise-identical container already has it) and add an absolutely-positioned empty `<svg data-tour-target="pathSvg">` sibling after the square divs, copying `_playback_board.html.erb`'s SVG attributes for pixel parity. Save stays as its own button, unchanged in behavior/position.

Not doing in this pass: extracting a shared `_transport_controls.html.erb` partial — the middle button differs enough (restart vs. play/pause icon-swap) that a parameterized partial adds more complexity than it saves for one row; matching Tailwind classes directly gets the visual-parity goal at lower risk. Worth revisiting later if the two rows drift.

**Spec** (`spec/requests/tours_spec.rb`, `GET /` block): add one assertion each for the restart button, the path toggle, and the `pathSvg` element's presence — matching this repo's one-assertion-per-new-markup-piece convention. (No existing Undo-button assertion needs removing — the current `GET /` block doesn't have one.)

Built as planned, no deviations. `restart`'s markup keeps its existing icon SVG (already in the file), just moved into the transport row with `class="restart"` and no `title`/`sr-only` label text duplication issue since the other transport buttons follow the same icon-only + `aria-label` pattern already.

**Verify**: `bundle exec rspec spec/requests/tours_spec.rb -e "GET /"` red (3 new assertions failing) → implement → green (23 examples in that block). Full `bundle exec rspec` 51/51, `bin/rubocop` clean. `tour_controller.js` still unwired to the new targets/actions — Step 6 next.

### 6. `tour_controller.js`: wire targets/actions, remove Undo, render path — shipped

No spec (Stimulus controller, per repo convention — matches `tour_playback_controller.js` having none). New targets: `pathSvg`, `startButton`, `prevButton`, `nextButton`, `endButton`, `pathToggle`. New actions: `toStart`, `prev`, `next`, `toEnd`, `togglePath`, `seek(index)`. Remove `undoButton` target and `undo` action. `restart` is unchanged. `render()` gains `renderPath(this.pathSvgTarget, this.game.moves)` (Step 3's module — deliberately `game.moves`, not the combined redo-inclusive path, since the drawn line should only show what's actually been walked) and sets `disabled` on `prevButton`/`startButton` from `atStart`, `nextButton`/`endButton` from `atEnd` (both now on `renderState`'s output). Wire the ticker's `onSeek` to `seek(index) { this.game.goTo(index + 1); this.render() }` — mirrors playback's existing `seek(index) { stop(); this.goTo(index + 1) }` off-by-one (0-based tiles vs. 1-based move count) exactly, no new translation logic needed.

Built as planned, no deviations. All 6 steps now land: `undo`/`undoButton` fully removed with no stray references anywhere in `app/` or `spec/` (grepped to confirm). `board_view.js`'s legal/current/visited/stuck coloring needed no changes — it already derives everything from `game`, which now just sometimes reflects a scrubbed-back cursor position instead of always the tip.

**Verify**: no spec (Stimulus controller). Full `node --test` suite 45/45, `bundle exec rspec` 51/51, `bin/rubocop` clean. Manual browser verification (scrubbing, redo-branch-discard on new move, path toggle, Restart) still needed — see the top-level Verification note; not yet done as of this commit.

**Followup, further consolidation**: swapped live play's "Visited Squares" label for an inline `N/64` count next to the ticker, matching playback's layout exactly. Added `min-w-[2ch] text-right` to both pages' `stepNum` span so a digit-count change (9→10) doesn't shift the `/64`. `bundle exec rspec` 51/51, `node --test` 45/45, `bin/rubocop` clean.

**Followup layout consolidation** (PR #24 review feedback: the two pages still "looked so different"): found the actual mismatch by diffing `new.html.erb` against `_playback_controls.html.erb` structurally — the shared pieces (transport row, ticker, path toggle) appeared in a different *order* on each page (live had ticker-before-transport; playback has transport-before-ticker) and only some children were individually wrapped in `w-64` rather than the whole column sharing one `w-64` wrapper like playback's does. Reordered live play to transport→ticker→toggle→save (matching playback's transport→ticker→speed→toggle) and switched its outer column to a single `w-64 flex flex-col gap-3 lg:gap-6 items-center` wrapper mirroring playback's, removing the now-redundant per-child `w-64`s. Caught and fixed a self-introduced regression before committing: dropping the status paragraph's `lg:w-64` (now redundant now that the parent is `w-64`) would have silently broken its recently-added wrapping-text width constraint, since the parent uses `items-center` (shrink-wrap) rather than playback's stretch-by-default — restored as `lg:w-full`. The path-toggle row needed the same fix (`w-full` added) for the same reason. Not addressed: the top-slot content itself (`<h1>Tour #id</h1>` on playback vs. the live status/instruction text) — these are genuinely different content serving different purposes, not the same shared element in a different spot, so left alone. No spec (pure markup/CSS reshuffle, no new behavior). `bundle exec rspec` 51/51, `bin/rubocop` clean throughout.

---

Each step lands as its own commit once its spec is green (per this repo's TDD-step-by-step convention) — no batching multiple steps into one commit.

---

# SEO: Meta Tags, Sitemap, and Search Console Verification (complete, kept for history)

Fixed wrong/stale link previews (chat/social, Google/Bing search snippets) caused by the app shipping zero Open Graph/description meta tags and the domain previously hosting a different site.

- **Per-page meta tags** (tracked plan, `#23`): layout grew `<meta name="description">` plus full `og:*`/`twitter:*` tags with site-wide defaults; `new`/`index`/`show` each set `content_for(:title)`/`content_for(:description)`, `show`'s reflecting the tour's actual move count/completion status. `og:image` reuses the existing `icon.png`. Verified live on `sidquinsaat.com` post-deploy via direct `curl`.
- **Follow-up (ad hoc, untracked in this doc's step checklist since each was a single static file, not app logic)**: added `public/sitemap.xml` (root + `/tours`) and referenced it from `robots.txt`; added Google (`public/google955ca68184b1e3c7.html`) and Bing (`public/BingSiteAuth.xml`) Search Console/Webmaster Tools site-verification files, committed straight to `main` per the user's explicit call (skipping the branch/PR flow for these, since they're inert static assets with no app behavior to review).

See `7e97bdc` (#23), `0d5bc77`, and `739fdfa`/`2bf0dd6` for the full history.

---

# Tour Playback UI (complete, kept for history)

Added an interactive playback UI to `tours#show` (scrubber, transport buttons, a sliding click-to-seek moves ticker, speed toggle, path-line show/hide) matching a design prototype reviewed with the user, plus reused the ticker+count on the live `/` play page.

- **`KNIGHT_SVG` extraction**: moved out of `tour_controller.js` into `app/javascript/game/knight_svg.js` so the new playback controller could reuse it — pure refactor, no behavior change.
- **Path-line pulse**: brightened the cyan rim (`#22d3ee` → `#3df3ff`) and deepened the magenta pulse's opacity floor (`0.85` → `0.65`) at the original `3s` cycle, after an over-strong first pass made the cyan bleed across the full stroke.
- **`TourPlayer`** (`app/javascript/game/tour_player.js`): step-cursor over a fixed, already-valid `Square[]` — no legality checking needed (unlike `KnightTourGame`). Exposes `step`/`current`/`visited`/`atStart`/`atEnd`/`goTo`/`notations`.
- **`ticker_view.js` + `playback_view.js`**: pure view-model layer — `tickerView(notations, currentIndex)` and `playbackView(tourPlayer, showPath)`.
- **Show page UI**: `_playback_board.html.erb` + `_playback_controls.html.erb` partials, `tour_playback_controller.js`, CSS. Board sizing switched to a definite `w-80 lg:w-[48rem]` + `aspect-square` container (intrinsic grid sizing broke once an absolutely-positioned SVG path sibling entered the picture). Ticker DOM-rendering (tile building, centering-transform math) factored into a shared `app/javascript/game/ticker_dom.js` (`renderTicker`) so the live-play page could reuse it without duplication.
- **Live `/` play page**: `#visited_count` box replaced with the same ticker partial (passive — no `onSeek`) plus an `N / 64` count; later polish removed the redundant fraction in favor of a rolling move-count animation, matching a "wheel" highlight/taper treatment added to the ticker on both pages. Board sizing, corner radius, row gaps, and controls-panel width unified between the two pages after drifting during independent sizing passes.

Test posture matched this repo's conventions throughout: `node --test` (33 examples) and `bundle exec rspec` (47) both green, `bin/rubocop` clean; no automated coverage of the interactive Stimulus controllers or DOM-rendering helpers (`tour_controller.js` already had none) — verified by hand in the browser with the user across several tuning rounds.

See `963f8fe` and its constituent commits for the full history.

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
