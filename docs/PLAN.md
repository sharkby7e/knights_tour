# Progress

- [x] 1. Local toolchain (Ruby 4.0.6 via mise, Rails 8.1.3, Docker Desktop)
- [x] 2. Generate Rails app (SQLite, Tailwind, RSpec added, `--skip-test`)
- [x] 3. Git init + push to `sharkby7e/knights_tour` on GitHub
- [x] README written for local dev setup
- [ ] 4. Port the game logic, lightly cleaned (Square model, `app/services/move_finder.rb`, new `app/services/knight_tour_game.rb`, thin `SquaresController`, views, specs) — **in progress, not started writing files yet**
- [ ] 5. Docker verification (local build/run before touching Hetzner)
- [ ] 6. Hetzner VPS provisioning (user does this manually)
- [ ] 7. Kamal 2 config + first deploy
- [ ] 8. End-to-end verification of the deployed app

Pick up at step 4. The reference files to port from live in the old app at `~/lab/knights_tour_ruby` (see paths below).

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

Research (2026-08-03) confirmed: Rails 8.1.3 is current stable; SQLite + Tailwind (via `tailwindcss-rails`, no Node needed) are `rails new` defaults; a production Dockerfile and `config/deploy.yml` (Kamal 2) are generated **by default** since Rails 8.0 (no flags needed to get them); Rails 8's "Solid" stack removes the need for the old app's `redis` gem; SQLite files default to `storage/`, matching Kamal's default named-volume config.

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

### 4. Port the game logic, lightly cleaned — NEXT STEP

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

### 5. Docker verification (local, before touching Hetzner)

```bash
docker build -t knights_tour .
docker run --rm -p 3000:3000 -e RAILS_MASTER_KEY=$(cat config/master.key) knights_tour
```

Open `http://localhost:3000` — confirm the board renders, a move can be made, legal squares highlight, a win and a stuck/dead-end state both display. Hit `http://localhost:3000/up` for the health check.

### 6. Hetzner VPS (user provisions this manually — real billable infra, not something to automate)

Via the Hetzner Cloud console:
1. Add a local SSH public key to the project.
2. Create a server — CAX11 (ARM, ~€4-5/mo, EU regions only — matches Apple Silicon for fast local builds) if an EU region works, otherwise CX22 (x86) in a US region.
3. Ubuntu 24.04 LTS image; attach the SSH key; skip password auth.
4. Note the server's public IP; confirm `ssh root@<ip>` works.

### 7. Kamal 2 config

Edit the generated `config/deploy.yml`:

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
  secret:
    - RAILS_MASTER_KEY

volumes:
  - "knights_tour_storage:/rails/storage"   # Docker-managed named volume —
                                              # keep this exact form, do not
                                              # convert to a host bind-mount
                                              # (a reversed bind-mount path is
                                              # a documented cause of SQLite
                                              # data loss on redeploy)
```

`.kamal/secrets` (committed; references env vars, not literal secrets):
```
RAILS_MASTER_KEY=$(cat config/master.key)
KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
```

Create a **classic** GitHub PAT with `write:packages` scope (GHCR doesn't support fine-grained PATs, and `gh`'s own OAuth token won't have this scope) at github.com/settings/tokens/new, then:

```bash
export KAMAL_REGISTRY_PASSWORD=ghp_xxxxxxxxxxxx
kamal setup      # first deploy: installs Docker on the server, builds/pushes
                  # the image, sets up kamal-proxy, deploys, runs migrations
```

Subsequent deploys: `kamal deploy`. Debugging: `kamal app logs`, `kamal app details`, `kamal proxy logs`.

### 8. Verify end-to-end

```bash
curl -I http://<HETZNER_SERVER_IP>/up   # expect 200
open http://<HETZNER_SERVER_IP>/
```

Play a full game in the browser: place the knight, chain legal moves, confirm the visited counter, confirm both the win state and a dead-end/stuck state render correctly. Run `kamal app boot` and reload to confirm the SQLite-backed board survives via the named volume.
