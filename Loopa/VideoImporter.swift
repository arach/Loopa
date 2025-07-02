//
//  VideoImporter.swift
//  Loopa
//
//  Created by Arach Tchoupani on 2025-07-01.
//

#if canImport(UIKit)
import SwiftUI
import PhotosUI
import UIKit

@available(iOS 14.0, *)
struct VideoImporter: UIViewControllerRepresentable {
    let onPick: (PHPickerResult?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (PHPickerResult?) -> Void

        init(onPick: @escaping (PHPickerResult?) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            onPick(results.first)
        }
    }
}
#endif
