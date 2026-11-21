# template-express-next-ios Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `template-express-next-ios`: the Express + Next.js template plus a native iPhone app (auth, home, demo buttons) and a companion Watch app that shows cards the phone fetches from the server.

**Architecture:** A fresh-history copy of `template-express-next` gains `apps/client/ios/`. The server learns to accept its existing session token as a bearer header and gains one demo endpoint. All native logic that is not a screen lives in a local Swift package, `AppCore`, tested with `swift test` on macOS; the two app targets hold only SwiftUI views and the WatchConnectivity glue.

**Tech Stack:** Express 5, TypeScript, Zod, Vitest, supertest, Postgres (existing). Swift, SwiftUI, Swift Testing, XCUITest, WatchConnectivity, Keychain Services, XcodeGen, `swift format`. GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-20-ios-watch-template-design.md`

## Global Constraints

- Repo root for every path below: `templates/template-express-next-ios/`.
- Each task is one PR off `main`, built with the `tdd-gated-dispatch` loop: RED tests by a fresh `test-author`, committed alone; then GREEN; one `pr-reviewer` review; squash merge. The PR body carries `**Risk:**`, `## Verification`, `## Review`.
- Task 2 is `**Risk:** high` (authentication). Integration tests run against real Postgres. The owner reads and merges it. Every other task is standard risk.
- Web behavior is unchanged: without `X-Session-Transport: token`, auth responses are byte-for-byte what they are today, and the session token never appears in a response body.
- All application routes are under `/v1`. `API_BASE_URL` on the phone is the origin only; the Swift client adds `/v1/...`.
- Server error envelope is `{ "code": string, "error": string }`.
- Session tokens are 64 lowercase hex characters.
- Server rules from the copied `CLAUDE.md` apply: file-name type suffixes, named exports only, alphabetical keys and imports, tests under `src/__tests__/`, no em dashes.
- No third-party Swift packages. XcodeGen is the only new tool. The `.xcodeproj` is generated and gitignored.
- The Watch never calls the server and never holds the session token.
- Never disable TLS verification. Debug may allow plain HTTP to localhost only (`NSAllowsLocalNetworking`). Release requires an HTTPS `API_BASE_URL`.
- No credential-shaped literals in any file, including tests. Build test passwords and tokens at run time (for example from `UUID()` or `crypto.randomBytes`).
- Accessibility: every control has a VoiceOver label, text uses Dynamic Type styles, animations respect Reduce Motion, contrast meets WCAG 2.1 AA.
- OS deployment targets: one major release behind the local Xcode 27 SDK for iOS and watchOS, and buildable by the newest Xcode on the GitHub-hosted macOS image. Task 4 fixes the exact numbers.

## Review Focus

Conditions the spec implies but does not spell out. Each has a test in the task named.

1. Phone launches with a stored token while the server is unreachable. Expected: the user is not logged out; a retry screen shows. (Task 5)
2. The server or a proxy answers with a non-JSON body (an HTML 502 page). Expected: a typed error and a readable message, no crash. (Task 5)
3. A demo button is tapped with no Watch paired or the Watch app not installed. Expected: the card still shows on the phone with a note that no Watch is available. (Task 7)
4. The Watch receives a context that is not a valid card. Expected: it keeps showing the previous card, or hello-world if there was none. (Task 7)
5. A client sends the scheme as `bearer` in lower case or with extra spaces. Expected: accepted, per HTTP's case-insensitive schemes. (Task 2)

---

### Task 1: Create the repo from the web template

Scaffolding; no behavior changes, so no RED test. The PR line: "Test-first exception: scaffolding copy, verified by the existing suite."

**Files:**

- Create: everything under `templates/template-express-next-ios/` by copy.
- Modify: `package.json` (name), `README.md` (title, one-paragraph intro), root `CLAUDE.md` (title; remove dead links).
- Delete from the copy: `.github/workflows/address-copilot-review.yml`.

**Interfaces:**

- Produces: a git repo on `main` whose web stack passes lint, format check, unit tests, and build.

- [ ] **Step 1: Copy.** From `templates/`, run `rsync -a` from `template-express-next/` into `template-express-next-ios/` without `--delete` (the target already holds `docs/superpowers/`). Exclude: `.git`, `node_modules`, `dist`, `.next`, `coverage`, `test-results`, `playwright-report`, `blob-report`, `storybook-static`, `.vercel`, `.DS_Store`, `.env`, `.env.*` (but include `.env.example`), `docs/audits`, `docs/issues`, `docs/prs`, `docs/session-handoff`, `docs/todos`.
- [ ] **Step 2: Rename.** `package.json` `name` becomes `template-express-next-ios`. README and root `CLAUDE.md` titles become "Express + Next.js + iOS Boilerplate". Delete the Copilot workflow.
- [ ] **Step 3: Prune dead links.** Run `grep -rnE "docs/(audits|issues|prs|session-handoff|todos)" --include="*.md" . --exclude-dir=node_modules --exclude-dir=docs/superpowers`. Remove each referencing line or sentence. Expected after: no matches.
- [ ] **Step 4: Verify.** Run `pnpm install --frozen-lockfile && pnpm lint && pnpm format:check && pnpm test && pnpm --filter ./apps/client/web run test && pnpm build`. Expected: every command exits 0.
- [ ] **Step 5: Commit.** `git init -b main`, add everything, commit `chore: initial commit from template-express-next@448006b`. This includes the spec and this plan.
- [ ] **Step 6: Ask the owner** before `gh repo create nullvoidundefined/template-express-next-ios --public` and the first push. After the push, confirm the three CI jobs (`build-and-test`, `e2e`, `docker-build`) are green with `gh run watch`.

