# Deploying to Railway

Railway builds from the GitHub repo using the `Dockerfile`, gives you one
Postgres (`DATABASE_URL`) and a dynamic `$PORT`. This repo is already
configured for it (`railway.toml`, `bin/railway-start`, `config/database.yml`).

## 1. Create the project
1. In Railway: **New Project → Deploy from GitHub repo** → pick the repo.
2. Railway detects the `Dockerfile` and `railway.toml` automatically.

## 2. Add Postgres
**New → Database → PostgreSQL** in the same project. Railway exposes its
connection string; reference it on the app service as the `DATABASE_URL`
variable (Railway usually wires this automatically when both are in one
project — confirm the app's Variables show `DATABASE_URL`).

> Solid Cache/Queue/Cable share this one database (no extra DBs needed).

## 3. Set environment variables (app service → Variables)

Required:
```
RAILS_MASTER_KEY     = <contents of config/master.key>   # decrypts credentials / secret_key_base
RAILS_ENV            = production
ANTHROPIC_API_KEY    = sk-ant-...                         # powers the AI tools
ADMIN_USERNAME       = admin
ADMIN_PASSWORD       = <strong password>                 # admin fails closed without this
APP_HOST             = <your-app>.up.railway.app         # mailer links
```

Google sign-in:
```
GOOGLE_CLIENT_ID     = ...
GOOGLE_CLIENT_SECRET = ...
```

Email (optional — buyer alerts + approval emails; without SMTP_ADDRESS, mail just isn't sent):
```
MAIL_FROM            = AcquireTMT <no-reply@yourdomain.com>
SMTP_ADDRESS         = smtp.postmarkapp.com
SMTP_PORT            = 587
SMTP_USERNAME        = ...
SMTP_PASSWORD        = ...
```

`DATABASE_URL` is provided by the Postgres service — don't set it by hand.

## 4. Deploy
Railway builds and runs `bin/railway-start`, which runs `db:prepare`
(migrations + seeds on the first deploy) and serves on `$PORT`. Watch the
deploy logs; the app is live at the generated `*.up.railway.app` domain
(or your custom domain).

## 5. After first deploy
- **Google OAuth:** add `https://<your-domain>/auth/google_oauth2/callback`
  to the Authorized redirect URIs in Google Cloud Console (and the JS origin
  `https://<your-domain>`).
- **Data:** the seeds insert sample deals + starter acquirers. Curate real
  ones in `/admin/acquirers` and `/admin/deals`; re-deploys won't wipe them.
- **Admin** is at `/admin/leads` (HTTP Basic with ADMIN_USERNAME/PASSWORD).

## Notes
- HTTPS is terminated by Railway; `config.assume_ssl` + `force_ssl` already
  trust the proxy, so secure cookies + redirects work.
- To run a one-off command: Railway **Service → Settings → Deploy → run**, or
  `railway run bin/rails console` with the Railway CLI.
