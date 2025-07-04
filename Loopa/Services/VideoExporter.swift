#if canImport(UIKit)
import AVFoundation
import Photos
import ImageIO
import UniformTypeIdentifiers
import UIKit

@available(iOS 14.0, *)
class VideoExporter {
    static func export(asset: AVAsset, filter: FilterType) async {
        let docs = FileManager.default.temporaryDirectory
        let outputURL = docs.appendingPathComponent("filtered.mov")

        // Remove if existing
        try? FileManager.default.removeItem(at: outputURL)

        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        if filter != .none {
            let item = await VideoFilterManager.applyFilterAsync(filter, to: asset)
            exportSession.videoComposition = item.videoComposition
        }

        do {
            try await exportSession.export()
            if exportSession.status == .completed {
                saveToPhotos(url: outputURL)
            }
        } catch {
            print("Export failed: \(error)")
        }
    }
    
    static func exportFilteredGIF(asset: AVAsset, filter: FilterType, startTime: Double = 0.0, endTime: Double? = nil) async -> URL? {
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

        do {
            try await exportSession.export()
            if exportSession.status == .completed {
                let filteredAsset = AVAsset(url: filteredURL)
                let clipEnd = endTime ?? filteredAsset.duration.seconds
                let duration = max(0, clipEnd - startTime)
                await exportGIF(from: filteredAsset, startTime: startTime, maxDuration: duration)
                return docs.appendingPathComponent("output.gif")
            } else {
                print("❌ Filtered export failed with status: \(exportSession.status)")
            }
        } catch {
            print("❌ Failed filtered export: \(error)")
        }
        return nil
    }

    static func exportGIF(from asset: AVAsset, startTime: Double = 0.0, maxDuration: Double = 5.0, fps: Int = 6, filter: FilterType = .none) async {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        let fullDuration: CMTime
        do {
            fullDuration = try await asset.load(.duration)
        } catch {
            print("Failed to load duration: \(error)")
            return
        }

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
            return
        }

        let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / Double(fps)]]
        let gifProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, gifProps as CFDictionary)

        for time in times {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let ciImage = CIImage(cgImage: cgImage)
                let filtered = VideoFilterManager.applyFilter(ciImage, type: filter)
                let context = CIContext()
                if let output = context.createCGImage(filtered, from: filtered.extent) {
                    CGImageDestinationAddImage(destination, output, frameProps as CFDictionary)
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
        }
    }

    private static func saveToPhotos(url: URL) {
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
}
#endif
