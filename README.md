# Express + Next.js + iOS Boilerplate

Production-ready Express 5 + Next.js 15 monorepo template, with a native iPhone app and a companion Apple Watch app.

## Stack

```
apps/server/     Express 5 + TypeScript -- REST API, custom auth, raw SQL
apps/client/web/ Next.js 15 App Router -- React 19, SCSS Modules, TanStack Query
apps/client/ios/ SwiftUI iPhone app, Apple Watch app, AppCore Swift package, XcodeGen
packages/tokens/ Design token system (CSS custom properties + JS object)
packages/types/  Shared TypeScript types (server + web client)
packages/constants/ Shared constants (analytics event names, etc.)
```

## Prerequisites

- Node.js 22+
- pnpm 9+
- PostgreSQL (local or Neon)
- Xcode and XcodeGen (`brew install xcodegen`), only for the native apps

## Getting Started

1. Clone and install:

   ```bash
   git clone <repo> my-app
   cd my-app
   pnpm install
   ```

2. Configure the server:

   ```bash
   cp apps/server/.env.example apps/server/.env
   # Edit apps/server/.env and set DATABASE_URL and SESSION_SECRET
   ```

3. Run migrations:

   ```bash
   pnpm --filter server run migrate:up
   ```

4. Start development servers:
   ```bash
   pnpm dev
   ```

API runs at `http://localhost:3001`, web client at `http://localhost:3000`.

## Run all four pieces

The four pieces are Postgres, the server, the web app, and the native apps (iPhone plus Watch). The native apps need macOS with Xcode and XcodeGen.

1. Start Postgres. `docker-compose.yml` defines a `postgres` service (`postgres:16-alpine`, port 5432) that you can start on its own:

   ```bash
   docker compose up -d postgres
   ```

   When you create `apps/server/.env` in step 2, set `DATABASE_URL` to a Postgres connection URL built from five parts: the scheme `postgresql`, the user, the password, the host and port `localhost:5432`, and the database name. The user, password, and database name are the `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` values in `docker-compose.yml`. The same URL with its real values is in the `e2e` job of `.github/workflows/ci.yml`, under `DATABASE_URL`, with a different database name. The host is `localhost` because the server runs on your machine, not inside Compose. Also set `SESSION_SECRET` in `apps/server/.env`. The server requires `DATABASE_URL` and `SESSION_SECRET` and refuses to start without them. A Postgres you already run locally works as well.

2. Install, configure, and migrate as in Getting Started steps 1 to 3 (`pnpm install`, copy `apps/server/.env.example` to `apps/server/.env`, `pnpm --filter server run migrate:up`).
3. Start the server and web app:

   ```bash
   pnpm dev
   ```

4. Generate the Xcode project:

   ```bash
   pnpm ios:generate
   ```

5. Open `apps/client/ios/TemplateApp.xcodeproj` in Xcode. Run the `App` scheme on an iPhone simulator that is paired with a Watch simulator. The Watch app is embedded in the iPhone app, so this installs both. Debug builds call `http://localhost:3001`.
6. Open the Watch app on the Watch simulator. It shows "Hello, world" until a card arrives.
7. On the phone, register, then tap "Send message". The card appears on the phone and on the Watch.
8. Log out on the phone. The Watch returns to "Hello, world".

If no Watch is paired, the card shows on the phone with the note "No Apple Watch available. The card is shown here only."

## Start a new app from this template

Change three values, then run `pnpm ios:generate`:

1. The project `name` in `apps/client/ios/project.yml`.
2. The bundle id `com.example.templateapp`. Replace every `com.example` in `project.yml`: `bundleIdPrefix`, `PRODUCT_BUNDLE_IDENTIFIER` for `App`, `WatchApp`, and `AppUITests`, and `INFOPLIST_KEY_WKCompanionAppBundleIdentifier`. Keep the Watch id equal to the phone id plus `.watchkitapp`, the UI test id equal to the phone id plus `.uitests`, and the companion key equal to the phone id.
3. `API_BASE_URL` in `apps/client/ios/Config/Debug.xcconfig` and `apps/client/ios/Config/Release.xcconfig`.

Release builds fail unless `API_BASE_URL` in `Release.xcconfig` starts with `https://`.

## Not included

- TestFlight or App Store delivery
- Push notifications
- In-app purchase
- A Watch app that works without the phone
- Password reset screens on the phone

CI runs the `ios` job on a macOS runner only when files under `apps/client/ios/` or the workflow change. macOS runner minutes are free for public repositories and billed at a higher rate for private ones.

## Environment Variables

| Variable           | Required | Default                 | Description                                                               |
| ------------------ | -------- | ----------------------- | ------------------------------------------------------------------------- |
| `DATABASE_URL`     | Yes      | --                      | PostgreSQL connection string                                              |
| `SESSION_SECRET`   | Yes      | --                      | Secret for signing session cookies (generate with `openssl rand -hex 32`) |
| `NODE_ENV`         | No       | `development`           | `development` or `production`                                             |
| `PORT`             | No       | `3001`                  | HTTP server port                                                          |
| `CORS_ORIGIN`      | Prod     | `http://localhost:3000` | Allowed origin for CORS (required in production)                          |
| `DATABASE_CA_CERT` | No       | --                      | PEM CA cert for SSL verification (Neon, RDS)                              |

## Deployment

### Server (Railway)

1. Create a Railway project and provision a Postgres database.
2. Link the repo and set root directory to `apps/server/`.
3. Set required env vars: `DATABASE_URL`, `SESSION_SECRET`, `CORS_ORIGIN`, `NODE_ENV=production`.
4. Run migrations before first deploy: `pnpm --filter server run migrate:up`.
5. Railway uses the `Dockerfile` `server` stage. The start script runs migrations then starts the server.

### Web Client (Railway)

1. Add a `web` service to the same Railway project as the `api`, `postgres`, and `redis` services.
2. Set the root directory to `apps/client/web/` in the Railway service settings.
3. Set `NODE_ENV=production` on the web service.
4. Set all required env vars on the web service before the first deploy (at minimum `NEXT_PUBLIC_API_URL` pointing to your Railway API URL).
5. Railway's default Next.js health check applies; no custom `/health` route is needed on the web service.

## Key Commands

```bash
pnpm dev                              # Start API + web client
pnpm build                            # Build all workspaces
pnpm test                             # Run server unit tests
pnpm test:coverage                    # Unit tests with coverage
pnpm lint                             # Lint all workspaces
pnpm format:check                     # Check formatting
pnpm ios:generate                     # Generate the Xcode project with XcodeGen
pnpm ios:test                         # Run the AppCore Swift tests
pnpm ios:test:ui                      # Run the XCUITest UI test
pnpm ios:verify-config                # Check Release needs https and ATS is Debug-only
pnpm ios:format:check                 # swift format lint

pnpm --filter server run migrate:up   # Apply migrations
pnpm --filter server run migrate:down # Roll back last migration
pnpm --filter server run test:integration
```

## Project Conventions

- Named exports only (no `export default` in non-Next.js files)
- CSRF: header-only (`X-Requested-With: XMLHttpRequest`) on all mutating requests
- Tests live in `src/__tests__/`, mirroring the source tree
- Alphabetical ordering: imports, props, type keys, union members
- Shared types go in `packages/types/` the moment two surfaces need them

See `CLAUDE.md` and the workspace-level `CLAUDE.md` files for full conventions.
