# User Story: Watch Cards

After logging in on the iPhone, the user can send a card to the Apple Watch. The Watch shows "Hello, world" until a card arrives, then shows the latest card and keeps it across launches. The Watch never calls the server and never holds the session token.

## As an iPhone user, I can send a card to my Apple Watch

- **Send message:** I tap "Send message" on the home screen and a card appears on the phone and on the Watch.
- **Send prompt card:** I tap "Send prompt card" on the home screen and a prompt card appears on the phone and on the Watch.
- **Watch keeps the card:** The card persists on the Watch across app relaunches via `UserDefaults`.
- **Watch shows "Hello, world" when empty:** When no card has been sent, the Watch displays "Hello, world".
- **Log out clears the Watch:** When I log out on the phone, the card is removed from the Watch and it returns to "Hello, world".

## Acceptance criteria

- `POST /v1/demo/cards` accepts `{ kind }` (`message` or `prompt`) and returns `201` with `{ card }`, where the card has `id`, `kind`, `title`, `body`, and `createdAt`.
- The card is shown on the phone after a successful send.
- The card is forwarded to the Watch via WatchConnectivity.
- A failed send leaves the previous card on the phone (if any) and does not clear the Watch.
- Sending while the Watch is unavailable still shows the card on the phone with a "No Apple Watch available" note.
- An unauthorized send ends the session and does not show a card.
- Logging out, or an unauthorized response, clears the card on the Watch.
- The Watch app never calls the server and never holds the session token.

## Coverage

- Unit (HomeViewModel): `apps/client/ios/Packages/AppCore/tests/AppCoreTests/HomeViewModelTests.swift`
- Unit (CardContext): `apps/client/ios/Packages/AppCore/tests/AppCoreTests/CardContextTests.swift`
- Unit (LatestCardStore): `apps/client/ios/Packages/AppCore/tests/AppCoreTests/LatestCardStoreTests.swift`
- UI (login, send message, accessibility audit): `apps/client/ios/tests/AppUITests/AuthFlowUITests.swift`
- Integration (demo cards flow): `apps/server/src/__tests__/integration/demo-cards-flow.test.ts`
- Unit (demo handlers): `apps/server/src/__tests__/handlers/demoHandler.test.ts`
- Unit (demo card service): `apps/server/src/__tests__/services/demoCardService.test.ts`
