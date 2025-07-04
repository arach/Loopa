import XCTest
@testable import Loopa

final class VideoEditorViewModelTests: XCTestCase {
    func testInitialState() {
        let vm = VideoEditorViewModel()
        XCTAssertNil(vm.asset)
        XCTAssertNil(vm.player)
        XCTAssertEqual(vm.selectedFilter, .none)
        XCTAssertEqual(vm.thumbnails.count, 0)
        XCTAssertEqual(vm.filteredThumbnails.count, 0)
    }
    
    func testSetFilter() {
        let vm = VideoEditorViewModel()
        vm.selectedFilter = .sepia
        XCTAssertEqual(vm.selectedFilter, .sepia)
    }
}