---

### Task 2: Server bearer sessions (high risk)

**Files:**

- Create: `apps/server/src/services/parseSessionTokenParser.ts`
- Modify: `apps/server/src/constants/sessionConstants.ts`, `apps/server/src/constants/errorCodesConstants.ts`, `apps/server/src/middleware/requireAuthMiddleware.ts`, `apps/server/src/handlers/authHandler.ts`, `apps/server/CLAUDE.md` (auth section)
- Test: `apps/server/src/__tests__/services/parseSessionTokenParser.test.ts`, `apps/server/src/__tests__/integration/bearer-auth-flow.test.ts`, additions to `apps/server/src/__tests__/handlers/auth/authHandler.test.ts`

**Interfaces:**

- Produces, for Tasks 3 and 5:
  - Request header `X-Session-Transport: token` on `POST /v1/auth/register`, `POST /v1/auth/login`, `PATCH /v1/auth/me` makes the response `{ "sessionToken": string, "user": User }`, sets no cookie, and adds `Cache-Control: no-store`.
  - `Authorization: Bearer <64 hex>` authenticates any route.
  - `sessionConstants.ts`: `SESSION_TRANSPORT_HEADER = 'X-Session-Transport'`, `SESSION_TRANSPORT_TOKEN = 'token'`, `SESSION_TOKEN_PATTERN = /^[a-f0-9]{64}$/`.
  - `ERROR_CODES.AUTH.AMBIGUOUS_CREDENTIALS = 'AUTH_AMBIGUOUS_CREDENTIALS'`.
  - `parseSessionToken(req: Request): ParsedSessionToken` where

```ts
type ParsedSessionToken =
  | { kind: 'conflict' }
  | { kind: 'none' }
  | { kind: 'token'; source: 'bearer' | 'cookie'; token: string };
```

Parser rules: a `sid` cookie and an `Authorization` header whose scheme is `bearer` (any case) together give `conflict`. A bearer header alone gives `token` only if the value after the scheme, trimmed, matches `SESSION_TOKEN_PATTERN`; otherwise `none`. A non-bearer `Authorization` header is ignored. Cookie handling is unchanged from today.

- [ ] **Step 1: RED, parser unit tests.** In `parseSessionTokenParser.test.ts`, with `token = randomBytes(32).toString('hex')`:

```ts
expect(parse({})).toEqual({ kind: 'none' });
expect(parse({ cookie: token })).toEqual({
  kind: 'token',
  source: 'cookie',
  token,
});
expect(parse({ authorization: `Bearer ${token}` })).toEqual({
  kind: 'token',
  source: 'bearer',
  token,
});
expect(parse({ authorization: `bearer   ${token}  ` })).toEqual({
  kind: 'token',
  source: 'bearer',
  token,
}); // Review Focus 5
expect(parse({ authorization: `Bearer ${token}`, cookie: token })).toEqual({
  kind: 'conflict',
});
expect(parse({ authorization: 'Bearer' })).toEqual({ kind: 'none' });
expect(parse({ authorization: `Bearer ${'a'.repeat(10_000)}` })).toEqual({
  kind: 'none',
});
expect(parse({ authorization: `Bearer ${token.toUpperCase()}` })).toEqual({
  kind: 'none',
});
expect(parse({ authorization: `Basic ${token}` })).toEqual({ kind: 'none' });
expect(parse({ authorization: `Basic ${token}`, cookie: token })).toEqual({
  kind: 'token',
  source: 'cookie',
  token,
});
```

- [ ] **Step 2: RED, integration tests** in `bearer-auth-flow.test.ts`, same harness as `auth-flow.test.ts` (`createApp({ query, withTransaction })`, `describe.skipIf(!DB_AVAILABLE)`). `T` is `.set('X-Session-Transport', 'token')`, `X` is `.set('X-Requested-With', 'XMLHttpRequest')`. One `it` per line:
  - register with `T`: 201, `body.sessionToken` matches `SESSION_TOKEN_PATTERN`, `headers['set-cookie']` undefined, `headers['cache-control']` is `no-store`.
  - login with `T`: 200, same three assertions.
  - register and login without `T`: `body` has exactly the key `user`, `set-cookie` defined.
  - `GET /v1/auth/me` with the bearer token: 200 and the registered email.
  - `GET /v1/auth/me` with an unknown 64-hex token: 401, `code` `AUTH_REQUIRED`.
  - `GET /v1/auth/me` with a bearer token whose session row has `expires_at` set to the past by a direct `query`: 401.
  - `GET /v1/auth/me` with both a valid cookie and a valid bearer: 400, `code` `AUTH_AMBIGUOUS_CREDENTIALS`.
  - `POST /v1/auth/logout` with bearer and `X`: 204; then `GET /v1/auth/me` with the same bearer: 401.
  - `POST /v1/auth/logout` with bearer and no `X`: 403, `code` `CSRF_HEADER_MISSING`; the token still works after.
  - `PATCH /v1/auth/me` password change with bearer, `X`, `T`: 200, a new `sessionToken` different from the old one; the old token gives 401; the new one gives 200.
  - A cookie session and a bearer session for one user; password change on the cookie session; the bearer token then gives 401.
