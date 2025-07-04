import XCTest
@testable import Loopa

final class FilterTypeTests: XCTestCase {
    func testAllCases() {
        let expected: [String] = [
            "None", "Sepia", "Comic", "Posterize", "Noir", "Mono", "Blur", "Vignette", "Bloom", "Pixelate", "Invert"
        ]
        let actual = FilterType.allCases.map { $0.rawValue }
        XCTAssertEqual(actual, expected)
    }
    
    func testRawValueMapping() {
        for type in FilterType.allCases {
            XCTAssertEqual(FilterType(rawValue: type.rawValue), type)
        }
    }
}
