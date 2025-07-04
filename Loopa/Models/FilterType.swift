//
//  VideoFilterManager.swift
//  Loopa
//
//  Created by Arach Tchoupani on 2025-07-01.
//

#if canImport(UIKit)
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

@available(iOS 13.0, *)


extension VideoFilterManager {
    static func trimAsset(_ asset: AVAsset, startTime: CMTime, endTime: CMTime) -> AVAsset? {
        let composition = AVMutableComposition()
        guard
            let assetTrack = asset.tracks(withMediaType: .video).first,
            let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            return nil
        }

        let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)

        do {
            try compositionTrack.insertTimeRange(
                timeRange,
                of: assetTrack,
                at: .zero
            )

            // Copy audio track if it exists
            if let audioTrack = asset.tracks(withMediaType: .audio).first,
               let compositionAudioTrack = composition.addMutableTrack(
                   withMediaType: .audio,
                   preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                try compositionAudioTrack.insertTimeRange(
                    timeRange,
                    of: audioTrack,
                    at: .zero
                )
            }

            return composition
        } catch {
            print("Failed to trim asset: \(error)")
            return nil
        }
    }
}

public enum FilterType: String, CaseIterable, Sendable {
    case none = "None"
    case sepia = "Sepia"
    case comic = "Comic"
    case posterize = "Posterize"
    case noir = "Noir"
    case mono = "Mono"
    case blur = "Blur"
    case vignette = "Vignette"
    case bloom = "Bloom"
    case pixelate = "Pixelate"
    case invert = "Invert"
}

extension VideoFilterManager {
    
    static func applyFilterAsync(_ filter: FilterType, to asset: AVAsset) async -> AVPlayerItem {
        guard filter != .none else {
            return await AVPlayerItem(asset: asset)
        }

        // Ensure async property is loaded (Swift 6 compatibility)
        _ = try? await asset.load(.duration)

        let composition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
            let source = request.sourceImage.clampedToExtent()
            let outputImage = apply(filter: filter, to: source)
            request.finish(with: outputImage.cropped(to: request.sourceImage.extent), context: nil)
        })

        let item = await AVPlayerItem(asset: asset)
        item.videoComposition = composition
        return item
    }

    static func applyFilter(_ image: CIImage, type: FilterType) -> CIImage {
        return apply(filter: type, to: image)
    }

    static func videoComposition(for asset: AVAsset, filter: FilterType) async -> AVVideoComposition? {
        await withCheckedContinuation { continuation in
            AVVideoComposition.videoComposition(
                with: asset,
                applyingCIFiltersWithHandler: { request in
                    let source = request.sourceImage.clampedToExtent()
                    let outputImage = apply(filter: filter, to: source)
                    request.finish(with: outputImage.cropped(to: request.sourceImage.extent), context: nil)
                },
                completionHandler: { composition, error in
                    continuation.resume(returning: composition)
                }
            )
        }
    }
}
#endif