- [ ] **Step 3: Confirm RED.** Run `pnpm --filter server run test -- parseSessionTokenParser` and `./scripts/ensure-test-db.sh && pnpm --filter server run test:integration -- bearer-auth-flow`. Expected: FAIL (module not found; `sessionToken` undefined). Commit the tests alone with the failing command and line in the body.
- [ ] **Step 4: Implement the constants, the error code, and `parseSessionToken`.**
- [ ] **Step 5: Change `createLoadSession`** to call `parseSessionToken`. On `conflict`, respond 400 with `AUTH_AMBIGUOUS_CREDENTIALS` and message `Send either a session cookie or a bearer token, not both` and do not call `next`. On `token`, look up as today. Update the code comment on `ERROR_CODES.AUTH.REQUIRED` to "No valid session cookie or bearer token".
- [ ] **Step 6: Change `authHandler.ts`.** Add one internal function used by `register`, `login`, and the password-change branch of `updateMe`:

```ts
function sendSession(
  req: Request,
  res: Response,
  status: number,
  user: User,
  sessionId: string,
): void;
```

With the token transport header it sets `Cache-Control: no-store` and sends `{ sessionToken: sessionId, user: toUserResponse(user) }`; otherwise it sets the cookie and sends `{ user }` exactly as now. `logout` takes its token from `parseSessionToken` and calls `res.clearCookie` only when the source is `cookie`.

- [ ] **Step 7: GREEN.** Run `pnpm --filter server run test` and `pnpm --filter server run test:integration`. Expected: all pass, including the untouched `auth-flow.test.ts` and `sessionCookie.test.ts`.
- [ ] **Step 8: Document** the bearer transport in `apps/server/CLAUDE.md` (who uses it, the opt-in header, the both-sent rejection). Run `pnpm lint && pnpm format:check`. Commit `feat(auth): accept the session token as a bearer header for native clients`.
- [ ] **Step 9: Review, then stop.** One `pr-reviewer` round. Hand the PR to the owner to merge.

---

### Task 3: Demo cards endpoint

**Files:**

- Create: `packages/types/src/cardTypes.ts`, `apps/server/src/schemas/demoSchema.ts`, `apps/server/src/services/demoCardService.ts`, `apps/server/src/handlers/demoHandler.ts`, `apps/server/src/routes/demoRoutes.ts`
- Modify: `packages/types/src/index.ts`, `apps/server/src/app.ts` (build the router; `v1Router.use('/demo', demoRouter)` in alphabetical position)
- Test: `apps/server/src/__tests__/services/demoCardService.test.ts`, `apps/server/src/__tests__/handlers/demoHandler.test.ts`, `apps/server/src/__tests__/integration/demo-cards-flow.test.ts`

**Interfaces:**

- Consumes: bearer auth from Task 2.
- Produces, for Task 6: `POST /v1/demo/cards`, body `{ "kind": "message" | "prompt" }`, response 201 `{ "card": Card }`.

```ts
// packages/types/src/cardTypes.ts
type CardKind = 'message' | 'prompt';
type Card = {
  body: string;
  createdAt: string;
  id: string;
  kind: CardKind;
  title: string;
};

// demoCardService.ts
function createDemoCard(kind: CardKind): Card;
// demoSchema.ts
const createDemoCardSchema = z
  .object({ kind: z.enum(['message', 'prompt']) })
  .strict();
// demoHandler.ts
function createDemoHandlers(): {
  createCard(req: Request, res: Response): void;
};
// demoRoutes.ts
function createDemoRouter(handlers: DemoHandlers): Router; // router.use(requireAuth)
```

`createDemoCard` returns `title` `'Message'` or `'Prompt'`, a `body` chosen at random from three fixed strings per kind (each at most 140 characters; the builder writes them), `id` from `crypto.randomUUID()`, `createdAt` as an ISO string.

- [ ] **Step 1: RED.** Service tests: for each kind, `card.kind === kind`, title as above, `card.body.length` between 1 and 140, `id` is a UUID, `Date.parse(card.createdAt)` is not NaN; two calls give different ids. Integration tests (bearer session created in a `beforeEach`):
  - valid kind `message`: 201 and `body.card.kind === 'message'`.
  - valid kind `prompt`: 201.
  - no session: 401 `AUTH_REQUIRED`.
  - `{ kind: 'other' }`, `{}`, `{ kind: 'message', extra: 1 }`, `{ kind: { $ne: 1 } }`: each 400 `INPUT_VALIDATION_ERROR`.
  - a body over 10 kb: 413.
  - no `X-Requested-With`: 403.
  - two calls without `Idempotency-Key`: different `card.id`.
