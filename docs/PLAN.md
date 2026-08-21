# Context

Live play's Save button currently sits below the transport/ticker/path-toggle, always visible, only `disabled` until at least one move has been made — so it's clickable throughout the whole mid-game, letting the user save any partial position they like.

The user wants to tighten this: Save should be hidden entirely until the game is actually over (won, or stuck with no legal moves left), then appear right next to the status text (where the move count / "You won!" / stuck message shows). Mid-tour saving is being deliberately given up — confirmed explicitly with the user (they first asked to keep some form of mid-tour saving, then reversed that: "let's just hide the button until stuck or solved. no more saving until done/stuck").

This supersedes the "Save stays a separate button, disabled only when there are zero moves" decision recorded in the previous (now-shipped) plan below — that behavior is being replaced, not extended.

# Progress

- [x] 1. `tour_presenter.js`: replace `saveDisabled` with `saveVisible` (true only when `statusVariant` is `"won"` or `"stuck"`)
- [x] 2. `new.html.erb` + `tour_controller.js`: move the Save button next to the status text, hidden by default, shown only when `state.saveVisible`

# Plan

### 1. `tour_presenter.js`: `saveDisabled` → `saveVisible` — shipped

`renderState` currently returns `saveDisabled: game.visitedCount === 0`. Replace with `saveVisible: statusVariant === "won" || statusVariant === "stuck"`, using the `statusVariant` already computed at the top of the function. No other fields change.

**Spec** (`spec/javascript/game/tour_presenter.test.js`): replace the two existing `saveDisabled` cases (no-moves → disabled, one-move → enabled) with `saveVisible` cases: false with no moves, false mid-game (one move made, not stuck/won), true at a real dead end (reuse the existing stuck fixture), true once all 64 squares are visited (reuse the existing won fixture).

Built as planned, no deviations.

### 2. `new.html.erb` + `tour_controller.js`: reposition and hide/show — shipped

`new.html.erb` — move the Save `<button>` (currently its own block below the path-toggle row) into the status area, as a sibling of the `status` `<p>` inside a new flex-row wrapper (`status` keeps its own internal flex-col for the two-line stuck-hint case). Save button starts with a `hidden` class (matches the page's initial "choose a starting square" state, where `saveVisible` is false) and drops its `disabled`/`disabled:*` styling, since visibility now replaces the disabled state — a shown Save button is always clickable.

`tour_controller.js` — in `render()`, replace `this.saveButtonTarget.disabled = state.saveDisabled` with toggling the `hidden` class off `saveButtonTarget` based on `state.saveVisible`.

No spec (Stimulus controller + markup reshuffle, per repo convention — matches how the transport-row/path-toggle markup changes in the prior plan's Step 5/6 had none).

Built as planned, no deviations.

**Followup, redesign**: went through several iterations live with the user — a small square icon-only button beside the headline read poorly, then a labeled pill sharing the hint-text line still duplicated the hint's own wording. Settled on: the "Restart or save" hint text removed entirely, the move count itself sized much larger on desktop, and a labeled "Save" pill on its own line, self-centered so it lines up with the transport row's middle Restart button beneath it. Made invisible (not display-hidden) rather than disabled/removed so its reserved space doesn't shift the transport row when it appears.

---

# Consolidate Live-Play and Playback Controls (complete, kept for history)

Gave live play the same transport row, ticker, and path-toggle as the playback page, including real undo/redo scrubbing through move history, plus several rounds of visual consistency fixes between the two pages.

See `0ea6d56` (#24) and its constituent commits for the full history.

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
