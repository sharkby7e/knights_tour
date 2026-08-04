# Knight's Tour

A Rails app for playing the [Knight's Tour](https://en.wikipedia.org/wiki/Knight%27s_tour) puzzle: move a knight around a chessboard, visiting every square exactly once.

## Local development

Install the Ruby version pinned in `.tool-versions` with whatever version manager you use (I use [mise](https://mise.jdx.dev/): `mise install`). Docker is only needed later, for building/deploying the production image.

```bash
bundle install
bin/rails db:prepare  # creates and migrates the database
bin/dev               # starts Rails + the Tailwind watcher (Procfile.dev)
```

Visit `http://localhost:3000`.

### Tests

```bash
bundle exec rspec
```

### Linting

RuboCop runs in CI, and there's a `pre-push` hook that runs it locally too. Enable it once per clone:

```bash
git config core.hooksPath .githooks
```

## Deployment

Deployed with [Kamal](https://kamal-deploy.org/) to a Hetzner Cloud VPS. See `config/deploy.yml`.
