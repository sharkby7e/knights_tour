# Progress

- [x] 1. Local toolchain (Ruby 4.0.6 via mise, Rails 8.1.3, Docker Desktop)
- [x] 2. Generate Rails app (SQLite, Tailwind, RSpec added, `--skip-test`)
- [x] 3. Git init + push to `sharkby7e/knights_tour` on GitHub
- [x] README written for local dev setup
- [x] 4. Switch primary database from SQLite to Postgres
- [ ] 5. Port the game logic, lightly cleaned (Square model, `app/services/move_finder.rb`, new `app/services/knight_tour_game.rb`, thin `SquaresController`, views, specs) — **not started, next step**
- [ ] 6. Docker verification (local build/run before touching Hetzner)
- [ ] 7. Hetzner VPS provisioning (user does this manually)
- [ ] 8. Kamal 2 config + first deploy (includes Postgres accessory)
- [ ] 9. End-to-end verification of the deployed app

Pick up at step 5 (port game logic), on the `port-game-logic` branch (already created and checked out as of 2026-08-06, no commits on it yet). The reference files to port from live in the old app at `~/lab/knights_tour_ruby` (see paths below).

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

### 5. Port the game logic, lightly cleaned

Reference files in the old app: `~/lab/knights_tour_ruby/app/helpers/move_finder.rb`, `~/lab/knights_tour_ruby/app/controllers/squares_controller.rb`, `~/lab/knights_tour_ruby/app/models/square.rb`, `~/lab/knights_tour_ruby/app/views/squares/index.html.erb` + `_square.html.erb`, `~/lab/knights_tour_ruby/app/views/layouts/application.html.erb`, `~/lab/knights_tour_ruby/config/routes.rb`, `~/lab/knights_tour_ruby/db/schema.rb` + `db/seeds.rb`, `~/lab/knights_tour_ruby/spec/helpers/move_finder_spec.rb`, `~/lab/knights_tour_ruby/spec/controllers/squares_controller_spec.rb`, `~/lab/knights_tour_ruby/spec/factories.rb`. All already read once this session — full contents were fetched, so re-reading should be quick to confirm nothing changed.

New app layout:
- `app/models/square.rb` — trimmed AR model (`x`, `y`, `has_knight`, `has_been_visited`), no `legal_moves` (the old hardcoded/dead stub is dropped). Needs a migration (old schema: `x:integer, y:integer, has_knight:boolean default false, has_been_visited:boolean default false`).
- `app/services/move_finder.rb` — port verbatim; correct and already unit-tested (`MOVE_SET` of 8 knight deltas, filters off-board). Moving it out of `app/helpers/` into `app/services/` fixes its misplacement.
- `app/services/knight_tour_game.rb` — **new** consolidation object owning what's currently split across controller + view: `legal_moves_from(square)`, `visit!(square)`, `reset!`, `visited_count`, `won?` (`visited_count == 64`), `stuck?(current_square)`. Controller and view both read from this instead of each computing their own piece.
- `app/controllers/squares_controller.rb` — `index` only (drop the unused `show`). Thin: builds/loads the game, branches on `params[:location].blank?`, assigns ivars from `@game`'s query methods.
- Views — port the Tailwind grid markup from `index.html.erb` + `_square.html.erb`, replace the inline `@visited_squares == 64 ? ... : ...` win-text ternary with `@game.won?`. Do NOT add the CDN `<script src="https://cdn.tailwindcss.com">` tag — the new app's `--css=tailwind` pipeline already covers this via `stylesheet_link_tag` in the generated layout.
- Delete/skip: `app/javascript/controllers/hello_controller.js` (+ its registration in `index.js`) — default Stimulus scaffold, not needed (pure Turbo Drive link navigation, no custom JS). Do NOT port `HomeController`, `home/*` views, `squares/show.html.erb`, or the `scratches/` files — all confirmed dead in the old app.
- No `redis` gem needed — Rails 8's Solid Queue/Cache/Cable (now Postgres-backed, see step 4) covers it, and the new app was generated without it.

Specs (RSpec only):
- `spec/factories.rb` — port as-is (note: old factory has `x { '1' }, y { '1' }` as strings despite the column being integer — fine to keep or fix to integers).
- `spec/services/move_finder_spec.rb` — port from `spec/helpers/move_finder_spec.rb`. Note the old file has a copy-paste bug: two "filters out..." examples both assert `eq [[2, 8]]` even though they stub different candidate arrays — fix this when porting rather than carrying the bug forward.
- `spec/services/knight_tour_game_spec.rb` — **new**, covers `visit!`, visited-filtering, `won?`, `stuck?`, `reset!` — this is logic that was previously split and untested as a unit.
- `spec/requests/squares_spec.rb` — port from `spec/controllers/squares_controller_spec.rb` (already request-style).

