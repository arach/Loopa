#if canImport(UIKit)
import AVFoundation

extension AVAsset {
    /// Safe duration: synchronous if already loaded, otherwise async-load
    func safeDuration() async -> Double {
        if statusOfValue(forKey: "duration", error: nil) == .loaded {
            return duration.seconds
        }
        do {
            let cmTime = try await load(.duration)
            return cmTime.seconds
        } catch {
            print("Failed to load duration: \(error)")
            return 0
        }
    }
}
#endif
