import SwiftUI

struct NoVideoPlaceholderView: View {
    var onImport: () -> Void
    var onShoot: () -> Void

    @State private var animate = false
    @State private var importBounce = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundColor(.gray.opacity(0.4))
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.1), value: animate)
            ZStack {
                Text("No video loaded")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: animate)
            }
            Text("Import a video to get started")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.5))
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: animate)
            HStack(spacing: 16) {
                Button(action: onImport) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                .scaleEffect(importBounce ? 1.15 : 1.0)
                .animation(.interpolatingSpring(stiffness: 220, damping: 8), value: importBounce)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: animate)
                Button(action: onShoot) {
                    Label("Shoot", systemImage: "camera")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: animate)
            }
        }
        .onAppear {
            animate = true
            // Trigger the bounce after 1.2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                importBounce = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    importBounce = false
                }
            }
        }
    }
}

struct NoVideoPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        NoVideoPlaceholderView(onImport: {}, onShoot: {})
    }
} 
