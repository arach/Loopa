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
                if let asset = viewModel.asset {
                    // Video player goes here
                } else {
                    NoVideoPlaceholderView(
                        onImport: { isPickerPresented = true },
                        onShoot: { viewModel.shootVideo() }
                    )
                }
            }
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.06))
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
            Text("TRIM SELECTION")
                .font(.caption).bold()
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)
            VideoTrimmerView(viewModel: viewModel)
                .padding(.vertical, 8)

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
        .frame(maxWidth: .infinity)
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
            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(action: {
                        Task { await viewModel.applyFilter(filter) }
                    }) {
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(viewModel.selectedFilter == filter ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                                .frame(width: 44, height: 44)
                                .background(viewModel.selectedFilter == filter ? Color.accentColor.opacity(0.1) : Color.clear)
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


#endif
