import XCTest

final class CekSepetUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func app() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset"]
        app.launchEnvironment["CEKSEPET_TEST_API_URL"] = "http://localhost:18080/api/v1/"
        app.launch(); return app
    }
    func testOnboardingBrowseSearchAndFavorite() {
        let app = app()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 15))
        capture("01-Onboarding", app: app)
        app.buttons["onboarding.skip"].tap()
        capture("02-Login", app: app)
        app.buttons["auth.browse"].tap()
        XCTAssertTrue(app.buttons["tab.1"].waitForExistence(timeout: 5))
        capture("03-Home", app: app)
        app.buttons["tab.1"].tap()
        let search = app.textFields["catalog.search"]; search.tap(); search.typeText("Macbook")
        XCTAssertTrue(app.buttons["product.prod-2"].waitForExistence(timeout: 5))
        app.buttons["product.prod-2"].tap()
        XCTAssertTrue(app.buttons["product.favorite"].waitForExistence(timeout: 5))
        app.buttons["product.favorite"].tap()
        capture("04-Product", app: app)
    }
    func testLoginOTPProfileAndWrongDeletePIN() {
        let app = app()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 15)); app.buttons["onboarding.skip"].tap()
        let phone = app.textFields["auth.phone"]; phone.tap(); phone.typeText("5551112233")
        let pin = app.secureTextFields["auth.pin"]; pin.tap(); pin.typeText("123456")
        app.buttons["Bitti"].tap(); app.buttons["auth.submit"].tap()
        let code = app.textFields["auth.otp"]
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        let debug = app.staticTexts["auth.debugCode"]
        XCTAssertTrue(debug.waitForExistence(timeout: 5))
        let otp = String(debug.label.suffix(6))
        code.tap(); code.typeText(otp)
        app.buttons["Bitti"].tap(); app.buttons["auth.verify"].tap()
        XCTAssertTrue(app.buttons["tab.3"].waitForExistence(timeout: 10)); app.buttons["tab.3"].tap()
        XCTAssertTrue(app.staticTexts["Ada Yılmaz"].waitForExistence(timeout: 5))
        capture("05-Profile", app: app)
        app.swipeUp(); app.buttons["profile.delete"].tap()
        let username = app.textFields["delete.username"]; XCTAssertTrue(username.waitForExistence(timeout: 5)); username.tap(); username.typeText("ada_yilmaz")
        app.secureTextFields["delete.pin"].tap(); app.secureTextFields["delete.pin"].typeText("000000")
        app.buttons["Bitti"].tap(); app.buttons["delete.submit"].tap(); app.buttons["Evet, hesabımı sil"].tap()
        XCTAssertTrue(app.otherElements["delete.error"].waitForExistence(timeout: 5) || app.staticTexts["Kullanıcı adı veya PIN hatalı."].exists)
        app.buttons["Vazgeç"].tap()
        XCTAssertTrue(app.staticTexts["Ada Yılmaz"].waitForExistence(timeout: 5))
    }
    func testRegistrationRestoresSessionAndDeletesAccount() {
        let app = app()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 15)); app.buttons["onboarding.skip"].tap()
        app.buttons["auth.switch"].tap()
        let first = app.textFields["auth.firstName"]; XCTAssertTrue(first.waitForExistence(timeout: 5)); first.tap(); first.typeText("Deniz")
        app.textFields["auth.lastName"].tap(); app.textFields["auth.lastName"].typeText("Test")
        app.textFields["auth.phone"].tap(); app.textFields["auth.phone"].typeText("555" + String(Int(Date().timeIntervalSince1970) % 10_000_000).leftPadded(to: 7))
        app.buttons["Bitti"].tap()
        app.secureTextFields["auth.pin"].tap(); app.secureTextFields["auth.pin"].typeText("123456")
        app.buttons["Bitti"].tap(); app.buttons["auth.submit"].tap()
        let avatar = app.buttons["avatar.avatar_03"]; XCTAssertTrue(avatar.waitForExistence(timeout: 10)); avatar.tap()
        capture("06-Avatars", app: app)
        app.buttons["auth.submit"].tap()
        let otpField = app.textFields["auth.otp"]; XCTAssertTrue(otpField.waitForExistence(timeout: 10))
        let usernameLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Kullanıcı adın: ")).firstMatch
        XCTAssertTrue(usernameLabel.exists)
        let username = String(usernameLabel.label.dropFirst("Kullanıcı adın: ".count))
        let code = String(app.staticTexts["auth.debugCode"].label.suffix(6))
        capture("07-OTP", app: app)
        otpField.tap(); otpField.typeText(code); app.buttons["Bitti"].tap(); app.buttons["auth.verify"].tap()
        XCTAssertTrue(app.buttons["tab.3"].waitForExistence(timeout: 10))
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["tab.3"].waitForExistence(timeout: 15)); app.buttons["tab.3"].tap()
        XCTAssertTrue(app.staticTexts["Deniz Test"].waitForExistence(timeout: 5))
        app.swipeUp(); app.buttons["profile.delete"].tap()
        let usernameField = app.textFields["delete.username"]; XCTAssertTrue(usernameField.waitForExistence(timeout: 5)); usernameField.tap(); usernameField.typeText(username)
        app.secureTextFields["delete.pin"].tap(); app.secureTextFields["delete.pin"].typeText("123456")
        app.buttons["Bitti"].tap(); app.buttons["delete.submit"].tap(); app.buttons["Evet, hesabımı sil"].tap()
        XCTAssertTrue(app.buttons["auth.submit"].waitForExistence(timeout: 10))
    }
    func testProductDraftCanBeSavedAndReopened() {
        let app = app()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 15)); app.buttons["onboarding.skip"].tap(); app.buttons["auth.browse"].tap()
        app.buttons["tab.add"].tap()
        let title = app.textFields["draft.title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Test Bisiklet")
        app.textFields["draft.brand"].tap(); app.textFields["draft.brand"].typeText("Bisan")
        app.buttons["Bitti"].tap(); app.swipeUp()
        let description = app.textViews["draft.description"]; description.tap(); description.typeText("Temiz kullanılmış şehir bisikleti.")
        app.buttons["Bitti"].tap(); app.swipeUp()
        app.textFields["draft.goal"].tap(); app.textFields["draft.goal"].typeText("2000"); app.buttons["Bitti"].tap()
        capture("08-Draft", app: app)
        app.buttons["draft.save"].tap()
        XCTAssertTrue(app.alerts["Taslak kaydedildi"].waitForExistence(timeout: 5)); app.alerts.buttons["Tamam"].tap()
        app.buttons["tab.3"].tap(); app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Ürün taslaklarım")).firstMatch.tap()
        let savedTitle = app.staticTexts.matching(identifier: "Test Bisiklet").firstMatch
        XCTAssertTrue(savedTitle.waitForExistence(timeout: 5))
        savedTitle.tap()
        XCTAssertTrue(app.textFields["draft.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["draft.title"].value as? String, "Test Bisiklet")
    }
}

private extension String {
    func leftPadded(to count: Int) -> String { String(repeating: "0", count: max(0, count - self.count)) + self }
}
