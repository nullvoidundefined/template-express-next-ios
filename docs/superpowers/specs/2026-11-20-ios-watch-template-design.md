# Design: `template-express-next-ios`

Date: 2026-11-20
Status: awaiting owner approval

## Intent

A new project template that is `template-express-next` plus a native iPhone app with a companion Apple Watch app. Cloning it gives a full stack that runs on day one: Express API, Next.js web app, iPhone app, Watch app.

Why: future apps will have a phone and Watch surface. In some the phone mirrors the web app. In others the phone is the real product and the web app is a dashboard or marketing site. The template cannot know which, so the phone must be a complete first-class client that never depends on the web app.

## What the owner decided

- The Watch is a thin display fed by the phone. It shows messages or prompt cards. In the template it is a hello-world screen that can also show a card.
- The phone ships with sign up, log in, log out, and a home screen. The home screen has demo buttons that put a card or message on the Watch.
- The card content comes from the server. The phone asks the API for a card and forwards it to the Watch. This proves the chain server, phone, Watch.
- Structure: a new repo copied from `template-express-next`, with the native app inside it (approach 1 below).
- Everything else native (billing, uploads, push) is per-app work, not template work.

## Goals

1. One clone runs server, web, phone, and Watch locally, with the phone and Watch in simulators.
2. A user can register, log in, and log out on the phone against the existing Express auth.
3. Tapping a demo button on the phone home screen fetches a card from the server and shows it on the Watch.
4. The Watch shows a hello-world screen until its first card arrives.
5. The native code has unit tests, runs in CI, and has written conventions, at the same standard as the web side.
6. The web app and its cookie login keep working exactly as they do today.

## Non-goals

- TestFlight, App Store delivery, signing automation.
- Push notifications (APNs).
- In-app purchase or any native billing.
- A Watch app that works without the phone.
- Refresh tokens or a longer native session. The phone session lasts the existing 7 days, then the user logs in again.
- Password reset screens on the phone. The server endpoints exist; the screens are per-app work.
- Generated API clients or shared-type generators.
- Native versions of the web template's posts, billing, or admin features.
- An Android app.

## Anti-goals

- Changing how the web app logs in. The `sid` cookie stays `httpOnly`, and the session token must never appear in a response body that browser JavaScript can read by default.
- A template so heavy that a new app starts by deleting things. The native side stays small enough to read in one sitting.
- Drift between the two templates caused by refactoring copied code. Copied server and web code is changed only where this design requires it.

## Constraints

- The global and project `CLAUDE.md` rules apply: test-first, one PR per slice, one review per PR, no em dashes, named exports, alphabetical ordering, file-name suffixes for TypeScript.
- The bearer-session server change touches authentication. It is **high risk**: integration tests against a real Postgres, and the owner reads and merges that PR.
- Never disable TLS verification. The Debug build may allow plain HTTP to localhost only (`NSAllowsLocalNetworking`); Release requires HTTPS.
- No secrets or credential-shaped literals in the repo, including in Swift tests.
- Xcode 27 is installed on the owner's machine.
- The source repo is public on GitHub, so macOS CI minutes are free for the template itself. Private repos cloned from it pay the macOS multiplier.

## Approaches considered

1. **New repo copied from the web template, native app inside (chosen).** `template-express-next-ios` starts as a copy of `template-express-next` with an Xcode project at `apps/client/ios/`. One clone gives the full stack, and an API change and its phone change land in one PR. Cost: fixes to the web template are copied over by hand afterward.
2. **Add the native app to the existing template.** No second repo. Rejected: every web-only project would carry an Xcode project and macOS CI it never uses.
3. **Separate native-only repo pointed at any server.** Smallest repo. Rejected: the demo needs two clones, and the demo endpoint and the phone code that calls it drift apart.

The owner picked 1 because the phone may be the real app, so it belongs beside its server.

## Design

### Repo

- Directory: `templates/template-express-next-ios/`. GitHub: `nullvoidundefined/template-express-next-ios`, public, matching the source. Creating the GitHub repo and the first push need the owner's go-ahead when that step is reached.
- Copied from `template-express-next` at commit `448006b` with fresh git history. Not copied: `.git`, `node_modules`, build output, test reports, and these `docs/` folders: `audits/`, `issues/`, `prs/`, `session-handoff/`, `todos/`. Kept: `docs/feature-list/`, `docs/user-stories/`, `docs/recurring-bugs/`. Any link in a `CLAUDE.md` or the README that goes dead because of this is removed.
- `.github/workflows/address-copilot-review.yml` is not copied (project rule: no Copilot review).
- Layout added:

