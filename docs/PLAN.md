# Context

Link previews for `sidquinsaat.com` on chat/social platforms (iMessage, Slack, Facebook, etc.) are showing wrong content — leftover from whatever the domain hosted before this app. The app currently ships zero Open Graph or Twitter Card meta tags and no per-page `<meta name="description">`; every page shares the same generic `<title>`. Without real tags, crawlers fall back to guessing, and platforms are also independently serving a stale cached preview from the old site regardless of what's live now.

This plan adds real per-page title/description/OG/Twitter tags so there's a correct source of truth going forward. Forcing platforms to drop their *already-cached* stale preview (via Facebook's Sharing Debugger, Twitter's Card Validator, etc.) is a manual follow-up outside this plan — code changes alone can't bust an existing cache.

Decisions made with the user before planning this:
- **og:image**: reuse the existing 512×512 `public/icon.png` — no new asset design pass. `twitter:card` is `summary` (square-image card) rather than `summary_large_image`, which expects a wider image.
- **Per-page wiring**: `content_for(:title)` / `content_for(:description)` set on all three views (`new`, `index`, `show`); the layout keeps sane site-wide defaults for both so a future view that omits them doesn't ship blank tags.
- **Show page copy**: description reflects live tour state (move count + complete/incomplete), reusing `_status_pill.html.erb`'s existing `moves.size == 64` check rather than adding a new `Tour` model method for a single call site.

# Progress

- [x] 1. Layout: description/OG/Twitter meta tags + per-page `content_for(:title)`/`content_for(:description)` on `new`, `index`, `show`

# Plan

### 1. Layout: description/OG/Twitter meta tags + per-page content_for wiring — shipped

`app/views/layouts/application.html.erb` grows a `page_title`/`page_description` local (falling back to site-wide defaults) and emits `<meta name="description">`, `og:type`/`og:title`/`og:description`/`og:image`/`og:url`, and `twitter:card`/`twitter:title`/`twitter:description`/`twitter:image`. `og:image`/`twitter:image` resolve to an absolute URL (`request.base_url` + `/icon.png`) since these tags must be crawlable outside the app's own host context.

Each view sets `content_for(:title)` and `content_for(:description)`:
- `new.html.erb` (root/play page): the primary link-shared page, gets an explicit description rather than relying on the layout default.
- `index.html.erb`: "Saved Tours" title, description about browsing/filtering saved tours.
- `show.html.erb`: title/description reflect the specific tour's move count and complete/incomplete status.

**Spec** (`spec/requests/tours_spec.rb`, extending the existing `GET /`, `GET /tours`, `GET /tours/:id` describe blocks — kept to one representative assertion per page per this repo's minimal-spec convention, not a full tag-by-tag matrix on every page): root page checks the full complement of tags (title, description, all four `og:*`, `twitter:card`) since that's the page the "wrong preview" bug is actually about; index and show pages each get one test confirming their title/description differ from the default and reflect page-specific content (tour completion status for show).

Built as planned, no deviations.

**Verify**: `bundle exec rspec` red (3 new assertions failing against unchanged views) → implement → green (48 examples total). `bin/rubocop` clean throughout.

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
