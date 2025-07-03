//
//  ContentView.swift
//  Loopa
//
//  Created by Arach Tchoupani on 2025-07-01.
//

#if canImport(UIKit)
import SwiftUI
import AVKit
import PhotosUI
import UIKit
import WebKit
import Combine

private let videoPreviewHeight: CGFloat = 240

@available(iOS 13.0, *)
struct ContentView: View {
    @StateObject private var viewModel = VideoEditorViewModel()
    @State private var isPickerPresented = false
    @State private var gifURL: URL? = nil
    @State private var showGifCreatedAlert = false
    @State private var showGifBanner = false
    @State private var isMakingGif = false
    @State private var isCameraPresented = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.accentColor)
                        Text("Create Magic")
                            .font(.title).bold()
                        Text("Turn videos into GIFs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    // Video preview section (refactored)
                    VideoPreviewSection(
                        player: viewModel.player,
                        isLoading: viewModel.isLoading,
                        hasAsset: viewModel.asset != nil,
                        onImport: { isPickerPresented = true },
                        onShoot: { isCameraPresented = true }
                    )

                    // FILTERS Section
                    VStack(spacing: 0) {
                        Text("FILTERS")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                            .padding(.top, 4)
                        ZStack {
                            if viewModel.isLoading {
                                HStack(spacing: 4) {
                                    ForEach(0..<6, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.12))
                                            .frame(width: 56, height: 56)
                                            .shimmer()
                                    }
                                }
                                
                                .padding(.horizontal)
                            } else {
                                FilterPickerView(viewModel: viewModel)
                                    .padding(.top, 12)
                                
                            }
                        }
                        .frame(height: 72) // Fixed height for filter section
                        .padding(.bottom, 5)
                    }

                    // TRIM SELECTION Section
                    VStack(spacing: 0) {
                            Text("TRIM SELECTION")
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.bottom, 4)
                                .padding(.top, 24)
                            ZStack {
                                VideoTrimmerView(viewModel: viewModel)
                                TrimmerPlayheadOverlay(
                                    currentTime: viewModel.currentTime,
                                    duration: viewModel.asset?.duration.seconds ?? 0
                                )
                            }
                            .frame(height: 76) // slightly taller to allow for overlay
                            
                            // Centered timer below trimmer
                            let relTime = max(0, min(viewModel.currentTime, viewModel.asset?.duration.seconds ?? 0))
                            let duration = viewModel.asset?.duration.seconds ?? 0
                            Text(String(format: "%02d:%02d.%01d / %02d:%02d.%01d",
                                Int(relTime) / 60, Int(relTime) % 60, Int((relTime * 10).truncatingRemainder(dividingBy: 10)),
                                Int(duration) / 60, Int(duration) % 60, Int((duration * 10).truncatingRemainder(dividingBy: 10))
                            ))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                    }
                    
                    // Drag instruction
                    HStack(spacing: 4) {
                        Image(systemName: "scissors")
                        Text("Drag to trim your GIF")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    // Advanced Settings
                    DisclosureGroup {
                        HStack {
                            Text("FPS:")
                            Picker("FPS", selection: $viewModel.gifFPS) {
                                ForEach([6,12,24,30], id: \.self) { fps in
                                    Text("\(fps)").tag(fps)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    } label: {
                        Label("Advanced Settings", systemImage: "gear")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 28)

                    // Action Buttons (always visible)
                    HStack(spacing: 16) {
                        Button {
                            isPickerPresented = true
                        } label: {
                            Label("New Video", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task {
                                if let asset = viewModel.asset {
                                    if let result = await VideoExporter.exportFilteredGIF(
                                        asset: asset,
                                        filter: viewModel.selectedFilter,
                                        startTime: viewModel.gifStartTime,
                                        endTime: viewModel.gifEndTime
                                    ) {
                                        DispatchQueue.main.async {
                                            gifURL = result
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Make GIF", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: 400)
                    .padding(.horizontal)
                    .padding(.bottom, 24)

                    if let gifURL = gifURL {
                        VStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 8)
                                GIFView(gifURL: gifURL)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.horizontal)
                            HStack(spacing: 16) {
                                Button(action: {
                                    do {
                                        let gifData = try Data(contentsOf: gifURL)
                                        UIPasteboard.general.setData(gifData, forPasteboardType: UTType.gif.identifier)
                                    } catch {
                                        print("Failed to copy GIF to clipboard: \(error)")
                                    }
                                }) {
                                    Label("Copy GIF", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                Button(action: {
                                    PHPhotoLibrary.shared().performChanges {
                                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: gifURL)
                                    } completionHandler: { success, error in
                                        if let error = error {
                                            print("Save to Photos failed: \(error)")
                                        } else {
                                            print("GIF saved to Photos")
                                        }
                                    }
                                }) {
                                    Label("Save to Photos", systemImage: "square.and.arrow.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                        // Celebratory banner
                        if showGifBanner {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("🎉 GIF Ready!")
                                        .font(.headline)
                                        .padding()
                                        .background(Color.green.opacity(0.95))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .shadow(radius: 8)
                                    Spacer()
                                }
                                .padding(.bottom, 40)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(100)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.4), value: viewModel.asset != nil)
            
            // Loader overlay for GIF creation
            if viewModel.isLoading && isMakingGif {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Creating your GIF...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .transition(.opacity)
            }
            #if DEBUG
            DebugMenu(viewModel: viewModel)
            #endif
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $isPickerPresented) {
            VideoImporter { result in
                if let result = result {
                    viewModel.handlePickerResult(result)
                }
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraKitView { url in
                viewModel.handleCapturedVideo(url)
            }
        }
        .alert(isPresented: $showGifCreatedAlert) {
            Alert(title: Text("GIF Ready!"), message: Text("The GIF has been copied to your clipboard."), dismissButton: .default(Text("OK")))
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - GIFView
struct GIFView: UIViewRepresentable {
    let gifURL: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.contentMode = .scaleAspectFit
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let data = try? Data(contentsOf: gifURL)
        if let data = data {
            uiView.load(data, mimeType: "image/gif", characterEncodingName: "", baseURL: gifURL.deletingLastPathComponent())
        }
    }
}

// MARK: - FilterPickerView
struct FilterPickerView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
//    HStack(spacing: 4) {
//        ForEach(0..<6, id: \.self) { _ in
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color.gray.opacity(0.12))
//                .frame(width: 56, height: 56)
//
//        }
//    }
//    .padding(.horizontal)
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(action: {
                        Task { await viewModel.applyFilter(filter) }
                    }) {
                        VStack {
                            if let thumb = viewModel.filteredThumbnails[filter] {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(viewModel.selectedFilter == filter ? Color.accentColor : Color.gray, lineWidth: 2)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(viewModel.selectedFilter == filter ? Color.accentColor : Color.gray, lineWidth: 1)
                                    .frame(width: 56, height: 56)
                                    .background(viewModel.selectedFilter == filter ? Color.accentColor.opacity(0.05) : Color.clear)
                                    .shimmer()
                            }
                            Text(filter.rawValue)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(3)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AnimatedLoadingText: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            BrailleSpinnerView()
                .frame(width: 22, alignment: .center)
            Text("loading")
                .font(.system(size: 13, weight: .light, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// Add shimmer effect modifier
extension View {
    func shimmer() -> some View {
        self
            .redacted(reason: .placeholder)
            .overlay(
                LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.6), Color.white.opacity(0.2)]), startPoint: .leading, endPoint: .trailing)
                    .rotationEffect(.degrees(30))
                    .offset(x: -100)
                    .animation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false), value: UUID())
            )
    }
}

struct VideoPreviewSection: View {
    let player: AVPlayer?
    let isLoading: Bool
    let hasAsset: Bool
    let onImport: () -> Void
    let onShoot: () -> Void

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .clipped()
            } else {
                NoVideoPlaceholderView(
                    onImport: onImport,
                    onShoot: onShoot
                )
            }
            if isLoading && !hasAsset {
                Color.black.opacity(0.95)
                    .overlay(
                        AnimatedLoadingText()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    )
            }
        }
        .frame(height: videoPreviewHeight)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06))
        .padding(.bottom, 12)
    }
}

struct TrimmerPlayheadOverlay: View {
    let currentTime: Double
    let duration: Double
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let progress = duration > 0 ? max(0, min(1, currentTime / duration)) : 0
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2, height: geometry.size.height)
                .offset(x: totalWidth * CGFloat(progress) - 1)
                .animation(.linear, value: currentTime)
                .zIndex(100)
        }
        .allowsHitTesting(false)
    }
}

#endif
