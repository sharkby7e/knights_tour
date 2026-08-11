# Progress

- [x] 1. Local toolchain (Ruby 4.0.6 via mise, Rails 8.1.3, Docker Desktop)
- [x] 2. Generate Rails app (SQLite, Tailwind, RSpec added, `--skip-test`)
- [x] 3. Git init + push to `sharkby7e/knights_tour` on GitHub
- [x] README written for local dev setup
- [x] 4. Switch primary database from SQLite to Postgres
- [x] 5. Port the game logic, lightly cleaned (Square model, `app/services/move_finder.rb`, new `app/services/knight_tour_game.rb`, thin `SquaresController`, views, specs)
- [x] 6. Docker verification (local build/run before touching Hetzner)
- [x] 7. Hetzner VPS provisioning (user did this manually)
- [x] 8. Kamal 2 config + first deploy (includes Postgres accessory)
- [x] 9. End-to-end verification of the deployed app

**The app is live** at `http://62.238.111.24/` (no domain yet — raw IP). Deployed via `kamal setup` on 2026-08-11. This closes out the initial-bring-up phase of the plan — per the user's standing preference, future feature work/refactors switch to a GitHub PR workflow (`gh pr create`) instead of local commits/merges to `main`, the way steps 4-9 were done.

---

# Rebuild Knight's Tour as a new Rails 8 app, deployed via Kamal to Hetzner

## Context

The current app (`~/lab/knights_tour_ruby`, Rails 7.1.3) works, but the user doesn't feel good about its modeling and wants a clean start rather than an in-place refactor. The whole board is persisted as 64 mutable `Square` rows with no `Game`/session concept (one global board shared by every visitor), move-legality logic is correctly isolated in a `MoveFinder` PORO but "already visited" filtering and win/stuck detection are split across the controller and the ERB view, and there's a fair amount of dead code (a broken hardcoded `Square#legal_moves` stub, an unrouted `HomeController`, a static unrelated chessboard view, an unused Stimulus scaffold, stray scratch files). Tailwind is loaded via a CDN `<script>` tag with no build pipeline, and two test frameworks (RSpec + vestigial Minitest) exist side by side. There's a working Dockerfile but nothing wires up deployment — no Kamal, no fly.toml, no CI.

The user's stated priority: **get something genuinely deployed and reachable in a browser first**, ahead of code-quality polish. The full data-model redesign (e.g. per-session/per-user game scoping) is explicitly deferred to a later session — this pass intentionally carries forward the single-global-shared-board limitation. The new app should be initialized with RSpec, Tailwind, and Docker from the start, and deployed with Rails' current recommended path (Kamal 2) to a new Hetzner VPS, replacing the user's current Fly.io-based workflow.

