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

@available(iOS 13.0, *)
struct ContentView: View {
    @StateObject private var viewModel = VideoEditorViewModel()
    @State private var isPickerPresented = false
    @State private var gifURL: URL? = nil

    var body: some View {
        VStack {
            // Video Player Section
            ZStack {
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                }
                if viewModel.isLoading {
                    Color.black.opacity(0.4)
                        .frame(height: 300)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2)
                        )
                }
            }

            // Filter Picker
            FilterPickerView(viewModel: viewModel)

            // Video Trimmer
            VideoTrimmerView(viewModel: viewModel)

            // Action Buttons
            HStack {
                Button("Import Video") {
                    isPickerPresented = true
                }

                Spacer()

                Button("Export") {
                    Task {
                        print("Export tapped — implement exportVideo logic if needed")
                    }
                }
                .disabled(viewModel.asset == nil)

                Button("Make a GIF") {
                    Task {
                        if let asset = viewModel.asset {
                            if let result = await VideoExporter.exportFilteredGIF(
                                asset: asset,
                                filter: viewModel.selectedFilter
                            ) {
                                DispatchQueue.main.async {
                                    gifURL = result
                                }
                            }
                        }
                    }
                }
            }
            .padding()

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
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            VideoImporter { result in
                if let result = result {
                    viewModel.handlePickerResult(result)
                }
            }
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
            HStack {
                ForEach(FilterType.allCases, id: \ .self) { filter in
                    Button(action: {
                        Task { await viewModel.applyFilter(filter) }
                    }) {
                        Text(filter.rawValue)
                            .padding()
                            .background(viewModel.selectedFilter == filter ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - VideoTrimmerView
@MainActor
struct VideoTrimmerView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    let thumbnailWidth: CGFloat = 40
    let thumbnailHeight: CGFloat = 60
    let handleWidth: CGFloat = 4
    let handleMinDistance: CGFloat = 10

    @GestureState private var isDraggingStart = false
    @GestureState private var isDraggingEnd = false

    var body: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(viewModel.thumbnails.indices, id: \ .self) { index in
                        Image(uiImage: viewModel.thumbnails[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: thumbnailWidth, height: thumbnailHeight)
                            .clipped()
                    }
                }
            }
            .frame(height: thumbnailHeight)

            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let duration = viewModel.asset?.duration.seconds ?? 0
                let pixelsPerSecond = duration > 0 ? totalWidth / duration : 0

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: CGFloat(viewModel.gifStartTime) * pixelsPerSecond)
                        .allowsHitTesting(false)

                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: totalWidth - CGFloat(viewModel.gifEndTime) * pixelsPerSecond)
                        .offset(x: CGFloat(viewModel.gifEndTime) * pixelsPerSecond)
                        .allowsHitTesting(false)

                    Rectangle()
                        .fill(Color.white)
                        .frame(width: handleWidth, height: thumbnailHeight)
                        .contentShape(Rectangle())
                        .offset(x: CGFloat(viewModel.gifStartTime) * pixelsPerSecond)
                        .gesture(
                            DragGesture()
                                .updating($isDraggingStart) { _, state, _ in
                                    state = true
                                }
                                .onChanged { value in
                                    let newTime = Double(min(max(0, value.location.x / pixelsPerSecond),
                                                             viewModel.gifEndTime - handleMinDistance / pixelsPerSecond))
                                    viewModel.gifStartTime = newTime
                                }
                        )
                        .zIndex(10)

                    Rectangle()
                        .fill(Color.white)
                        .frame(width: handleWidth, height: thumbnailHeight)
                        .contentShape(Rectangle())
                        .offset(x: CGFloat(viewModel.gifEndTime) * pixelsPerSecond)
                        .gesture(
                            DragGesture()
                                .updating($isDraggingEnd) { _, state, _ in
                                    state = true
                                }
                                .onChanged { value in
                                    let newTime = Double(max(min(duration, value.location.x / pixelsPerSecond),
                                                             viewModel.gifStartTime + handleMinDistance / pixelsPerSecond))
                                    viewModel.gifEndTime = newTime
                                }
                        )
                        .zIndex(10)
                }
                .frame(height: thumbnailHeight)
            }
            .frame(height: thumbnailHeight)
            .zIndex(20)
        }
    }
}
#endif
