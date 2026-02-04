import XCTest
@testable import AudioBooth

final class EbookReaderPreferencesTests: XCTestCase {
    func testToEPUBPreferencesMapping() {
        let preferences = EbookReaderPreferences()
        
        // Test Vertical Scrolling Enabled
        preferences.verticalScrolling = true
        var epubPrefs = preferences.toEPUBPreferences()
        XCTAssertTrue(epubPrefs.scroll, "Vertical scrolling should be mapped to Readium's scroll preference")
        
        // Test Vertical Scrolling Disabled
        preferences.verticalScrolling = false
        epubPrefs = preferences.toEPUBPreferences()
        XCTAssertFalse(epubPrefs.scroll, "Paginated mode should map to scroll = false")
    }
}