- [ ] **Step 2: Confirm RED** with `pnpm --filter server run test -- demo` and `pnpm --filter server run test:integration -- demo-cards-flow`. Expected: FAIL, module not found and 404. Commit tests alone.
- [ ] **Step 3: Implement** the five files and the `app.ts` wiring, following `postsRoutes.ts` for shape.
- [ ] **Step 4: GREEN.** Same two commands pass; then `pnpm lint && pnpm format:check && pnpm build`.
- [ ] **Step 5: Commit** `feat(demo): add the demo cards endpoint and shared Card type`.

---

### Task 4: Native scaffold, tooling, and CI

Scaffolding with one real test so the pipeline is proven. PR line: "Test-first exception: project scaffolding; the model decoding test is written first."

**Files:**

- Create: `apps/client/ios/project.yml`, `apps/client/ios/Config/Debug.xcconfig`, `apps/client/ios/Config/Release.xcconfig`, `apps/client/ios/.swift-format`, `apps/client/ios/CLAUDE.md`, `apps/client/ios/App/TemplateApp.swift`, `apps/client/ios/App/Info.plist`, `apps/client/ios/WatchApp/TemplateWatchApp.swift`, `apps/client/ios/Packages/AppCore/Package.swift`, `apps/client/ios/Packages/AppCore/Sources/AppCore/Models/User.swift`, `.../Models/Card.swift`, `apps/client/ios/Packages/AppCore/Tests/AppCoreTests/ModelDecodingTests.swift`, `.../Tests/AppCoreTests/Fixtures/user.json`, `.../Fixtures/card.json`
- Modify: `.gitignore`, `lefthook.yml`, `package.json` (scripts), `.github/workflows/ci.yml`, root `CLAUDE.md` (workspace list, commands)

**Interfaces:**

- Produces, for Tasks 5 to 7:
  - Xcode project `TemplateApp`. Targets: `App` (iOS app, bundle id `com.example.templateapp`), `WatchApp` (watchOS companion app, bundle id `com.example.templateapp.watchkitapp`, `WKCompanionAppBundleIdentifier` set to the phone id), `AppUITests`. Schemes `App` and `WatchApp`. Both app targets depend on the local package `AppCore`.
  - `AppCore` package platforms: iOS, watchOS, and macOS (so `swift test` runs without a simulator).
  - Build setting `API_BASE_URL` from xcconfig, surfaced in `Info.plist` as `APIBaseURL`. Debug: `http://localhost:3001`. Release: empty, plus a build-phase script that fails the build unless the value starts with `https://`.
  - `Info.plist` Debug-only `NSAppTransportSecurity` with `NSAllowsLocalNetworking` true and nothing else.
  - Models:

```swift
public enum UserRole: String, Codable, Sendable { case admin, user }
public struct User: Codable, Equatable, Sendable {
    public let createdAt: String; public let email: String; public let id: String
    public let role: UserRole; public let updatedAt: String?
}
public enum CardKind: String, Codable, Sendable { case message, prompt }
public struct Card: Codable, Equatable, Identifiable, Sendable {
    public let body: String; public let createdAt: String; public let id: String
    public let kind: CardKind; public let title: String
}
```

- Root scripts: `ios:generate` (`cd apps/client/ios && xcodegen generate`), `ios:test` (`swift test --package-path apps/client/ios/Packages/AppCore`), `ios:format:check` (`swift format lint --strict --recursive apps/client/ios`).

