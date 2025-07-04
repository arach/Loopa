import SwiftUI
import UIKit

struct CameraKitView: View {
    var onVideoCaptured: (URL) -> Void
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        #if targetEnvironment(simulator)
        // Mock camera UI for simulator
        VStack(spacing: 24) {
            Text("Simulator Camera")
                .font(.title)
                .padding(.top, 40)
            Image(systemName: "video.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.gray)
            Button("Simulate Video Capture") {
                // Try to load from Media/coffee.mov as a dev asset
                if let url = Bundle.main.url(forResource: "coffee", withExtension: "mov", subdirectory: "Media") ?? Bundle.main.url(forResource: "coffee", withExtension: "mov") {
                    onVideoCaptured(url)
                } else {
                    print("[CameraKit] Could not find Media/coffee.mov in bundle. Make sure it's listed as a Development Asset.")
                }
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
        #else
        // Real camera for device
        CameraKitPicker(onVideoCaptured: { url in
            onVideoCaptured(url)
            presentationMode.wrappedValue.dismiss()
        })
        #endif
    }
}

// UIKit wrapper for UIImagePickerController (real camera)
struct CameraKitPicker: UIViewControllerRepresentable {
    var onVideoCaptured: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.delegate = context.coordinator
        picker.videoQuality = .typeHigh
        picker.cameraCaptureMode = .video
        picker.videoMaximumDuration = 60
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraKitPicker

        init(_ parent: CameraKitPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.onVideoCaptured(url)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {}
    }
} 