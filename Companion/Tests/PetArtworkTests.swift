import XCTest
@testable import Companion

@MainActor
final class PetArtworkTests: XCTestCase {
    func testBlobHitTestingIsShapedNotRectangular() {
        let art = BlobPetArtwork()
        XCTAssertTrue(art.contains(CGPoint(x: 60, y: 76)), "center of the body is clickable")
        XCTAssertFalse(art.contains(CGPoint(x: 1, y: art.size.height - 1)), "transparent corner passes clicks through")
        XCTAssertFalse(art.contains(CGPoint(x: -10, y: 50)), "outside the window is not the character")
    }
}
