import XCTest
@testable import HandySwitch

final class PanelPlacementTests: XCTestCase {
    func testOriginAnchorsBelowTopMenuBar() {
        let screens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        let visibles = [CGRect(x: 0, y: 0, width: 1440, height: 875)]
        let anchor = CGRect(x: 700, y: 878, width: 24, height: 22)
        let origin = PanelPlacement.origin(
            anchor: anchor,
            size: CGSize(width: 280, height: 168),
            screens: screens,
            visibleScreens: visibles,
            fallbackVisible: visibles[0]
        )
        XCTAssertEqual(origin.y, anchor.minY - 168 - 6, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(origin.x, 8)
    }
}
