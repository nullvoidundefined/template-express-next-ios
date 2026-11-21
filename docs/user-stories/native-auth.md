# User Story: Native Auth

The iPhone app lets a user register, log in, stay logged in across launches, and log out. Native clients use the bearer transport: `X-Session-Transport: token` at register and login, `Authorization: Bearer` on every request, token stored in the Keychain. The server returns `sessionToken` only when the opt-in header is present.

## As an iPhone user, I can manage my session

- **Register:** I enter my email and password and receive a session token stored in the Keychain. The server returns `201` with `{ sessionToken, user }` when I send `X-Session-Transport: token`.
- **Log in:** I enter my email and password and the server authenticates me, returning a session token. The token is sent as `Authorization: Bearer` on subsequent requests.
- **Stay logged in:** The app restores my session from the Keychain on launch. If the server rejects the token, I am signed out.
- **Log out:** I tap "Log out" and the server deletes my session. The token is removed from the Keychain.

## Acceptance criteria

- Register returns `409 AUTH_EMAIL_ALREADY_REGISTERED` when the email is already taken.
- Login returns `401 AUTH_INVALID_CREDENTIALS` for wrong email or password; the error message does not distinguish which field was wrong.
- The session token is stored in the Keychain and restored on app launch.
- A rejected token signs the user out and clears the Keychain.
- Logout always returns `204`. The app clears the Keychain and the Watch card even if the server call fails.
- The server rejects requests carrying both a `sid` cookie and a bearer token with `400 AUTH_AMBIGUOUS_CREDENTIALS`.

## Coverage

- Unit (AuthViewModel): `apps/client/ios/Packages/AppCore/tests/AppCoreTests/AuthViewModelTests.swift`
- Unit (SessionTokenStore): `apps/client/ios/Packages/AppCore/tests/AppCoreTests/SessionTokenStoreTests.swift`
- Unit (CredentialValidator): `apps/client/ios/Packages/AppCore/tests/AppCoreTests/CredentialValidatorTests.swift`
- Unit (ModelDecoding): `apps/client/ios/Packages/AppCore/tests/AppCoreTests/ModelDecodingTests.swift`
- Unit (URLSessionAPIClient): `apps/client/ios/Packages/AppCore/tests/AppCoreTests/URLSessionAPIClientTests.swift`
- UI (login, send, logout, audit): `apps/client/ios/tests/AppUITests/AuthFlowUITests.swift`
- Integration (bearer auth flow): `apps/server/src/__tests__/integration/bearer-auth-flow.test.ts`
- Integration (auth flow): `apps/server/src/__tests__/integration/auth-flow.test.ts`
- Unit (auth handlers): `apps/server/src/__tests__/handlers/auth/authHandler.test.ts`
- Unit (session cookie): `apps/server/src/__tests__/handlers/auth/sessionCookie.test.ts`
- Unit (auth repository): `apps/server/src/__tests__/repositories/authRepository.test.ts`
- Unit (auth schemas): `apps/server/src/__tests__/schemas/authSchema.test.ts`
