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

@available(iOS 13.0, *)
struct ContentView: View {
    @StateObject private var viewModel = VideoEditorViewModel()
    @State private var isPickerPresented = false
    @State private var gifURL: URL? = nil
    @State private var showGifCreatedAlert = false
    @State private var showGifBanner = false
    @State private var isMakingGif = false

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
                .padding(.top, 40)
                .padding(.bottom, 24)

                // Video Preview or Placeholder
                ZStack {
                    if let player = viewModel.player {
                        VideoPlayer(player: player)
                            .frame(height: 240)
                            .clipped()
                    } else {
                        NoVideoPlaceholderView(
                            onImport: { isPickerPresented = true },
                            onShoot: { viewModel.shootVideo() }
                        )
                    }
                    // Loader overlay (section only)
                    if viewModel.isLoading {
                        if let thumbnail = viewModel.loadingThumbnail {
                            ZStack {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 240)
                                    .clipped()
                                Color.black.opacity(0.95)
                                AnimatedLoadingText()
                            }
                            
                        } else {
                            ZStack {
                                Color.black.opacity(0.95)
                                AnimatedLoadingText()
                            }
                            
                        }
                    }
                }
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.1))
                .padding(.bottom, 24)

                // FILTERS Section
                Text("FILTERS")
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                FilterPickerView(viewModel: viewModel)
                    .padding(.bottom, 20)

                // TRIM SELECTION Section
                if !viewModel.thumbnails.isEmpty {
                    Text("TRIM SELECTION")
                        .font(.caption).bold()
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    VideoTrimmerView(viewModel: viewModel)
                        .padding(.vertical, 8)
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

                // Action Buttons
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
                    GIFView(gifURL: gifURL)
                        .frame(height: 150)
                        .contextMenu {
                            Button("Copy to Clipboard") {
                                do {
                                    let gifData = try Data(contentsOf: gifURL)
                                    UIPasteboard.general.setData(gifData, forPasteboardType: UTType.gif.identifier)
                                } catch {
                                    print("Failed to copy GIF to clipboard: \(error)")
                                }
                            }

                            Button("Save to Photos") {
                                PHPhotoLibrary.shared().performChanges {
                                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: gifURL)
                                } completionHandler: { success, error in
                                    if let error = error {
                                        print("Save to Photos failed: \(error)")
                                    } else {
                                        print("GIF saved to Photos")
                                    }
                                }
                            }
                        }
                    Button {
                        do {
                            let gifData = try Data(contentsOf: gifURL)
                            UIPasteboard.general.setData(gifData, forPasteboardType: UTType.gif.identifier)
                        } catch {
                            print("Failed to copy GIF to clipboard: \(error)")
                        }
                    } label: {
                        Label("Copy GIF", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .padding(.bottom)
                }
            }
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
            // Celebratory banner when GIF is ready
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
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
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(viewModel.selectedFilter == filter ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.selectedFilter == filter ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                    .frame(width: 56, height: 56)
                                    .background(viewModel.selectedFilter == filter ? Color.accentColor.opacity(0.1) : Color.clear)
                            }
                            Text(filter.rawValue)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(4)
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

#endif
