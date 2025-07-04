//
//  VideoProcessingService.swift
//  Loopa
//
//  Created by Arach Tchoupani on 2025-07-02.
//


import Foundation
import AVFoundation
import CoreImage
import UIKit
import Photos
import ImageIO
import UniformTypeIdentifiers

protocol VideoProcessingServiceProtocol {
    func generateThumbnails(from asset: AVAsset, frameCount: Int) async -> [UIImage]
    // Add other methods as needed
}

final class VideoProcessingService: VideoProcessingServiceProtocol {
    // MARK: - Video Filtering

    func filteredPlayerItem(for asset: AVAsset, filter: FilterType) async -> AVPlayerItem {
        guard filter != .none else {
            return await AVPlayerItem(asset: asset)
        }

        _ = try? await asset.load(.duration)

        let composition = await VideoFilterManager.videoComposition(for: asset, filter: filter)

        let item = AVPlayerItem(asset: asset)
        await MainActor.run {
            item.videoComposition = composition
        }
        return item
    }

    // MARK: - Video Export

    func exportVideo(asset: AVAsset, filter: FilterType) async throws -> URL? {
        let docs = FileManager.default.temporaryDirectory
        let outputURL = docs.appendingPathComponent("filtered.mov")
        try? FileManager.default.removeItem(at: outputURL)

        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        if filter != .none {
            let item = await VideoFilterManager.applyFilterAsync(filter, to: asset)
            exportSession.videoComposition = item.videoComposition
        }

        if #available(iOS 18, *) {
            try await exportSession.export()
            var completed = false
            var failedError: Error? = nil

            for await state in exportSession.states(updateInterval: 0.1) {
                switch state {
                case .waiting:
                    // Waiting to begin
                    break
                case .exporting(let progress):
                    print("Exporting: \(progress)")
                
                @unknown default:
                    break
                }
            }
            if completed {
                return outputURL
            } else if let error = failedError {
                print("❌ Export failed with error: \(error)")
                return nil
            } else {
                print("❌ Export failed or was cancelled.")
                return nil
            }
        } else {
            try await exportSession.export()
            if exportSession.status == .completed {
                return outputURL
            } else {
                print("❌ Export failed with status: \(exportSession.status)")
                return nil
            }
        }
    }

    func exportGIF(asset: AVAsset, filter: FilterType, startTime: Double = 0.0, endTime: Double? = nil, fps: Int = 6) async throws -> URL? {
        let docs = FileManager.default.temporaryDirectory
        let filteredURL = docs.appendingPathComponent("filtered.mov")
        try? FileManager.default.removeItem(at: filteredURL)

        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
        exportSession.outputURL = filteredURL
        exportSession.outputFileType = .mov

        if filter != .none {
            let item = await VideoFilterManager.applyFilterAsync(filter, to: asset)
            exportSession.videoComposition = item.videoComposition
        }

        if #available(iOS 18, *) {
            try await exportSession.export()
            for await state in exportSession.states(updateInterval: 0.1) {
                switch state {
                case .pending:
                    print("Pending")
                case .waiting:
                    print("Waiting...")
                case .exporting(let progress):
                    print("Exporting: \(progress.fractionCompleted)")
                @unknown default:
                    break
                }
            }
            // If we got here with no error, the export succeeded
                    let filteredAsset = AVURLAsset(url: filteredURL)
            let clipEnd: Double
            if let endTime = endTime {
                clipEnd = endTime
            } else {
                clipEnd = try await filteredAsset.load(.duration).seconds
            }
                    let duration = max(0, clipEnd - startTime)
                    let gifURL = try await self.exportGIFFrames(from: filteredAsset, startTime: startTime, maxDuration: duration, fps: fps, filter: filter)
                    return gifURL
        } else {
            try await exportSession.export()
            if exportSession.status == .completed {
                let filteredAsset = AVURLAsset(url: filteredURL)
                let clipEnd: Double
                if let endTime = endTime {
                    clipEnd = endTime
                } else {
                    clipEnd = try await filteredAsset.load(.duration).seconds
                }
                let duration = max(0, clipEnd - startTime)
                let gifURL = try await self.exportGIFFrames(from: filteredAsset, startTime: startTime, maxDuration: duration, fps: fps, filter: filter)
                return gifURL
            } else {
                print("❌ Filtered export failed with status: \(exportSession.status)")
            }
        }
        return nil
    }

    private func exportGIFFrames(from asset: AVAsset, startTime: Double = 0.0, maxDuration: Double = 5.0, fps: Int = 6, filter: FilterType = .none) async throws -> URL {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        let fullDuration: CMTime = try await asset.load(.duration)
        let clipDuration = min(maxDuration, fullDuration.seconds - startTime)
        let times: [CMTime] = stride(
            from: startTime,
            to: startTime + clipDuration,
            by: 1.0 / Double(fps)
        ).map {
            CMTime(seconds: $0, preferredTimescale: 600)
        }

        let docs = FileManager.default.temporaryDirectory
        let gifURL = docs.appendingPathComponent("output.gif")
        try? FileManager.default.removeItem(at: gifURL)

        guard let destination = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, times.count, nil) else {
            print("❌ Failed to create GIF destination")
            throw NSError(domain: "GIF", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create GIF destination"])
        }

        let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / Double(fps)]]
        let gifProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, gifProps as CFDictionary)

        for time in times {
            do {
                if #available(iOS 18, *) {
                    let cgImage = try await withCheckedThrowingContinuation { continuation in
                        generator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
                            if let cgImage = cgImage {
                                continuation.resume(returning: cgImage)
                            } else {
                                continuation.resume(throwing: error ?? NSError(domain: "GIF", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to generate CGImage"]))
                            }
                        }
                    }
                    let ciImage = CIImage(cgImage: cgImage)
                    let filtered = VideoFilterManager.applyFilter(ciImage, type: filter)
                    let context = CIContext()
                    if let output = context.createCGImage(filtered, from: filtered.extent) {
                        CGImageDestinationAddImage(destination, output, frameProps as CFDictionary)
                    }
                } else {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let ciImage = CIImage(cgImage: cgImage)
                    let filtered = VideoFilterManager.applyFilter(ciImage, type: filter)
                    let context = CIContext()
                    if let output = context.createCGImage(filtered, from: filtered.extent) {
                        CGImageDestinationAddImage(destination, output, frameProps as CFDictionary)
                    }
                }
            } catch {
                print("⚠️ Failed to get frame at \(time.seconds): \(error)")
            }
        }

        print("🔄 Saving GIF to Photos at \(gifURL.path)")
        if CGImageDestinationFinalize(destination) {
            saveToPhotos(url: gifURL)
        } else {
            print("❌ Failed to finalize GIF")
            throw NSError(domain: "GIF", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize GIF"])
        }
        return gifURL
    }

    private func saveToPhotos(url: URL) {
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            request.addResource(with: .photo, fileURL: url, options: options)
        } completionHandler: { success, error in
            if let error = error {
                print("❌ Failed to save: \(error)")
            } else {
                print("✅ Saved to Photos: \(url)")
            }
        }
    }

    // MARK: - Thumbnail Generation

    func generateThumbnails(from asset: AVAsset, frameCount: Int = 20) async -> [UIImage] {
        do {
            _ = try await asset.load(.duration)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 100, height: 100)

            let duration = try await asset.load(.duration)
            let times: [CMTime] = (0..<frameCount).map { i in
                let seconds = duration.seconds * Double(i) / Double(frameCount)
                return CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
            }

            // Parallel async thumbnail generation (iOS 18 async API)
            return try await withThrowingTaskGroup(of: (Int, UIImage?).self) { group in
                for (i, time) in times.enumerated() {
                    group.addTask {
                        // Use async thumbnail API
                        return await withCheckedContinuation { cgContinuation in
                            generator.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
                                let image = cgImage.map { UIImage(cgImage: $0) }
                                cgContinuation.resume(returning: (i, image))
                            }
                        }
                    }
                }
                var images = Array<UIImage?>(repeating: nil, count: frameCount)
                for try await (i, image) in group {
                    images[i] = image
                }
                return images.compactMap { $0 }
            }
        } catch {
            print("Failed to generate thumbnails: \(error)")
            return []
        }
    }
}
