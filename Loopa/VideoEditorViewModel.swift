#if canImport(UIKit)
@preconcurrency import AVFoundation
import SwiftUI
import PhotosUI
import CoreImage
import UIKit

@MainActor
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
    @Published public var gifFPS: Int = 6
    @Published public var loadedDuration: Double? = nil
    @Published public var loadingThumbnail: UIImage? = nil
    @Published public var filteredThumbnails: [FilterType: UIImage] = [:]
    @Published public var currentTime: Double = 0

    private let filterKey = "selectedFilter"
    private let fpsKey = "gifFPS"
    private let videoService = VideoProcessingService()
    private var timeObserverToken: Any?

    public init() {
        if let saved = UserDefaults.standard.string(forKey: filterKey),
           let f = FilterType(rawValue: saved) {
            self.selectedFilter = f
        }
        let savedFPS = UserDefaults.standard.integer(forKey: self.fpsKey)
        if savedFPS > 0 { self.gifFPS = savedFPS }
    }

    private func setOnMain<T>(_ keyPath: ReferenceWritableKeyPath<VideoEditorViewModel, T>, _ value: T, label: String) {
        if Thread.isMainThread {
            self[keyPath: keyPath] = value
            print("Set \(label) on main thread")
            if label == "selectedFilter", let raw = (value as? FilterType)?.rawValue {
                UserDefaults.standard.set(raw, forKey: self.filterKey)
            }
            if label == "gifFPS", let fps = value as? Int {
                UserDefaults.standard.set(fps, forKey: self.fpsKey)
            }
        } else {
            DispatchQueue.main.async {
                self[keyPath: keyPath] = value
                print("Set \(label) on main thread (from background)")
                if label == "selectedFilter", let raw = (value as? FilterType)?.rawValue {
                    UserDefaults.standard.set(raw, forKey: self.filterKey)
                }
                if label == "gifFPS", let fps = value as? Int {
                    UserDefaults.standard.set(fps, forKey: self.fpsKey)
                }
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
                Task { [weak self] in
                    guard let self = self else { return }
                    print("Setting asset and generating thumbnails")
                    let newAsset = AVURLAsset(url: copiedURL)
                    self.setOnMain(\Self.asset, newAsset, label: "asset")
                    if let asset = self.asset {
                        do {
                            let cmTime = try await asset.load(.duration)
                            self.loadedDuration = cmTime.seconds
                            if CMTimeCompare(cmTime, CMTime(seconds: 0, preferredTimescale: cmTime.timescale)) > 0 {
                                let start = max(0, CMTimeGetSeconds(cmTime) * 0.45)
                                let end = min(CMTimeGetSeconds(cmTime), start + 3)
                                self.gifStartTime = start
                                self.gifEndTime = end
                            }
                            await self.generateThumbnails(from: asset)
                            print("Calling applyFilter(.none)")
                            await self.applyFilter(.none)
                        } catch {
                            print("Failed to load duration: \(error)")
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func applyFilter(_ filter: FilterType) async {
        print("applyFilter called with filter: \(filter)")
        guard let asset = asset else {
            print("No asset to apply filter to")
            isLoading = false
            return
        }
        isLoading = true
        selectedFilter = filter

        let item = await videoService.filteredPlayerItem(for: asset, filter: filter)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        addPlayerTimeObserver(player: newPlayer)

        do {
            let duration = try await asset.load(.duration).seconds
            if duration > 0 {
                self.duration = duration
            }
        } catch {
            print("Failed to load duration in applyFilter: \(error)")
        }
        isLoading = false
        print("applyFilter finished, isLoading set to false")
    }

    func generateThumbnails(from asset: AVAsset, frameCount: Int = 20) async {
        let images = await videoService.generateThumbnails(from: asset, frameCount: frameCount)
        setOnMain(\Self.thumbnails, images, label: "thumbnails")
    }

    @MainActor
    func shootVideo() {
        print("Shoot video tapped — implement camera logic here.")
        // TODO: Implement camera capture logic
    }

    func generateLoadingThumbnail(for asset: AVAsset) {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        DispatchQueue.global(qos: .userInitiated).async {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let image = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self.loadingThumbnail = image
                    self.generateFilteredThumbnails(from: image)
                }
            } else {
                DispatchQueue.main.async {
                    self.loadingThumbnail = nil
                    self.filteredThumbnails = [:]
                }
            }
        }
    }

    func generateFilteredThumbnails(from base: UIImage) {
        var result: [FilterType: UIImage] = [:]
        guard let ciImage = CIImage(image: base) else {
            self.filteredThumbnails = [:]
            return
        }
        let context = CIContext()
        for filter in FilterType.allCases {
            let filteredCI = VideoFilterManager.apply(filter: filter, to: ciImage)
            if let cgImage = context.createCGImage(filteredCI, from: filteredCI.extent) {
                result[filter] = UIImage(cgImage: cgImage)
            }
        }
        self.filteredThumbnails = result
    }

    func handleCapturedVideo(_ url: URL) {
        // Copy to temp directory to ensure we have access
        let copiedURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: copiedURL)
        do {
            try FileManager.default.copyItem(at: url, to: copiedURL)
        } catch {
            print("Copy failed: \(error)")
        }
        DispatchQueue.main.async {
            let asset = AVURLAsset(url: copiedURL)
            self.asset = asset
            self.generateLoadingThumbnail(for: asset)
            Task { await self.generateThumbnails(from: asset) }
            Task { await self.applyFilter(.none) }
        }
    }

    private func addPlayerTimeObserver(player: AVPlayer?) {
        // Remove old observer if any
        if let token = timeObserverToken, let oldPlayer = self.player {
            oldPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
        guard let player = player else { return }
        // Observe every 1/30th of a second
        let interval = CMTime(seconds: 1.0/30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
}
#endif
