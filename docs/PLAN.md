# Context

Adding a Warnsdorff's-rule "helper" toggle to the play page, in the space freed up by the previous branch's ticker removal. When on, every currently-legal square shows how many onward moves it would leave (its "degree"); the player applies the rule themselves by picking the lowest number. A small info icon opens a modal explaining the rule. This is purely client-side — the in-progress game has no server-side state until Save ([[project_live_play_logic_stays_client_side]]).

# Progress

- [x] 1. `warnsdorff.js`: pure degree-calculation module
- [x] 2. Surface `legalDegree` on legal squares in `board_view.js`
- [x] 3. Wire up the toggle, board overlay, and info modal

---

## Step 1 — Degree calculation

Shipped. `degreeOf(game, square)` in `app/javascript/game/warnsdorff.js`, tested in `warnsdorff.test.js`.

## Step 2 — Surface it on the board

Shipped. `squareView` in `board_view.js` gains a `legalDegree` field (the degree when legal, `null` otherwise), tested in `board_view.test.js`.

## Step 3 — Toggle, overlay, and info modal

Shipped, pending hand-test on phone. "Show move counts" toggle (off by default) in `new.html.erb`'s free slot; legal squares show their number when it's on. A second `<dialog>` (info icon next to the toggle) explains the rule; `.save-dialog` renamed to `.modal` since both dialogs share that styling now.

# Verification

`node --test` and `bundle exec rspec` green after steps 1-2, `bin/rubocop` clean throughout. Step 3 hand-tested in the browser.

---

# Restore Undo/Restart/Save Row (complete, kept for history)

Reverted the play page's Save button from a game-over-gated pill back to an always-visible Undo/Restart/Save row (enabled after the first move), added a real "name your tour" popup on Save (previously console-only), and removed the play page's moves ticker to free up space for the Warnsdorff helper above.

See PR #27 for the full history.

---

# Hide Save Until Game Over, Redesign as a Pill (superseded, kept for history)

Save previously appeared only once the game was won or stuck, shown as a pill next to the status area instead of a permanently-visible disabled button below the controls. This plan reverses that: Save is back in the Undo/Restart row and no longer game-over-gated.

- `tour_presenter.js`: `saveDisabled` → `saveVisible` (true only when won/stuck)
- Repositioned Save, hid/showed it, then polished the layout (own line, no redundant hint text, bigger desktop count)

See `fa1cf3f` (#25) for the full history.

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
