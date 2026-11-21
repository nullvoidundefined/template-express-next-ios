# iOS and Watch apps

## Layout

- `project.yml`: XcodeGen spec. The `TemplateApp.xcodeproj` it generates is gitignored; run `pnpm ios:generate`.
- `App/`: iPhone app target (`App`). Views and glue only.
- `WatchApp/`: watchOS companion target (`WatchApp`). Views and glue only.
- `Config/Debug.xcconfig`, `Config/Release.xcconfig`: build settings, including `API_BASE_URL`.
- `Packages/AppCore/`: local Swift package. All logic lives here: models, networking, session handling.
- `tests/AppUITests/`: UI tests, added with the first UI test.

## Rules

- Logic lives in `AppCore`. Targets hold views and glue only.
- No third-party Swift packages. XcodeGen is the only added tool.
- Tests live under `Packages/AppCore/tests/AppCoreTests` and `tests/AppUITests`. The folder is lowercase `tests`.
- Accessibility identifiers are kebab-case, for example `login-submit-button`.
- The Watch never talks to the server and never holds the session token. The Watch target must not reference networking code.
- `API_BASE_URL` is an origin only (the client adds `/v1/...`). Debug is `http://localhost:3001` with `NSAllowsLocalNetworking`. Release must be `https://`; the "Require HTTPS API_BASE_URL" build phase fails the build otherwise. Never disable TLS verification.
- No credential-shaped literals, including in tests. Build test passwords and tokens at run time.

## Commands

```bash
pnpm ios:generate       # xcodegen generate
pnpm ios:test           # swift test on AppCore (runs on macOS, no simulator)
pnpm ios:format:check   # swift format lint --strict
pnpm ios:verify-config  # Release needs https, ATS exception is Debug-only (run after generate)
```

## Renaming the app

Change three values, then run `pnpm ios:generate`: the project `name` in `project.yml`, the bundle id (`com.example.templateapp`, set in `project.yml` for both targets along with `INFOPLIST_KEY_WKCompanionAppBundleIdentifier`), and `API_BASE_URL` in the xcconfig files.

## Toolchain record

- Local: Xcode 27.0, Swift 6.4, iOS 27 and watchOS 27 SDKs.
- CI: GitHub-hosted `macos-26` runner, default Xcode 26.6 (iOS 26.5 and watchOS 26.5 SDKs and simulators).
- Deployment targets: iOS 26.0 and watchOS 26.0. `AppCore` uses `// swift-tools-version: 6.2`, platforms iOS 26, watchOS 26, macOS 15.
- Use no API or language feature newer than Xcode 26.6 supports.