Decisions already made with the user:
- **Deploy target**: new Hetzner Cloud VPS via Kamal (not Fly, not a PaaS).
- **Domain**: none yet — access via raw server IP; TLS/domain is a later add-on.
- **Initial scope**: port the existing game logic, lightly cleaned up — reuse `MoveFinder`'s correct move-delta logic, drop the dead code, consolidate the split visited/win/stuck logic into one place. Not the full remodel.
- **Repo**: new sibling directory `~/lab/knights_tour`, fresh `git init`, new public GitHub repo `sharkby7e/knights_tour` (matches the old repo's visibility).
- **Tests**: RSpec only, no Minitest.
- **VPS provider**: Hetzner Cloud.
- **Database**: Postgres (decided 2026-08-04, supersedes the SQLite default the app was generated with in step 2) — deployed as a Kamal accessory container. **All-Postgres** (decided 2026-08-06): Solid Queue/Cache/Cable also moved to Postgres rather than staying on SQLite files, for one database technology everywhere rather than a mixed setup. See step 4.
- **Local dev Postgres**: existing Homebrew `postgresql@16` service (decided 2026-08-06), not a Docker container — the local Rails app runs directly via `bin/dev`, not containerized, so Docker wouldn't actually mirror prod any more closely than Homebrew does; Homebrew is one less moving part.

Research (2026-08-03) confirmed: Rails 8.1.3 is current stable; SQLite + Tailwind (via `tailwindcss-rails`, no Node needed) are `rails new` defaults; a production Dockerfile and `config/deploy.yml` (Kamal 2) are generated **by default** since Rails 8.0 (no flags needed to get them); Rails 8's "Solid" stack removes the need for the old app's `redis` gem; SQLite files default to `storage/`, matching Kamal's default named-volume config. (Superseded 2026-08-04 for the primary DB, and 2026-08-06 for Solid Queue/Cache/Cable too — see step 4 — no SQLite remains in production.)

## Plan

### 1. Local toolchain — done

Ruby 4.0.6 installed via mise, pinned in `.tool-versions`. Rails 8.1.3 gem installed. Docker Desktop installed and running.

### 2. Generate the Rails app — done

```bash
rails new . --database=sqlite3 --css=tailwind --skip-test
bundle add rspec-rails --group "development,test" --version "~> 8.0"
bundle add factory_bot_rails --group test
bin/rails generate rspec:install
```

Kept the default-generated `Dockerfile` and `config/deploy.yml`. `bin/dev` boots the app on `:3000`.

### 3. Git + GitHub — done

Repo is `sharkby7e/knights_tour`, public, pushed to `main`.

### 4. Switch primary database to Postgres — done

Used Rails' built-in `bin/rails db:system:change --to=postgresql` rather than hand-editing the gem/Dockerfile/`database.yml` — it handles all three consistently (swapped the `sqlite3` gem for `pg`, swapped the Dockerfile's `sqlite3` apt package for `postgresql-client` in the runtime stage and added `libpq-dev` to the build stage, rewrote `config/database.yml` for the `postgresql` adapter). Since the All-Postgres decision (see above) was made, the generated `production` block already came out with four separate databases — `primary`, `cache`, `queue`, `cable` — matching Solid Queue/Cache/Cable's existing multi-db split, just on Postgres instead of SQLite files.

Two things the generator didn't get right, fixed by hand:
- The generated `production` block had no `host`/`port` — it would've tried a local Unix socket, which can't reach the separate Kamal Postgres accessory container. Added `host: <%= ENV["DB_HOST"] %>` / `port: <%= ENV.fetch("DB_PORT") { 5432 } %>`.
- Renamed the generated password env var (`KNIGHTS_TOUR_DATABASE_PASSWORD`) to `POSTGRES_PASSWORD`, and read the username from `POSTGRES_USER`, to match the naming the official `postgres` Docker image itself uses — so step 8's Kamal accessory env and `config/database.yml` share the same var names instead of needing translation.

Also trimmed the generic Rails-boilerplate comments `db:system:change` adds to `database.yml` (driver install instructions, `DATABASE_URL` explainer, etc.) — kept only the one comment that's an actual warning specific to real behavior (`db:test:prepare`/`rake` clobbering the test DB from dev).

**Open item for step 8**: the official `postgres` Docker image's `POSTGRES_DB` env var only creates *one* database on first boot, but production now needs four (`knights_tour_production{,_cache,_queue,_cable}`). The accessory will need a `docker-entrypoint-initdb.d` init script (or equivalent) to create all four — not solved yet, revisit when writing step 8's `deploy.yml`. The `knights_tour_storage` named volume in the step 8 draft below was for SQLite-backed Solid Queue/Cache/Cable files — no longer needed now that everything's on Postgres; drop it when we get there.

**Unrelated blocker hit and fixed along the way**: an already-on-`main` dependabot commit (`9ccbb53`, bumping `image_processing` 1.14.0 → 2.0.2) turned out to drop that gem's implicit `ruby-vips` dependency, so `bin/rails` couldn't boot *at all* (any command, not just db-related ones) until fixed — added `gem "ruby-vips", "~> 2.0"` to the Gemfile explicitly. That in turn needed the native `libvips` system library, present in the Docker image via `apt` but missing on the Mac — `brew install vips` fixed local dev. The app doesn't actually use Active Storage/file uploads; Rails just wires it up by default and requires it at boot regardless.

