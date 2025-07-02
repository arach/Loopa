#if canImport(UIKit)
import SwiftUI
import AVFoundation
import PhotosUI
import CoreImage
import UIKit

@available(iOS 13.0, *)
public class VideoEditorViewModel: ObservableObject {
    @Published public var player: AVPlayer?
    @Published public var asset: AVAsset?
    @Published public var selectedFilter: FilterType = .none
    @Published public var thumbnails: [UIImage] = []
    @Published public var gifStartTime: Double = 0
    @Published public var gifEndTime: Double = 1
    @Published public var trimStart: Double = 0.0
    @Published public var trimEnd: Double = 0.0
    @Published public var duration: Double = 1
    @Published public var isLoading: Bool = false

    private func setOnMain<T>(_ keyPath: ReferenceWritableKeyPath<VideoEditorViewModel, T>, _ value: T, label: String) {
        if Thread.isMainThread {
            self[keyPath: keyPath] = value
            print("Set \(label) on main thread")
        } else {
            DispatchQueue.main.async {
                self[keyPath: keyPath] = value
                print("Set \(label) on main thread (from background)")
            }
        }
    }

    func handlePickerResult(_ result: PHPickerResult) {
        print("handlePickerResult called")
        guard result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else { print("Picker result does not conform to movie type"); setOnMain(\Self.isLoading, false, label: "isLoading"); return }
        setOnMain(\Self.isLoading, true, label: "isLoading")
        print("Started loading file representation")
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
            if let error = error {
                print("Error loading file representation: \(error)")
            }
            guard let url = url else { print("No URL returned from picker"); self.setOnMain(\Self.isLoading, false, label: "isLoading"); return }
            print("Got file URL from picker: \(url)")
            let copiedURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: copiedURL)
            do {
                try FileManager.default.copyItem(at: url, to: copiedURL)
                print("Copied video to temp directory: \(copiedURL)")
            } catch {
                print("Copy failed: \(error)")
                self.setOnMain(\Self.isLoading, false, label: "isLoading")
                return
            }

            DispatchQueue.main.async {
                print("Setting asset and generating thumbnails")
                self.setOnMain(\Self.asset, AVURLAsset(url: copiedURL), label: "asset")
                self.generateThumbnails(from: self.asset!)
                Task {
                    print("Calling applyFilter(.none)")
                    await self.applyFilter(.none)
                }
            }
        }
    }

    func applyFilter(_ filter: FilterType) async {
        print("applyFilter called with filter: \(filter)")
        guard let asset = asset else {
            print("No asset to apply filter to")
            setOnMain(\Self.isLoading, false, label: "isLoading");
            return
        }
        setOnMain(\Self.isLoading, true, label: "isLoading")
        setOnMain(\Self.selectedFilter, filter, label: "selectedFilter")
        print("Calling VideoFilterManager.applyFilterAsync")
        let item = await VideoFilterManager.applyFilterAsync(filter, to: asset)
        DispatchQueue.main.async {
            print("Setting player and updating duration")
            self.setOnMain(\Self.player, AVPlayer(playerItem: item), label: "player")
            let duration = asset.duration.seconds
            if duration > 0 {
                self.setOnMain(\Self.duration, duration, label: "duration")
                self.setOnMain(\Self.gifEndTime, duration, label: "gifEndTime")
            }
            self.setOnMain(\Self.isLoading, false, label: "isLoading")
            print("applyFilter finished, isLoading set to false")
        }
    }

    func generateThumbnails(from asset: AVAsset, frameCount: Int = 20) {
        let duration = asset.duration
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 100, height: 100)

        let times: [NSValue] = (0..<frameCount).map { i in
            let seconds = CMTimeGetSeconds(duration) * Double(i) / Double(frameCount)
            return NSValue(time: CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
        }

        var images: [UIImage] = []
        generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, _, _ in
            if let cgImage = cgImage {
                DispatchQueue.main.async {
                    let image = UIImage(cgImage: cgImage)
                    images.append(image)
                    self.setOnMain(\Self.thumbnails, images, label: "thumbnails")
                    print("Updated thumbnails on main thread: \(Thread.isMainThread)")
                }
            }
        }
    }
}
#endif
