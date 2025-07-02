//
//  FilmStripView.swift
//  Loopa
//
//  Created by Arach Tchoupani on 2025-07-01.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

@available(iOS 13.0, *)
struct FilmStripView: View {
    let thumbnails: [UIImage]
    @Binding var trimStart: CGFloat
    @Binding var trimEnd: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // ScrollView with thumbnails
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(thumbnails.indices, id: \.self) { index in
                            Image(uiImage: thumbnails[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 60)
                                .clipped()
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 60)

                // Overlay to dim unselected areas and drag handles
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: trimStart)
                        .allowsHitTesting(false)

                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: geometry.size.width - trimEnd)
                        .offset(x: trimEnd)
                        .allowsHitTesting(false)

                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 8, height: 60)
                            .contentShape(Rectangle())
                            .offset(x: trimStart - 4)
                            .zIndex(1)
                            .background(Color.clear)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        trimStart = min(max(0, value.location.x), trimEnd - 10)
                                    }
                            )

                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 8, height: 60)
                            .contentShape(Rectangle())
                            .offset(x: trimEnd - 4)
                            .zIndex(1)
                            .background(Color.clear)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        trimEnd = max(min(geo.size.width, value.location.x), trimStart + 10)
                                    }
                            )
                    }
                }
            }
        }
        .frame(height: 60)
    }
}
#endif