```
apps/client/ios/
  CLAUDE.md                 Swift and Xcode conventions for this workspace
  project.yml               XcodeGen project definition (the .xcodeproj is generated, not committed)
  Config/                   Debug.xcconfig, Release.xcconfig (API base URL, bundle ids)
  App/                      iPhone target
    Features/Auth/          login and register screens, auth view model
    Features/Home/          home screen, home view model
    Services/               phone side of the Watch link
  WatchApp/                 Watch target: hello-world and card screen, Watch side of the link
  Packages/AppCore/         local Swift package shared by both targets
    Sources/AppCore/        models, API client, session token store, card encoding
    Tests/AppCoreTests/
  AppUITests/               one phone UI test
```

### Server changes

**1. Bearer sessions (high risk).** Today `createLoadSession` in `apps/server/src/middleware/requireAuthMiddleware.ts` reads the session token only from the `sid` cookie, and login returns only `{ user }`.

- `loadSession` accepts the token from the `sid` cookie or from `Authorization: Bearer <token>`. Same `sessions` table, same SHA-256 hashing, same 7-day TTL. A request carrying both a `sid` cookie and a bearer header is rejected with 400, so there is never a question of which one applies. A bearer token alone, with no cookie, is a fully valid session.
- A client opts in to token transport by sending `X-Session-Transport: token`. With that header, the three places that issue a session (`register`, `login`, and the session rotation in `updateMe`) respond with `{ user, sessionToken }` and set no cookie. Without the header, behavior is byte-for-byte what it is today.
- `logout` deletes the session named by either the cookie or the bearer token.
- `updateMe` keeps its current behavior of revoking every session for the user on a password change. So a password change on the web logs the phone out, and the reverse. That is intended. The phone has no password-change screen; token transport on `updateMe` exists so the API is complete for apps that add one.
- `csrfGuard` is unchanged and still applies to bearer requests. Browsers do not attach bearer tokens on their own, so the bearer path has no CSRF exposure, but one rule for every client is simpler than an exemption. The phone sends `X-Requested-With` on every request like the web client does.
- `corsConfig` is unchanged. Native requests carry no `Origin`, and `Authorization` is already an allowed header.
- Tests: integration tests against real Postgres for bearer login, bearer `GET /auth/me`, bearer logout invalidating the token, token absent from the body without the opt-in header, and negative input (malformed header, oversized token, unknown token, expired session, cookie and bearer sent together, bearer request missing `X-Requested-With`).

**2. Demo cards endpoint (standard risk).** `POST /v1/demo/cards`, behind `requireAuth`.

All application routes are mounted under `/v1` in `apps/server/src/app.ts`; this document writes the full paths. `API_BASE_URL` on the phone is the origin only (for example `http://localhost:3001`), and the Swift client adds `/v1/...`.

- Request: `{ "kind": "message" | "prompt" }`, validated with Zod.
- Response `201`: `{ "card": { "body": string, "createdAt": string, "id": string, "kind": "message" | "prompt", "title": string } }`.
- Content is picked by the server from a short fixed list per kind. No database table, no LLM call. `id` is a fresh UUID so each card is distinct. The phone sends no `Idempotency-Key` for this call, on purpose: every tap makes a new card.
- Follows the existing layering: `demoRoutes.ts`, `demoHandler.ts`, `demoSchema.ts`, and a `demoCardService.ts` that owns the fixed list.
- `Card` and `CardKind` types are added to `packages/types/`.
- Tests: unit tests for the handler and service, one integration test through the app with auth, and negative-input tests.

### Native apps

- **UI:** SwiftUI for both targets. No third-party Swift dependencies.
- **Project file:** generated by XcodeGen from `project.yml`. Reason: the project is renamed for every new app, and a text definition makes that a three-line edit and avoids project-file merge conflicts. XcodeGen is the one new tool; it is installed with Homebrew and in CI.
- **OS targets:** one major release behind the Xcode 27 SDK for both iOS and watchOS. The builder confirms the exact numbers against the installed Xcode.
- **Shared code:** `AppCore` holds everything that is not a screen, so it is tested without a simulator UI:
  - `User` and `Card` models written by hand to match `packages/types/`. Each Swift model carries a comment naming the TypeScript file it mirrors.
  - `APIClient` protocol with a `URLSession` implementation. It adds `X-Requested-With`, `X-Session-Transport: token`, and the bearer header when a token is stored. It maps the server's error envelope to a typed Swift error.
  - `SessionTokenStore` protocol with a Keychain implementation and an in-memory implementation for tests.
  - Card encoding for the phone-to-Watch hop.
- **Phone:**
  - On launch: if a token is stored, call `GET /v1/auth/me`. Success shows Home. A 401 clears the token and shows Login.
  - A 401 on any later call does the same and shows "You were signed out. Log in again." This covers expiry and a password change made elsewhere.
  - The phone's `URLSession` is configured to store and send no cookies, so it never produces the cookie-plus-bearer case.
  - Login and Register screens with field validation matching the server schema, a visible error for each failure state, and a loading state.
  - Home shows the signed-in email, a "Send message" button, a "Send prompt card" button, the last card sent, and Log out. Each button calls `POST /v1/demo/cards`, then forwards the card to the Watch.
  - Logout calls the server, then clears the Keychain token regardless of the server result.
