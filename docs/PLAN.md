# Context

A new "Statistics" page at `/stats`, linked from the title-bar nav alongside "Play" and "Tours". It shows aggregate numbers across every saved `Tour` (complete and incomplete both count) — total tours, complete/incomplete split, total moves made, average moves per tour — plus a heatmap-style board showing which squares get visited most often, colored by intensity rather than labeled with raw numbers. This is the "most-visited squares" feature the `Move`-as-first-class-model schema was originally chosen to make cheap (see History: Enable Saving Tours).

# Progress

- [ ] 1. `Move.visit_counts` query method
- [ ] 2. `StatsController#show` + route, assembling the tour/move numbers
- [ ] 3. Stats page view: stat tiles + nav link
- [ ] 4. Heatmap board partial, colored by visit intensity

---

## Step 1 — `Move.visit_counts`

A class method on `Move` doing `group(:square).count`, returning `{ "e4" => 3, ... }` across all tours (no scoping to complete-only). Model spec covering: counts accumulate across multiple tours, a square with zero visits is simply absent from the hash.

## Step 2 — `StatsController#show` + route

`get "stats" => "stats#show", as: :stats`. Controller computes: total tours, complete count, incomplete count, total moves, average moves per tour (guard divide-by-zero when there are no tours), and `Move.visit_counts` for the heatmap. Request spec seeds a couple of tours/moves via factories and asserts the numbers land in the rendered HTML; also covers the zero-tours case rendering without error.

## Step 3 — Stats page view: stat tiles + nav link

Stat-tile row (reusing this repo's existing tile/pill visual language) for total tours, complete vs incomplete, total moves, average tour length. Add "Statistics" to `_titlebar.html.erb` next to Play/Tours, active-state styled like the existing two. Request-spec coverage mirrors the existing nav assertions in `tours_spec.rb` (link present, active-state class when on `/stats`).

## Step 4 — Heatmap board partial, colored by visit intensity

New partial reusing the `Square.all` 8×8 SVG grid pattern from `_board_path.html.erb`, but each square's fill is interpolated between the board's base color and the accent color by `count / max_count` instead of the fixed light/dark checker — zero-visit squares stay at the board's base color. Load the `dataviz` skill before implementing the color-scale math (sequential-palette approach) rather than hand-rolling interpolation. Spec (request or helper-level) asserts a known highest-count square renders at full intensity and an unvisited square renders at the base color, using fixed seeded move data.

# Verification

`bundle exec rspec` and `bin/rubocop` clean. Hand-tested in the browser (no automated browser-driving, per existing convention).

---

# History

- **Guard Restart, How-to-Play Modal, Shared Game-Over Board Color** — disabled Restart until the first move like Undo/Save; added a "How to Play" info modal. See PR #31.
- **Add Warnsdorff's-Rule Helper Toggle** — client-side "Show move counts" toggle on the play page, with an info modal explaining the rule. See PR #28.
- **Restore Undo/Restart/Save Row** — Save moved back to an always-visible row with a real "name your tour" popup; ticker removed to free up space. See PR #27.
- **Hide Save Until Game Over, Redesign as a Pill (superseded)** — gated Save behind game-over as a pill; later reversed by the entry above. See `fa1cf3f` (#25).
- **Consolidate Live-Play and Playback Controls** — live play gained the playback page's transport row, ticker, path-toggle, and real undo/redo scrubbing. See `0ea6d56` (#24).
- **SEO: Meta Tags, Sitemap, and Search Console Verification** — per-page OG/description meta tags, `sitemap.xml`, Google/Bing site-verification files. See `7e97bdc` (#23), `0d5bc77`, `739fdfa`/`2bf0dd6`.
- **Tour Playback UI** — scrubber, transport, click-to-seek ticker, speed toggle, and path-line toggle added to `tours#show`, reused on the live play page. See `963f8fe`.
- **Filter Tours By Completion Status** — responsive 3-column `/tours` grid with `?status=complete`/`incomplete` filter pills. See `85bf5ab`.
- **Enable Saving Tours** — `Move`/`Tour` models, save endpoint, and the read-only `tours#show` playback page. See the initial save-tour commits.
