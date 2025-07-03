//
//  VideoTrimmerView.swift
//  Loopa
//
//  Created by Arach Tchoupani on 2025-07-02.
//

import SwiftUI

struct VideoTrimmerView: View {
    @ObservedObject var viewModel: VideoEditorViewModel

    @State private var isLeftDragging = false
    @State private var isRightDragging = false

    // Constants
    private let thumbnailWidth: CGFloat = 40
    private let thumbnailHeight: CGFloat = 60
    private let handleWidth: CGFloat = 14
    private let handleCornerRadius: CGFloat = 4
    private let handleMinDistance: CGFloat = 10

    var body: some View {
        ZStack(alignment: .center) {
            // Decorative sprocket background (taller than thumbnails)
            Image("film_sprockets")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, minHeight: thumbnailHeight + 16, maxHeight: thumbnailHeight + 16)
                .clipped()
                .opacity(0.88)
                .zIndex(0)

            VStack(spacing: 0) {
                Spacer(minLength: 8) // breathing room above

                ZStack {
                    FilmStripThumbnailsView(
                        thumbnails: viewModel.thumbnails,
                        width: thumbnailWidth,
                        height: thumbnailHeight
                    )
                    GeometryReader { geometry in
                        let totalWidth = geometry.size.width
                        let duration = viewModel.asset?.duration.seconds ?? 10
                        let pixelsPerSecond = duration > 0 ? totalWidth / duration : 0

                        let leftXRaw = CGFloat(viewModel.gifStartTime) * pixelsPerSecond - handleWidth / 2
                        let leftX = leftXRaw < 0.1 ? 0 : leftXRaw
                        let rightX = max(0, CGFloat(viewModel.gifEndTime) * pixelsPerSecond - handleWidth / 2)

                        ZStack(alignment: .leading) {
                            TrimOverlayView(
                                totalWidth: totalWidth,
                                startTime: viewModel.gifStartTime,
                                endTime: viewModel.gifEndTime,
                                pixelsPerSecond: pixelsPerSecond,
                                height: thumbnailHeight
                            )

                            // Left Handle
                            TrimHandleView(
                                color: .yellow,
                                height: thumbnailHeight,
                                cornerRadius: handleCornerRadius
                            )
                            .scaleEffect(isLeftDragging ? 1.18 : 1.0)
                            .shadow(color: Color.yellow.opacity(0.40), radius: isLeftDragging ? 10 : 5)
                            .offset(x: leftX)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newTime = Double(min(max(0, value.location.x / pixelsPerSecond),
                                                                 viewModel.gifEndTime - handleMinDistance / pixelsPerSecond))
                                        viewModel.gifStartTime = newTime
                                        isLeftDragging = true
                                    }
                                    .onEnded { value in
                                        // withAnimation(.spring(response: 0.27, dampingFraction: 0.57)) {
                                            let newTime = Double(min(max(0, value.location.x / pixelsPerSecond),
                                                                     viewModel.gifEndTime - handleMinDistance / pixelsPerSecond))
                                            viewModel.gifStartTime = newTime
                                        // }
                                        isLeftDragging = false
                                    }
                            )
                            .zIndex(10)

                            // Right Handle
                            TrimHandleView(
                                color: .yellow,
                                height: thumbnailHeight,
                                cornerRadius: handleCornerRadius
                            )
                            .scaleEffect(isRightDragging ? 1.18 : 1.0)
                            .shadow(color: Color.yellow.opacity(0.40), radius: isRightDragging ? 10 : 5)
                            .offset(x: rightX)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newTime = Double(max(min(duration, value.location.x / pixelsPerSecond),
                                                                 viewModel.gifStartTime + handleMinDistance / pixelsPerSecond))
                                        viewModel.gifEndTime = newTime
                                        isRightDragging = true
                                    }
                                    .onEnded { value in
                                        // withAnimation(.spring(response: 0.27, dampingFraction: 0.57)) {
                                            let newTime = Double(max(min(duration, value.location.x / pixelsPerSecond),
                                                                     viewModel.gifStartTime + handleMinDistance / pixelsPerSecond))
                                            viewModel.gifEndTime = newTime
                                        // }
                                        isRightDragging = false
                                    }
                            )
                            .zIndex(10)
                        }
                        .frame(height: thumbnailHeight)
                    }
                    .frame(height: thumbnailHeight)
                }

                Spacer(minLength: 8) // breathing room below
            }
            .zIndex(1)
        }
        .frame(height: thumbnailHeight + 16)
    }
}

// MARK: - Thumbnails or Placeholders
struct FilmStripThumbnailsView: View {
    let thumbnails: [UIImage]
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                if thumbnails.isEmpty {
                    ForEach(0..<10, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: width, height: height)
                            .cornerRadius(2)
                    }
                } else {
                    ForEach(thumbnails.indices, id: \.self) { idx in
                        Image(uiImage: thumbnails[idx])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: height)
                            .clipped()
                            .cornerRadius(2)
                    }
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Dimming Overlay
struct TrimOverlayView: View {
    let totalWidth: CGFloat
    let startTime: Double
    let endTime: Double
    let pixelsPerSecond: CGFloat
    let height: CGFloat

    var body: some View {
        // Left dim
        Rectangle()
            .fill(Color.black.opacity(0.32))
            .frame(width: CGFloat(startTime) * pixelsPerSecond)
            .allowsHitTesting(false)
        // Right dim
        Rectangle()
            .fill(Color.black.opacity(0.32))
            .frame(width: totalWidth - CGFloat(endTime) * pixelsPerSecond)
            .offset(x: CGFloat(endTime) * pixelsPerSecond)
            .allowsHitTesting(false)
    }
}

// MARK: - Handle
struct TrimHandleView: View {
    let color: Color
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color)
            .frame(width: 14, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.28), radius: 4, x: 0, y: 1)
            .contentShape(Rectangle().inset(by: -10))
    }
}