Verified: local Homebrew Postgres running, `bin/rails db:create db:migrate` created `knights_tour_development`/`knights_tour_test` (no migrations yet — expected, game logic isn't ported until step 5), `bundle exec rspec` passes (0 examples, still empty), `bin/rails runner` confirms `ActiveRecord::Base.connection.adapter_name` is `PostgreSQL`, a standalone `bin/rails server` boots and serves `/up` as 200 with no SQLite errors, and `docker build` succeeds end-to-end (confirms the `libpq-dev`/`postgresql-client` Dockerfile changes are correct, not just the local Homebrew path).

Separately noticed, not fixed (out of scope for this step, pre-existing): `bin/dev`'s `css` process (`bin/rails tailwindcss:watch`) exits immediately instead of staying in watch mode, which makes foreman tear down the whole `bin/dev` process group. Unrelated to the Postgres switch — worth a look before step 5's UI work, since watch mode not working makes Tailwind iteration slower.

### 5. Port the game logic, lightly cleaned — done (not yet committed)

Reference files in the old app: `~/lab/knights_tour_ruby/app/helpers/move_finder.rb`, `~/lab/knights_tour_ruby/app/controllers/squares_controller.rb`, `~/lab/knights_tour_ruby/app/models/square.rb`, `~/lab/knights_tour_ruby/app/views/squares/index.html.erb` + `_square.html.erb`, `~/lab/knights_tour_ruby/app/views/layouts/application.html.erb`, `~/lab/knights_tour_ruby/config/routes.rb`, `~/lab/knights_tour_ruby/db/schema.rb` + `db/seeds.rb`, `~/lab/knights_tour_ruby/spec/helpers/move_finder_spec.rb`, `~/lab/knights_tour_ruby/spec/controllers/squares_controller_spec.rb`, `~/lab/knights_tour_ruby/spec/factories.rb`. All already read once this session — full contents were fetched, so re-reading should be quick to confirm nothing changed.

New app layout:
- `app/models/square.rb` — trimmed AR model (`x`, `y`, `has_knight`, `has_been_visited`), no `legal_moves` (the old hardcoded/dead stub is dropped). Needs a migration (old schema: `x:integer, y:integer, has_knight:boolean default false, has_been_visited:boolean default false`).
- `app/services/move_finder.rb` — port verbatim; correct and already unit-tested (`MOVE_SET` of 8 knight deltas, filters off-board). Moving it out of `app/helpers/` into `app/services/` fixes its misplacement.
- `app/services/knight_tour_game.rb` — **new** consolidation object owning what's currently split across controller + view: `legal_moves_from(square)`, `visit!(square)`, `reset!`, `visited_count`, `won?` (`visited_count == 64`), `stuck?(current_square)`. Controller and view both read from this instead of each computing their own piece.
- `app/controllers/squares_controller.rb` — `index` only (drop the unused `show`). Thin: builds/loads the game, branches on `params[:location].blank?`, assigns ivars from `@game`'s query methods.
- Views — port the Tailwind grid markup from `index.html.erb` + `_square.html.erb`, replace the inline `@visited_squares == 64 ? ... : ...` win-text ternary with `@game.won?`. Do NOT add the CDN `<script src="https://cdn.tailwindcss.com">` tag — the new app's `--css=tailwind` pipeline already covers this via `stylesheet_link_tag` in the generated layout.
- Delete/skip: `app/javascript/controllers/hello_controller.js` (+ its registration in `index.js`) — default Stimulus scaffold, not needed (pure Turbo Drive link navigation, no custom JS). Do NOT port `HomeController`, `home/*` views, `squares/show.html.erb`, or the `scratches/` files — all confirmed dead in the old app.
- No `redis` gem needed — Rails 8's Solid Queue/Cache/Cable (SQLite-backed) covers it, and the new app was generated without it.

Specs (RSpec only):
- `spec/factories.rb` — port as-is (note: old factory has `x { '1' }, y { '1' }` as strings despite the column being integer — fine to keep or fix to integers).
- `spec/services/move_finder_spec.rb` — port from `spec/helpers/move_finder_spec.rb`. Note the old file has a copy-paste bug: two "filters out..." examples both assert `eq [[2, 8]]` even though they stub different candidate arrays — fix this when porting rather than carrying the bug forward.
- `spec/services/knight_tour_game_spec.rb` — **new**, covers `visit!`, visited-filtering, `won?`, `stuck?`, `reset!` — this is logic that was previously split and untested as a unit.
- `spec/requests/squares_spec.rb` — port from `spec/controllers/squares_controller_spec.rb` (already request-style).

Explicitly out of scope for this pass (call this out, don't silently half-do it): `Square` stays a single global 64-row board with no per-session/per-user scoping — same limitation as today, deferred to the later remodel.

Built pretty much as planned above, with a few deviations found along the way:

- `KnightTourGame` ended up with the "clear every square's `has_knight`" side effect folded into `visit!` itself (`Square.update_all(has_knight: false)` at the top, then set the target square), rather than as a constructor side effect — keeps `KnightTourGame.new` a plain no-op PORO build. `reset!` clears both `has_knight` and `has_been_visited` in one `update_all`. Final method set matches the plan: `visit!(x:, y:)`, `legal_moves_from(square)`, `visited_count`, `won?`, `stuck?(square)`, `reset!`.
- `SquaresController#index` is exactly the thin branch-on-`params[:location].blank?` shape the plan described, assigning ivars from `@game`'s query methods.
- `spec/factories.rb` — fixed `x`/`y` to integers (`{ 1 }`) rather than carrying forward the old string factory.
- `spec/services/move_finder_spec.rb` — fixed the copy-paste bug: the "filters out moves with a coord less than 1" example now correctly asserts `eq []` (all three stubbed candidates `[[0, 6], [-1, 3], [2, -1]]` fail the `.positive?` check on at least one coordinate), instead of the old file's copy-pasted `eq [[2, 8]]`.
- `spec/requests/squares_spec.rb` uses `assigns[:...]`, ported verbatim from the old controller spec's assertions. That needs the `rails-controller-testing` gem (extracted out of rspec-rails core; the old app already depended on it) — added it to the `test` group. Considered rewriting the spec to assert on rendered HTML/DB state instead so we wouldn't need the extra gem, but decided to keep it matching the old app exactly.
- `spec/support/factory_bot.rb` ported as-is (`config.include FactoryBot::Syntax::Methods`), and `spec/rails_helper.rb`'s commented-out support-glob require line got uncommented so it actually loads.

Two real bugs surfaced during manual testing (not present in the old SQLite-backed app), both fixed:
1. **Board rendered in the wrong visual position after a move.** `Square.all` has no `ORDER BY`, and unlike SQLite (which reliably returns rows in insertion/rowid order), Postgres makes no such guarantee — confirmed by querying `Square.all` before/after an `update_all` and seeing the same non-insertion-order row sequence both times. Since the grid's row-major CSS layout (`grid-rows-8 grid-cols-8`) depends on iteration order matching the seeded rank/file layout, this silently misplaced the knight/visited highlighting relative to the clicked square. Fixed by querying `Square.order(y: :desc, x: :asc)` explicitly in the controller instead of `Square.all`.
2. **Hovering "Restart" reset the board without a click.** Turbo 8 (this app's Turbo version) preloads links on hover by default, firing a real GET to `squares_path` — which `SquaresController#index` treats as a fresh visit (`params[:location].blank?` → `@game.reset!`). The per-square links already had `data-turbo-prefetch="false"` on their wrapper (carried over from the old app), which happened to also suppress this for board moves, but the Restart/Congrats link never had that attribute — a gap that didn't bite in the old app's Turbo 7 setup, where hover-preload wasn't on by default. Fixed by adding `data: { turbo_prefetch: false }` to just that `link_to` call.

Verified: `bundle exec rspec` passes (17 examples, 0 failures) covering `MoveFinder`, `KnightTourGame`, and the `squares#index` request spec. Manually played a full game via `bin/dev` in the browser — knight placement, legal-move highlighting, the visited counter, a win state, and a stuck/dead-end state all render correctly after the two fixes above; confirmed hovering Restart no longer wipes the board.

Not yet done: nothing in this repo has been `git add`/committed yet — working tree has the new/modified files from this step sitting uncommitted on `port-game-logic`.

### 6. Docker verification (local, before touching Hetzner) — done

One correction to the plan's example commands: the generated Dockerfile `EXPOSE`s port 80, not 3000 — Thruster (`bin/thrust`) listens on 80 inside the container and reverse-proxies to Puma on its default internal port 3000 (`config/puma.rb`). So the port mapping is `-p 3000:80` (host:container), not `-p 3000:3000`.

```bash
docker build -t knights_tour .

docker network create knights_tour_net
docker run -d --name knights_tour_postgres --network knights_tour_net \
  -e POSTGRES_USER=knights_tour -e POSTGRES_PASSWORD=<local-test-password> \
  -e POSTGRES_DB=knights_tour_production \
  postgres:17

docker run -d --name knights_tour_app --network knights_tour_net -p 3000:80 \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e DB_HOST=knights_tour_postgres -e DB_PORT=5432 \
  -e POSTGRES_USER=knights_tour -e POSTGRES_PASSWORD=<local-test-password> \
  knights_tour
```

Resolved the step 4 "open item" about the official `postgres` image's `POSTGRES_DB` only creating one database on first boot: no init script needed. `bin/docker-entrypoint` runs `bin/rails db:prepare` before booting the server, and Rails' multi-database `db:prepare` connects as the (superuser) `POSTGRES_USER` and creates every configured database that doesn't exist yet — confirmed via container logs: `Created database 'knights_tour_production_cache'`, `_queue`, `_cable` (the primary `knights_tour_production` already existed from the postgres image's own `POSTGRES_DB` bootstrap). `db:prepare` also ran `db:seed` automatically since the databases were freshly created — confirmed `Square.count` was 64 with no separate seed step needed.

Verified: `docker build` succeeds; `curl http://localhost:3000/up` → 200; a simulated move (`curl 'http://localhost:3000/squares?location%5Bx%5D=1&location%5By%5D=1'`) rendered the knight glyph, the correct two legal-move links (`(2,3)` and `(3,2)`), and a visited count of 1. User confirmed manually in the browser at `http://localhost:3000` that the containerized app renders and plays correctly, matching the native `bin/dev` version from step 5.

### 7. Hetzner VPS — done

Detoured through both DigitalOcean and Hetzner's ARM line before landing here — worth recording since it's not obvious from the final state:

- Tried DigitalOcean first (cost concern about Hetzner's up-front account credit requirement for new accounts, which read as unexpectedly "predatory" friction). DO's cheapest tier (512MB RAM, $4/mo) was rejected as too small to safely run Rails+Puma+Postgres+Solid Queue together; the viable DO tier was $12/mo for 2GB.
- Switched back to Hetzner. The plan's original ARM pick (CAX11) had no capacity available at signup time; the x86 CX23 (4GB, $6.49/mo) was also unavailable moments later, only CPX12 (x86, 2GB, $13.49/mo — Hetzner's shared-vCPU line) showed up as available. Rather than keep fighting availability across two providers, and since Hetzner required (and got) a prepaid credit deposit already, stuck with Hetzner and took whatever server type was actually available.
- Final server: Hetzner CPX12, `eu-central` (Falkenstein), Ubuntu 26.04 LTS (not 24.04 — that's simply what Hetzner's image list currently defaults to), 2 vCPU / ~2GB usable RAM, x86_64. **Public IP: `62.238.111.24`.**
- Confirmed via direct SSH before touching Kamal: `docker version 29.7.2` was already present (likely from an earlier partial `kamal setup` bootstrap run — see step 8), non-interactive SSH `$PATH` includes `/usr/bin` correctly.

2GB RAM (rather than the plan's original 4GB target) is fine for this app — it's a small single-page game with minimal traffic, no heavy background job load.

### 8. Kamal 2 config — done

Actual `config/deploy.yml` differs from the plan's draft in a few ways, captured here since the draft above is now superseded:

- `builder.arch: amd64` (not `arm64`) — the CPX12 box is x86_64.
- No `volumes:` block for `knights_tour_storage` — dropped entirely rather than carried forward commented-out, since the All-Postgres decision (step 4) means nothing needs a SQLite-backed volume.
- `accessories.postgres.host` and `servers.web` both point at the real IP `62.238.111.24` (not a placeholder).
- Otherwise matches the draft: `ghcr.io` registry under `sharkby7e`, `proxy.app_port: 3000` with no `host:`/`ssl:` keys (raw-IP access, no domain yet), `DB_HOST: knights_tour-postgres` for the accessory's internal Docker network hostname, Postgres 17 accessory with a `data:/var/lib/postgresql/data` named volume.
- Did not add the optional `pg-backup` accessory — still not blocking, still open for later.

**Secrets — ended up on 1Password, not plain env exports.** The plan's draft assumed `export KAMAL_REGISTRY_PASSWORD=...` / `export POSTGRES_PASSWORD=...` in the shell before each `kamal` command. That's what was used for the actual `kamal setup` run, but both values got pasted into the terminal in a way that landed in this session's transcript — treated as burned afterward (GHCR PAT revoked and rotated; Postgres password left as-is since it's not externally exposed, only used internally on the box). Switched `.kamal/secrets` to 1Password instead, to avoid repeating that exposure on every future `kamal` command:

```
SECRETS=$(kamal secrets fetch --adapter 1password --account my --from Private/knights_tour KAMAL_REGISTRY_PASSWORD POSTGRES_PASSWORD)
KAMAL_REGISTRY_PASSWORD=$(kamal secrets extract KAMAL_REGISTRY_PASSWORD ${SECRETS})
POSTGRES_PASSWORD=$(kamal secrets extract POSTGRES_PASSWORD ${SECRETS})
RAILS_MASTER_KEY=$(cat config/master.key)
```

Setup: 1Password CLI (`op`, installed via `brew install --cask 1password-cli`) with the app's Settings → Developer → "Integrate with 1Password CLI" toggle on; account shorthand is `my` (from `my.1password.com`); secrets live in a Secure Note titled `knights_tour` in the `Private` vault, with two concealed custom fields labeled exactly `KAMAL_REGISTRY_PASSWORD` and `POSTGRES_PASSWORD` (field labels are looked up verbatim/case-sensitive by `kamal secrets extract`). `RAILS_MASTER_KEY` stayed on the file-read approach — no reason to move it to 1Password since `config/master.key` already covers it. Verified `kamal config` resolves fully with zero manually-exported env vars.

One hiccup during the actual `kamal setup` run: an early step failed with `Running docker -v on 62.238.111.24` / exit status 127 (command not found). Diagnosed by SSHing in directly — Docker turned out to already be installed and working fine (PATH was correct too), so this reads as a timing artifact from Kamal's own bootstrap-then-check sequence rather than a real problem. Re-running `kamal setup` completed successfully past that point.

Subsequent deploys: `bin/kamal deploy`. Debugging: `bin/kamal app logs`, `bin/kamal app details`, `bin/kamal proxy logs`, `bin/kamal accessory logs postgres`. Console/db access: `bin/kamal console` (Rails console), `bin/kamal dbc` (psql via `rails dbconsole`), `bin/kamal shell` (raw shell) — all three exec into the live container, no separate credentials needed beyond what `.kamal/secrets` already resolves.

### 9. Verify end-to-end — done

`curl http://62.238.111.24/up` → 200, homepage → 200, `kamal app details` / `kamal accessory details postgres` both show healthy running containers. User confirmed manually in the browser that the live app is reachable and playable.
