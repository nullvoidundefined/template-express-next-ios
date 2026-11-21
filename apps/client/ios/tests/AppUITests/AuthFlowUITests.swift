import XCTest

final class AuthFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLoginReachesSignedInAndPassesAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestStubAPI"]
        app.launch()

        let submit = app.buttons["login-submit-button"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()

        let email = app.textFields["login-email-field"]
        XCTAssertTrue(email.exists)
        email.tap()
        email.typeText("ada@example.com")

        let password = app.secureTextFields["login-password-field"]
        XCTAssertTrue(password.exists)
        password.tap()
        password.typeText(UUID().uuidString)

        submit.tap()

        let sendMessage = app.buttons["home-send-message-button"]
        XCTAssertTrue(sendMessage.waitForExistence(timeout: 10))
        sendMessage.tap()

        XCTAssertTrue(app.descendants(matching: .any)["home-last-card"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["home-watch-status"].waitForExistence(timeout: 10))

        let logout = app.buttons["home-logout-button"]
        XCTAssertTrue(logout.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit()

        logout.tap()
        XCTAssertTrue(app.buttons["login-submit-button"].waitForExistence(timeout: 10))
    }
}
