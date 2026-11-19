import XCTest

/// The main flows (spec 13.8): Home → Movie → Theatre → Book tickets, Search, and You.
final class FlowTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUp() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launch()
  }

  func testHomeToMovieToTheatreToBook() {
    let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Best theatre'")).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 5))
    card.tap()

    XCTAssertTrue(app.staticTexts["Best theatres for this movie"].waitForExistence(timeout: 5))
    let firstTheatre = app.descendants(matching: .any)["theatreCard.1"]
    XCTAssertTrue(firstTheatre.waitForExistence(timeout: 5))
    XCTAssertTrue(firstTheatre.label.hasPrefix("Rank 1"))
    app.swipeUp()
    firstTheatre.tap()

    let book = app.buttons["Book tickets"]
    XCTAssertTrue(book.waitForExistence(timeout: 5))
    book.tap()
    XCTAssertTrue(app.buttons["Open BookMyShow"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Open District"].exists)
  }

  func testSearchFindsAMovie() {
    app.buttons["Search any movie"].tap()
    let field = app.textFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("doomsday")
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Avengers: Doomsday'")).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    XCTAssertTrue(app.staticTexts["Best theatres for this movie"].waitForExistence(timeout: 5))
  }

  func testSearchWithNoMatch() {
    app.buttons["Search any movie"].tap()
    let field = app.textFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.typeText("qwxzv")
    XCTAssertTrue(app.buttons["Tell us about this movie"].waitForExistence(timeout: 5))
  }

  func testYouOpensFromAvatar() {
    app.buttons["You: saved theatres and settings"].tap()
    XCTAssertTrue(app.navigationBars["You"].waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.staticTexts["Tap the heart on any theatre to save it here."].exists
        || app.staticTexts["Saved theatres"].exists)
  }
}