Explicitly out of scope for this pass (call this out, don't silently half-do it): `Square` stays a single global 64-row board with no per-session/per-user scoping — same limitation as today, deferred to the later remodel. Moves also stay full-page navigations with `params[:location]` in the URL, same as the old app — replacing this with Turbo Streams/Frames (move without a full reload) is a real interaction redesign the user wants eventually, not a straight port, so it's deferred to its own later pass rather than folded into this one.

### 6. Docker verification (local, before touching Hetzner)

```bash
docker build -t knights_tour .
docker run --rm -p 3000:3000 -e RAILS_MASTER_KEY=$(cat config/master.key) knights_tour
```

Open `http://localhost:3000` — confirm the board renders, a move can be made, legal squares highlight, a win and a stuck/dead-end state both display. Hit `http://localhost:3000/up` for the health check. Since Postgres is now the primary DB, also confirm the containerized app can actually reach a Postgres instance (local `docker run postgres` container on the same Docker network, or equivalent) — this is the first point where a missing `libpq` runtime lib in the Dockerfile (see step 4) would surface.

### 7. Hetzner VPS (user provisions this manually — real billable infra, not something to automate)

Via the Hetzner Cloud console:
1. Add a local SSH public key to the project.
2. Create a server — CAX11 (ARM, ~€4-5/mo, EU regions only — matches Apple Silicon for fast local builds) if an EU region works, otherwise CX22 (x86) in a US region.
3. Ubuntu 24.04 LTS image; attach the SSH key; skip password auth.
4. Note the server's public IP; confirm `ssh root@<ip>` works.

### 8. Kamal 2 config

Edit the generated `config/deploy.yml`, adding a Postgres accessory (pattern from https://rameerez.com/kamal-tutorial-how-to-deploy-a-postgresql-rails-app/):

```yaml
service: knights_tour
image: sharkby7e/knights_tour

servers:
  web:
    - <HETZNER_SERVER_IP>

proxy:
  app_port: 3000
  # no `host:` (no domain yet); do NOT set `ssl:` at all — a `false` boolean
  # in the proxy section is a known Kamal bug, omitting the key is correct here

registry:
  server: ghcr.io
  username: sharkby7e
  password:
    - KAMAL_REGISTRY_PASSWORD

builder:
  arch: arm64   # amd64 if the server ended up being a CX (x86) instead

env:
  clear:
    DB_HOST: knights_tour-postgres
    POSTGRES_USER: knights_tour
    POSTGRES_DB: knights_tour_production
  secret:
    - RAILS_MASTER_KEY
    - POSTGRES_PASSWORD

accessories:
  postgres:
    image: postgres:17
    host: <HETZNER_SERVER_IP>   # same host as the web server (single-VPS setup)
    env:
      clear:
        POSTGRES_USER: knights_tour
        POSTGRES_DB: knights_tour_production
      secret:
        - POSTGRES_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
    # app <-> postgres traffic stays on Kamal's internal Docker network,
    # not exposed publicly — no `port:` needed unless we want a local psql
    # tunnel later (e.g. `port: "127.0.0.1:5432:5432"`)

volumes:
  - "knights_tour_storage:/rails/storage"   # only needed if Solid Queue/Cache/Cable
                                              # stay on SQLite (mixed-adapter route,
                                              # see step 4) — drop this entirely if
                                              # everything moves to Postgres. Docker-
                                              # managed named volume — keep this exact
                                              # form, do not convert to a host bind-mount
                                              # (a reversed bind-mount path is a
                                              # documented cause of SQLite data loss
                                              # on redeploy)
```

`.kamal/secrets` (committed; references env vars, not literal secrets):
```
RAILS_MASTER_KEY=$(cat config/master.key)
KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
```

Consider a separate `pg-backup` accessory (same article) for automated Postgres backups once the base deploy works — not blocking the first deploy.

Create a **classic** GitHub PAT with `write:packages` scope (GHCR doesn't support fine-grained PATs, and `gh`'s own OAuth token won't have this scope) at github.com/settings/tokens/new, then generate a Postgres password and set both:

```bash
export KAMAL_REGISTRY_PASSWORD=ghp_xxxxxxxxxxxx
export POSTGRES_PASSWORD=$(openssl rand -hex 32)   # save this — needed for future kamal commands too
kamal setup      # first deploy: installs Docker on the server, builds/pushes
                  # the image, boots the postgres accessory, sets up kamal-proxy,
                  # deploys, runs migrations
```

Subsequent deploys: `kamal deploy`. Debugging: `kamal app logs`, `kamal app details`, `kamal proxy logs`, `kamal accessory logs postgres`.

### 9. Verify end-to-end

```bash
curl -I http://<HETZNER_SERVER_IP>/up   # expect 200
open http://<HETZNER_SERVER_IP>/
```

Play a full game in the browser: place the knight, chain legal moves, confirm the visited counter, confirm both the win state and a dead-end/stuck state render correctly. Run `kamal app boot` and reload to confirm the Postgres-backed board survives (data lives in the `postgres` accessory's `data` volume, independent of app container restarts).
