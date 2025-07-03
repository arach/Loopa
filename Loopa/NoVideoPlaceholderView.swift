import SwiftUI

struct NoVideoPlaceholderView: View {
    var onImport: () -> Void
    var onShoot: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack{
                Circle()
                    .fill(Color.secondary.opacity(0.85))
                    .frame(width: 50, height: 80)
                Image(systemName: "film")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 90)
                    .foregroundColor(.white.opacity(0.95))
            }
            ZStack {
                Text("No video loaded")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Text("Import a video to get started")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.5))
            HStack(spacing: 16) {
                Button(action: onImport) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                Button(action: onShoot) {
                    Label("Shoot Video", systemImage: "camera")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct NoVideoPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        NoVideoPlaceholderView(onImport: {}, onShoot: {})
    }
} 
