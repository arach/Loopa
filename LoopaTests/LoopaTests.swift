//
//  LoopaTests.swift
//  LoopaTests
//
//  Created by Arach Tchoupani on 2025-07-01.
//

import XCTest
@testable import Loopa
import AVFoundation

final class LoopaTests: XCTestCase {

    func testVideoLoading() async throws {
        let viewModel = VideoEditorViewModel()
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: "test_video", withExtension: "mov") else {
            throw XCTSkip("Test video not found in bundle")
        }
        await MainActor.run {
            viewModel.asset = AVURLAsset(url: url)
        }
        await viewModel.applyFilter(.none)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        XCTAssertNotNil(viewModel.asset)
        XCTAssertNotNil(viewModel.player)
    }

}