- **Phone to Watch:** `WatchConnectivity`, using `updateApplicationContext`. The Watch always shows the latest card, delivery survives the Watch app being closed, and no reachability handling is needed. The Watch never calls the server and never holds the session token.
- **Watch:** a companion app (not independent). Shows "Hello, world" until a card arrives, then the card's title and body. The latest card is kept across launches.
- **Configuration:** `API_BASE_URL` comes from xcconfig. Debug points at `http://localhost:3001`. Release holds a placeholder that fails the build until replaced with an HTTPS URL. Bundle ids and the app name are set in one place.
- **Accessibility:** every control has a VoiceOver label, text respects Dynamic Type, animations respect Reduce Motion, and contrast meets WCAG 2.1 AA. The UI test runs Xcode's built-in accessibility audit on Login and Home.

### Testing

- `AppCore`: Swift Testing unit tests. API client against a stubbed `URLProtocol` (success, 401, validation error, network failure, malformed body), token store, model decoding against JSON fixtures copied from real server responses, and card encoding round trip.
- View models: unit tests with a fake `APIClient` and fake Watch link.
- Phone UI: one XCUITest, login to Home to tapping a demo button, with the API stubbed through a launch argument, plus the accessibility audit.
- Watch delivery: checked by hand in paired simulators and recorded in the PR. Paired-simulator `WatchConnectivity` is not reliable enough to gate CI on.
- Server: as listed under Server changes.
- Web: existing tests unchanged and still passing.

### CI

- A new `ios` job in `.github/workflows/ci.yml` on a GitHub-hosted macOS runner. The job always starts and always reports a result, so it is safe to make a required check. Its first step detects whether `apps/client/ios/**` or the workflow file changed, and the remaining steps are skipped when they did not. Steps: install XcodeGen, generate the project, run `AppCore` and view-model tests, run the phone UI test, build the Watch target.
- Existing Linux jobs unchanged.
- CI may run an older Xcode than the owner's Xcode 27. The OS deployment targets and Swift language features are chosen so that both the local Xcode and the newest Xcode on the hosted runner image build the project. The builder checks the runner image in slice 4. If no hosted image can build and test the phone target, the builder stops and asks the owner; a self-hosted runner is not set up without the owner.
- CI needs a phone simulator only. It never needs a paired Watch simulator.

### Tooling and docs

- Formatting: `swift format`, which ships with the Xcode toolchain. A lefthook entry checks staged Swift files.
- `apps/client/ios/CLAUDE.md`: Swift conventions for this workspace (layout, naming, where tests live, state handling, the rule that the Watch never talks to the server).
- Root `CLAUDE.md` and `README.md`: add the native workspace, the new commands, and a "run all four pieces" walkthrough. The local database setup is the web template's existing one (`docker-compose.yml`, the server's migrate scripts); the phone needs nothing extra.
- `docs/feature-list/features.md` and `docs/user-stories/`: rows and stories for native auth and the demo card flow, per the repo's feature checklist.

## Suggested build order

One PR per slice. The plan may adjust this.

1. Create the repo from the copy; CI green on the unchanged web stack.
2. Server: bearer sessions (high risk, owner merges).
3. Server: demo cards endpoint and shared types.
4. Native scaffold: XcodeGen project, both targets building, `AppCore` package, `ios` CI job, Swift conventions file.
5. Phone: API client, token store, login, register, logout.
6. Phone: home screen and card fetch.
7. Watch: card display and the phone-to-Watch link.
8. Docs: README walkthrough, feature list, user stories.

## Calls made by Claude (not owner decisions)

Each can be overturned at approval.

- SwiftUI; no third-party Swift packages.
- XcodeGen instead of a committed `.xcodeproj`.
- Hand-written Swift models instead of a generator.
- Token transport by the `X-Session-Transport: token` opt-in header rather than separate native auth routes.
- A request with both a cookie and a bearer token is rejected.
- A password change anywhere logs out every device, as the server does today.
- CI may use an older Xcode than the local one.
- `updateApplicationContext` for the Watch link.
- Demo card content from a fixed server-side list, no database table.
- Native CI runs unit tests and one stubbed UI test; the real server-to-Watch chain is a manual check.
- The copy drops history docs and the Copilot review workflow.
- The new repo is public, like its source.

## Left to the builder

- Exact OS deployment targets.
- Swift type and file names inside the layout above.
- Visual design of the four screens, within the accessibility rules. Plain system styling is expected.
- The fixed card texts.
- How the UI test's stub API is wired.
