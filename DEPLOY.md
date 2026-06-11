# Deploying AcquireTMT

The app deploys as a Docker container via [Kamal](https://kamal-deploy.org).
Production runs on PostgreSQL (primary + Solid cache/queue/cable databases) with
SSL terminated by the Kamal proxy.

## 1. One-time setup

Install Kamal locally (bundled): `bin/kamal version`.

Fill in the placeholders in [`config/deploy.yml`](config/deploy.yml):

| Key | Replace with |
| --- | --- |
| `image` | your registry image, e.g. `ghcr.io/acme/acquire_tmt` |
| `registry.username` | your registry user |
| `servers.web` | your server IP(s) |
| `proxy.host` | your real domain (e.g. `acquiretmt.com`) |

## 2. Secrets

Secrets are read from your shell (or a password manager) by
[`.kamal/secrets`](.kamal/secrets) and injected into the container. Export them
before deploying (see [`.env.example`](.env.example) for the full list):

```bash
export KAMAL_REGISTRY_PASSWORD=…          # registry token
export ACQUIRE_TMT_DATABASE_PASSWORD=…    # production Postgres password
export ANTHROPIC_API_KEY=sk-ant-…         # powers the AI tools
export ADMIN_USERNAME=admin               # admin HTTP Basic auth
export ADMIN_PASSWORD=…                    # MUST be strong & non-default
# RAILS_MASTER_KEY is read from config/master.key automatically
```

Better: pull them from a password manager — see the `kamal secrets fetch`
example at the top of `.kamal/secrets`.

> **Note:** `ADMIN_PASSWORD` must be set and not the default in production, or
> the admin area fails closed (returns 503) by design — see
> `Admin::BaseController`. Likewise, without `ANTHROPIC_API_KEY` the three tool
> endpoints return 503.

## 3. First deploy

```bash
bin/kamal setup
```

This builds the image, boots Postgres-backed containers, and runs
`bin/rails db:prepare` (via the Docker entrypoint), which creates the
databases, loads the schema, **and runs the seeds** — populating the sourced
comps (`Comp`) and active acquirers (`Buyer`) the tools rely on.

## 4. Subsequent deploys

```bash
bin/kamal deploy
```

`db:prepare` runs pending migrations automatically but does **not** re-seed an
existing database. When you change seed data (e.g. refreshed comps/buyer
multiples in `db/seeds.rb`), re-run the seeds — they're idempotent:

```bash
bin/kamal app exec "bin/rails db:seed"
```

## 5. Handy commands

```bash
bin/kamal logs -f                          # tail logs
bin/kamal console                          # rails console on the server
bin/kamal app exec "bin/rails db:seed"     # refresh comps/buyer data
```

## Rotating the Anthropic API key

Update `ANTHROPIC_API_KEY` in your secret store / shell, then
`bin/kamal env push && bin/kamal app boot` (or a full `bin/kamal deploy`) to
roll it out.