- [ ] **Step 1: Pin the toolchain.** Run `xcodebuild -version` and `xcodebuild -showsdks` locally. Look up the Xcode versions on the current GitHub-hosted macOS image (the `actions/runner-images` README for the newest macOS label). Choose the newest runner label and deployment targets that both toolchains build. Record the label, both Xcode versions, and the targets in `apps/client/ios/CLAUDE.md`. If no hosted image can build a SwiftUI iOS app plus a watchOS companion at any target the local Xcode 27 supports, stop and ask the owner.
- [ ] **Step 2: RED.** Write `ModelDecodingTests.swift` (Swift Testing). `user.json` and `card.json` are real responses captured from a local server by `curl` against `/v1/auth/me` and `/v1/demo/cards`. Tests: `decodesUserFixture` (expects the fixture's email, `role == .user`, `updatedAt == nil` when the fixture has null), `decodesCardFixture` (`kind == .message`, non-empty `body`), `rejectsUnknownCardKind` (decoding `"kind":"other"` throws). Run `pnpm ios:test`. Expected: FAIL, no such module or type.
- [ ] **Step 3: Implement** the package, the models, `project.yml`, the xcconfigs, and two placeholder app entry points that each show a `Text`. Each model file carries a comment naming the TypeScript file it mirrors (`packages/types/src/userTypes.ts`, `packages/types/src/cardTypes.ts`).
- [ ] **Step 4: GREEN.** `pnpm ios:test` passes. `pnpm ios:generate` succeeds. `xcodebuild -project apps/client/ios/TemplateApp.xcodeproj -scheme App -destination 'generic/platform=iOS Simulator' build` and the same for scheme `WatchApp` with `generic/platform=watchOS Simulator` both end `BUILD SUCCEEDED`.
- [ ] **Step 5: Tooling.** `.gitignore`: add `*.xcodeproj`, `.build/`, `DerivedData/`, `xcuserdata/`. `lefthook.yml`: add pre-commit `format-swift` (glob `apps/client/ios/**/*.swift`, run `swift format lint --strict {staged_files}`) and add `swift` to the `no-em-dash` glob. Do not add native steps to `pre-push`.
- [ ] **Step 6: CI.** Add job `ios` to `ci.yml` on the runner label from Step 1, `fetch-depth: 0`. First step sets output `changed` to `true` when `git diff --name-only <base>...<head>` (base is `github.event.pull_request.base.sha`, or `github.event.before` on push) lists a path under `apps/client/ios/` or `.github/workflows/ci.yml`. Every later step has `if: steps.detect.outputs.changed == 'true'`: `brew install xcodegen`, `swift test --package-path apps/client/ios/Packages/AppCore`, `xcodegen generate`, `xcodebuild build` for schemes `App` and `WatchApp`, `swift format lint --strict --recursive apps/client/ios`. Task 5 adds the `xcodebuild test` step once a UI test exists. The job has no third-party actions beyond `actions/checkout`.
- [ ] **Step 7: Conventions.** Write `apps/client/ios/CLAUDE.md`: layout, that logic lives in `AppCore` and targets hold views and glue only, tests under `Packages/AppCore/Tests` and `AppUITests`, accessibility identifiers in kebab-case, the Watch never talks to the server, how to rename the app (three values in `project.yml` and xcconfig), toolchain record from Step 1.
- [ ] **Step 8: Commit** `feat(ios): scaffold the iPhone and Watch targets, AppCore package, and CI job`. Confirm the `ios` job runs and passes on the PR with `gh pr checks`.

---

### Task 5: Phone auth

**Files:**

- Create in `apps/client/ios/Packages/AppCore/Sources/AppCore/`: `Networking/APIError.swift`, `Networking/APIClient.swift`, `Networking/URLSessionAPIClient.swift`, `Session/SessionTokenStore.swift`, `Session/KeychainSessionTokenStore.swift`, `Session/InMemorySessionTokenStore.swift`, `Auth/AuthViewModel.swift`, `Auth/CredentialValidator.swift`
- Create in `apps/client/ios/App/`: `Features/Auth/LoginView.swift`, `Features/Auth/RegisterView.swift`, `Features/Root/RootView.swift`, `Features/Root/UnreachableView.swift`, `Support/StubAPIClient.swift` (compiled in Debug only), `Support/AppEnvironment.swift`
- Modify: `apps/client/ios/App/TemplateApp.swift`
- Test: `apps/client/ios/Packages/AppCore/Tests/AppCoreTests/URLSessionAPIClientTests.swift`, `SessionTokenStoreTests.swift`, `AuthViewModelTests.swift`, `CredentialValidatorTests.swift`, `Support/StubURLProtocol.swift`, `Support/FakeAPIClient.swift`; `apps/client/ios/AppUITests/AuthFlowUITests.swift`

**Interfaces:**

- Consumes: Task 2's headers and response shapes; Task 4's models.
- Produces, for Tasks 6 and 7:

```swift
public enum APIError: Error, Equatable {
    case decoding
    case network
    case server(code: String, message: String, status: Int)
    case unauthorized
}
public protocol APIClient: Sendable {
    func createDemoCard(kind: CardKind) async throws -> Card   // implemented in Task 6
    func fetchCurrentUser() async throws -> User
    func login(email: String, password: String) async throws -> User
    func logout() async throws
    func register(email: String, password: String) async throws -> User
}
public protocol SessionTokenStore: Sendable {
    func clear() throws
    func read() throws -> String?
    func save(_ token: String) throws
}
public final class URLSessionAPIClient: APIClient {
    public init(baseURL: URL, session: URLSession, tokenStore: SessionTokenStore)
}
public enum AuthState: Equatable {
    case checking
    case signedIn(User)
    case signedOut(notice: String?)
    case unreachable
}
@MainActor @Observable public final class AuthViewModel {
    public private(set) var errorMessage: String?
    public private(set) var isSubmitting: Bool
    public private(set) var state: AuthState
    public init(apiClient: APIClient, tokenStore: SessionTokenStore)
    public func handleUnauthorized()
    public func login(email: String, password: String) async
    public func logout() async
    public func register(email: String, password: String) async
    public func restore() async
}
public enum CredentialValidator {
    public static func loginError(email: String, password: String) -> String?
    public static func registerError(email: String, password: String) -> String?
}
```

Client rules: every request sends `X-Requested-With: XMLHttpRequest`, `X-Session-Transport: token`, `Accept: application/json`, and `Authorization: Bearer <token>` when the store has one. The `URLSessionConfiguration` passed by the app has `httpCookieStorage = nil` and `httpShouldSetCookies = false`. `login` and `register` save `sessionToken` to the store. A 401 from `login` or `register` is `.server`; a 401 from any other call clears the store and is `.unauthorized`. A transport failure is `.network`. A non-2xx body that is not the error envelope is `.server(code: "UNKNOWN", message: "Something went wrong. Try again.", status:)`. A 2xx body that does not decode is `.decoding`. `createDemoCard` in this task throws `.decoding` as a placeholder until Task 6.

View model rules: `restore()` with no token gives `.signedOut(notice: nil)`; with a token and success gives `.signedIn`; with `.unauthorized` gives `.signedOut(notice: nil)`; with `.network` keeps the token and gives `.unreachable`. `handleUnauthorized()` clears the token and gives `.signedOut(notice: "You were signed out. Log in again.")`. `logout()` calls the server, then clears the token and gives `.signedOut(notice: nil)` whether or not the server call threw. `errorMessage` is the server's `error` text for `.server`, `"Can't reach the server. Check your connection."` for `.network`.

Validator rules match `authSchema.ts`: email must contain `@` with text on both sides and a dot in the domain; register password 8 to 72 characters; login password non-empty. Messages: `Invalid email`, `Password must be at least 8 characters`, `Password must be at most 72 characters`, `Password is required`.

Accessibility identifiers: `login-email-field`, `login-password-field`, `login-submit-button`, `login-register-link`, `login-error`, `login-notice`, `register-email-field`, `register-password-field`, `register-submit-button`, `register-error`, `unreachable-retry-button`.

- [ ] **Step 1: RED, API client** (`StubURLProtocol` records the request and returns a canned response). One test per line:
  - `loginSendsRequiredHeadersAndSavesToken`: request path `/v1/auth/login`, method POST, the three headers present, no `Authorization`; after it the store reads the returned token.
  - `authenticatedRequestSendsBearer`: with a stored token, `fetchCurrentUser` sends `Authorization: Bearer <token>`.
  - `loginWith401IsServerError`: `.server(code: "AUTH_INVALID_CREDENTIALS", message: "Invalid email or password", status: 401)`; store untouched.
  - `fetchCurrentUserWith401ClearsToken`: throws `.unauthorized`; store reads nil.
  - `registerWith409IsServerError`: code `AUTH_EMAIL_ALREADY_REGISTERED`.
  - `transportFailureIsNetworkError`.
  - `htmlErrorBodyIsServerUnknown`: status 502 with body `<html>` gives `.server(code: "UNKNOWN", message: "Something went wrong. Try again.", status: 502)`. (Review Focus 2)
  - `malformedSuccessBodyIsDecodingError`.
  - `logoutSendsBearerAndPostsToLogout`.
- [ ] **Step 2: RED, token store.** Shared test function run against `InMemorySessionTokenStore` and `KeychainSessionTokenStore(service: "AppCoreTests-\(UUID())")`: read is nil when empty; save then read returns it; save twice returns the second; clear then read is nil; clear when empty does not throw. The value is built from `UUID()`. If the Keychain case cannot run under `swift test` on the CI runner (no usable keychain for an unsigned test binary), gate that one case behind an environment check and run it from the phone UI test target instead; say so in the PR.
- [ ] **Step 3: RED, view model and validator** with `FakeAPIClient` (each method returns a queued `Result`):
  - `restoreWithoutTokenIsSignedOut`, `restoreWithValidTokenIsSignedIn`, `restoreWithRejectedTokenIsSignedOut`.
  - `restoreWhenServerUnreachableKeepsToken`: state `.unreachable`, store still holds the token. (Review Focus 1)
  - `loginSuccessIsSignedIn`, `loginFailureSetsErrorMessage` (message `Invalid email or password`, state unchanged).
  - `loginIgnoresSecondCallWhileSubmitting`: two overlapping calls reach the fake once.
  - `logoutClearsTokenEvenWhenServerFails`.
  - `handleUnauthorizedShowsNotice`.
  - Validator: one test per message above, plus a valid pair returning nil, plus a 73-character password.
- [ ] **Step 4: Confirm RED** with `pnpm ios:test`. Expected: FAIL to compile, types missing. Commit tests alone.
- [ ] **Step 5: Implement `AppCore`.** Keychain store uses `kSecClassGenericPassword` with the given service, account `session-token`, and `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- [ ] **Step 6: GREEN** with `pnpm ios:test`.
- [ ] **Step 7: Views.** `AppEnvironment` builds the live client from `APIBaseURL` and the Keychain store, or `StubAPIClient` plus the in-memory store when the launch argument `-uiTestStubAPI` is present (Debug builds only). `RootView` switches on `AuthState`: a progress view, `LoginView`, `UnreachableView` (text plus a Retry button calling `restore()`), or a placeholder signed-in view showing the email and a Log out button with identifier `home-logout-button`. Forms show the validator's message before any network call, disable the submit button while `isSubmitting`, and use system text styles.
- [ ] **Step 8: UI test.** `AuthFlowUITests.testLoginReachesSignedInAndPassesAudit`: launch with `-uiTestStubAPI`, call `performAccessibilityAudit()` on Login, type an email and a run-time password, tap `login-submit-button`, assert `home-logout-button` exists, audit again, tap it, assert `login-submit-button` exists. Run `xcodebuild test -project apps/client/ios/TemplateApp.xcodeproj -scheme App -destination 'platform=iOS Simulator,name=<the simulator from Task 4>'`. Expected: `TEST SUCCEEDED`. Add this command to the `ios` CI job after the build steps, with the same `if` guard.
- [ ] **Step 9: Manual check against the real server.** `pnpm dev`, run the app in a simulator, register, kill and relaunch (still signed in), log out. Stop the server and relaunch while signed in: the retry screen shows. Record the result in the PR.
- [ ] **Step 10: Commit** `feat(ios): phone sign up, log in, and log out against the Express API`.

---

### Task 6: Phone home screen and card fetch

**Files:**

- Create: `apps/client/ios/Packages/AppCore/Sources/AppCore/Home/HomeViewModel.swift`, `.../Watch/WatchLink.swift`, `apps/client/ios/App/Features/Home/HomeView.swift`, `apps/client/ios/App/Features/Home/CardView.swift`
- Modify: `URLSessionAPIClient.swift` (`createDemoCard`), `StubAPIClient.swift`, `RootView.swift` (signed-in case shows `HomeView`)
- Test: `.../Tests/AppCoreTests/HomeViewModelTests.swift`, additions to `URLSessionAPIClientTests.swift`, `Support/FakeWatchLink.swift`; additions to `AuthFlowUITests.swift`

**Interfaces:**

- Consumes: `APIClient`, `AuthViewModel.handleUnauthorized()`, Task 3's endpoint.
- Produces, for Task 7:

```swift
public enum WatchDelivery: Equatable, Sendable { case sent, unavailable }
public protocol WatchLink: Sendable {
    func send(_ card: Card) -> WatchDelivery
}
@MainActor @Observable public final class HomeViewModel {
    public private(set) var errorMessage: String?
    public private(set) var isSending: Bool
    public private(set) var lastCard: Card?
    public private(set) var lastDelivery: WatchDelivery?
    public init(apiClient: APIClient, onUnauthorized: @escaping @MainActor () -> Void, watchLink: WatchLink)
    public func send(kind: CardKind) async
}
```

In this task the app passes a `WatchLink` that always returns `.unavailable`; Task 7 replaces it.

Identifiers: `home-email`, `home-send-message-button`, `home-send-prompt-button`, `home-last-card`, `home-watch-status`, `home-error`, `home-logout-button`. Button titles: `Send message`, `Send prompt card`. Watch status text: `Sent to Apple Watch` for `.sent`, `No Apple Watch available. The card is shown here only.` for `.unavailable`.

- [ ] **Step 1: RED.**
  - Client: `createDemoCardPostsKindAndDecodesCard` (path `/v1/demo/cards`, JSON body `{"kind":"prompt"}`, bearer present, no `Idempotency-Key` header, returns the fixture card).
  - `sendStoresCardAndForwardsToWatch`: `lastCard` is the returned card, the fake link received exactly that card, `lastDelivery == .sent`.
  - `sendWithUnavailableWatchStillShowsCard`: `lastCard` set, `lastDelivery == .unavailable`, `errorMessage == nil`.
  - `sendFailureSetsErrorAndKeepsPreviousCard`.
  - `sendUnauthorizedCallsOnUnauthorized`: the closure ran once and the link received nothing.
  - `sendIgnoresSecondCallWhileSending`: two overlapping calls reach the fake client once.
- [ ] **Step 2: Confirm RED** with `pnpm ios:test`; commit tests alone.
- [ ] **Step 3: Implement** the view model, `createDemoCard`, and the views. Both buttons are disabled while `isSending`. `CardView` shows title and body and is one accessibility element whose label is "title, body".
- [ ] **Step 4: GREEN** with `pnpm ios:test`.
- [ ] **Step 5: Extend the UI test:** after login, tap `home-send-message-button`, assert `home-last-card` exists and `home-watch-status` exists, run the audit on Home. `xcodebuild test` as in Task 5. Expected: `TEST SUCCEEDED`.
- [ ] **Step 6: Commit** `feat(ios): home screen with demo buttons that fetch a card from the server`.

---

### Task 7: Watch display and the phone-to-Watch link

**Files:**

- Create: `apps/client/ios/Packages/AppCore/Sources/AppCore/Watch/CardContext.swift`, `.../Watch/LatestCardStore.swift`, `apps/client/ios/App/Services/WatchConnectivityLink.swift`, `apps/client/ios/WatchApp/WatchContextReceiver.swift`, `apps/client/ios/WatchApp/WatchRootView.swift`
- Modify: `apps/client/ios/WatchApp/TemplateWatchApp.swift`, `apps/client/ios/App/Support/AppEnvironment.swift` (use `WatchConnectivityLink`)
- Test: `.../Tests/AppCoreTests/CardContextTests.swift`, `LatestCardStoreTests.swift`

**Interfaces:**

- Consumes: `Card`, `WatchLink`, `WatchDelivery`.
- Produces:

```swift
public enum CardContext {
    public static let key = "card"
    public static func decode(_ context: [String: Any]) -> Card?
    public static func encode(_ card: Card) throws -> [String: Any]   // ["card": Data] holding the card's JSON
}
@MainActor @Observable public final class LatestCardStore {
    public private(set) var card: Card?
    public init(defaults: UserDefaults)          // loads the saved card, nil if absent or corrupt
    public func receive(context: [String: Any])  // valid card: replace and persist; invalid: no change
}
```

`WatchConnectivityLink.send` returns `.unavailable` when `WCSession.isSupported()` is false, the session is not activated, `isPaired` is false, or `isWatchAppInstalled` is false; otherwise it calls `updateApplicationContext(try CardContext.encode(card))` and returns `.sent`, or `.unavailable` if that throws. It activates the session at app start. `WatchContextReceiver` is the Watch's `WCSessionDelegate`; on `didReceiveApplicationContext` and on activation (reading `receivedApplicationContext`) it hops to the main actor and calls `store.receive(context:)`.

Watch screen: when `store.card` is nil, the text `Hello, world`. Otherwise a `ScrollView` with the title in `.headline` and the body in `.body`. Identifiers `watch-hello`, `watch-card-title`, `watch-card-body`.

- [ ] **Step 1: RED.**
  - `encodeThenDecodeReturnsSameCard`.
  - `decodeRejectsEmptyContext`, `decodeRejectsWrongType` (`["card": "text"]`), `decodeRejectsCorruptData` (`["card": Data([0x00])]`): each nil.
  - `storeStartsEmpty` (fresh `UserDefaults(suiteName: UUID().uuidString)`).
  - `storeKeepsLatestCardAcrossInstances`: receive a card, build a second store on the same suite, its `card` equals the first.
  - `storeReplacesCardWithNewer`.
  - `storeIgnoresInvalidContextAndKeepsPreviousCard`. (Review Focus 4)
  - `storeWithCorruptSavedDataStartsEmpty`.
- [ ] **Step 2: Confirm RED** with `pnpm ios:test`; commit tests alone.
- [ ] **Step 3: Implement** the codec, the store, the link, the receiver, and the Watch view.
- [ ] **Step 4: GREEN** with `pnpm ios:test`; both schemes build as in Task 4 Step 4; the phone UI test still passes.
- [ ] **Step 5: Manual check in paired simulators,** recorded in the PR with a screenshot of each: (a) Watch launches to `Hello, world`; (b) server running, phone signed in, tap Send message: the Watch shows the card and the phone says `Sent to Apple Watch`; (c) tap Send prompt card: the Watch replaces it; (d) quit and relaunch the Watch app: the last card is still there; (e) on a phone simulator with no paired Watch, tap a button: the card shows on the phone with the unavailable note. (Review Focus 3)
- [ ] **Step 6: Commit** `feat(watch): show the latest card sent from the phone`.

---

### Task 8: Docs

No behavior; PR line: "Test-first exception: documentation only."

**Files:**

- Modify: `README.md`, root `CLAUDE.md`, `docs/feature-list/features.md`, `apps/client/CLAUDE.md` (it describes the web client only; add one line pointing native work to `apps/client/ios/CLAUDE.md`)
- Create: `docs/user-stories/native-auth.md`, `docs/user-stories/watch-cards.md`

- [ ] **Step 1: README.** Add "Run all four pieces": prerequisites (Xcode, `brew install xcodegen`), `docker compose up -d`, `pnpm --filter server run migrate:up`, `pnpm dev`, `pnpm ios:generate`, open the project, run scheme `App` on a phone simulator paired with a Watch simulator, run scheme `WatchApp`, register, tap a demo button. Add "Start a new app from this template": the three rename values and setting the Release `API_BASE_URL`. State what is not included (TestFlight, push, in-app purchase) and that private repos pay the macOS CI multiplier.
- [ ] **Step 2: Root `CLAUDE.md`.** Add the workspace to the list at the top and to Stack, the three `ios:*` commands to Key Commands, and one rule: "Native clients authenticate with the bearer transport; the web client keeps the cookie. Never return `sessionToken` without the opt-in header."
- [ ] **Step 3: Feature list and stories.** Rows for "Native sign up, log in, log out" and "Demo card to Apple Watch"; one story file each in the format of `docs/user-stories/posts.md`. The repo rule asking for a Playwright spec per feature is met for these two by the XCUITest and the recorded manual check; say so in the feature rows.
- [ ] **Step 4: Verify.** `pnpm format:check` exits 0. `grep -rn "$(printf '\xe2\x80\x94')" README.md CLAUDE.md docs apps/client` prints nothing. Follow the README walkthrough once from a fresh clone in the scratchpad directory and confirm each command works as written.
- [ ] **Step 5: Commit** `docs: native workspace walkthrough, rules, feature list, and user stories`. After merge, delete `docs/superpowers/specs/` and `docs/superpowers/plans/` files for this work per the repo's feature checklist.
