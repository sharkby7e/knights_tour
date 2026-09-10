# Context

A real "About" page at `/about`, linked from the title-bar nav. Personal page for the site's owner: a photo carousel of hand-solved paper knight's tours as the hero, a storytelling section (the owner's own copy — not placeholder), and a "right now" section pitching that they're looking for their next role, with contact CTAs. Decided against the earlier stashed modal approach (an "About" `<dialog>` trigger, WIP on a now-deleted `about-modal` branch) — a full page gives room for photos and real prose that a popup doesn't.

Design direction agreed with the user via a comparison Artifact before building (reference: brittanychiang.com/joshwcomeau.com/lynnandtonic.com browsed for inspiration; landed closest to Comeau's playful-but-clear tone, without needing this page itself to be interactive — the knight's tour game already covers that). Reuses the app's existing dark zinc/Poppins/accent tokens rather than a new palette. Signature element: the app's own dual-stroke cyan/magenta path-line (the same visual used to trace a tour on the board) repurposed as a faint connecting thread down the page's spine, instead of a generic decorative shape. Hero leads with the photo carousel itself, not a headline block.

Photos: static assets under `app/assets/images/` (not Active Storage — these are the owner's own fixed photos, not user uploads; avoids Active Storage's DB tables and, on this Kamal deploy specifically, the need for a persistent volume mount for local Disk storage). Resize/compress before committing (~1600px max width) to keep the repo light.

# Progress

- [x] 1. `/about` route + `AboutController#show` + nav link
- [x] 2. Page layout: photo-carousel hero, story section, "right now" CTA section, path-line spine — placeholder copy/photos matching the approved mockup
- [ ] 3. Swap in the owner's real photos (resized) once provided
- [ ] 4. Swap in the owner's real copy once written

---

## Step 1 — Route, controller, nav link

`resource :about, only: :show`, matching the `resource :stats, only: :show` idiom already used. `AboutController#show` — no instance data needed yet (static content). Add "About" to `_titlebar.html.erb` next to Stats, active-state styled like the existing links; re-check mobile nav fit now that it's a real 4th item (previously validated with a throwaway placeholder link during the stats-page work — confirm it still holds with the real link).

## Step 2 — Page layout

`app/views/about/show.html.erb` (+ partials by section, per the repo's view-decomposition convention): hero carousel (native CSS scroll-snap, no JS library — plain `<figure>` cards, horizontal scroll), story section (prose measure, generous line-height, drop-cap per the mockup), "right now" card (accent-bordered, matching the stats page's discovered-tours tile styling) with CTA buttons (email/LinkedIn/résumé — real targets TBD from the user), and the path-line spine SVG connecting the sections. Placeholder photos (illustrated paper-sketch style, matching the mockup) and placeholder copy stand in until Steps 3–4. Request spec covers structural presence (nav link, carousel, section headings, CTA links) rather than exact copy, since copy is expected to change.

## Step 3 — Real photos

Once the user hands off photo files: resize/compress to web sizes, land under `app/assets/images/`, swap into the carousel partial.

## Step 4 — Real copy

Swap placeholder story/CTA text for the user's own writing once ready. Not really a red/green step — just a content pass once text exists.

# Verification

`bundle exec rspec` and `bin/rubocop` clean. Hand-tested in the browser (no automated browser-driving, per existing convention).

---

# History

- **Statistics Page** — `/stats` with tour/move summary tiles, a "tours discovered" thermometer against the ~19.6 quadrillion possible knight's tours, and a viridis heatmap of most-visited squares (full squares, no gridlines — a Tailwind `stroke-*`-utility bug on the prod box's Linux/amd64 build silently dropped them; fixed by using inline SVG attributes instead of Tailwind classes for that element). See PR #35 and follow-up commits `e118d0f`, `fed3a42`.
- **Guard Restart, How-to-Play Modal, Shared Game-Over Board Color** — disabled Restart until the first move like Undo/Save; added a "How to Play" info modal. See PR #31.
- **Add Warnsdorff's-Rule Helper Toggle** — client-side "Show move counts" toggle on the play page, with an info modal explaining the rule. See PR #28.
- **Restore Undo/Restart/Save Row** — Save moved back to an always-visible row with a real "name your tour" popup; ticker removed to free up space. See PR #27.
- **Hide Save Until Game Over, Redesign as a Pill (superseded)** — gated Save behind game-over as a pill; later reversed by the entry above. See `fa1cf3f` (#25).
- **Consolidate Live-Play and Playback Controls** — live play gained the playback page's transport row, ticker, path-toggle, and real undo/redo scrubbing. See `0ea6d56` (#24).
- **SEO: Meta Tags, Sitemap, and Search Console Verification** — per-page OG/description meta tags, `sitemap.xml`, Google/Bing site-verification files. See `7e97bdc` (#23), `0d5bc77`, `739fdfa`/`2bf0dd6`.
- **Tour Playback UI** — scrubber, transport, click-to-seek ticker, speed toggle, and path-line toggle added to `tours#show`, reused on the live play page. See `963f8fe`.
- **Filter Tours By Completion Status** — responsive 3-column `/tours` grid with `?status=complete`/`incomplete` filter pills. See `85bf5ab`.
- **Enable Saving Tours** — `Move`/`Tour` models, save endpoint, and the read-only `tours#show` playback page. See the initial save-tour commits.
