import SwiftUI

#if DEBUG
struct DebugMenu: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var isPresented = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Slide-out minimalist drawer from the top
            VStack(spacing: 0) {
                if isPresented {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Button(action: {
                                viewModel.isLoading.toggle()
                            }) {
                                Text(viewModel.isLoading ? "Stop Loading" : "Start Loading")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            Button(action: {
                                viewModel.waveAnimated = true
                            }) {
                                Text("Wave Filters")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            // Add more debug buttons here in the HStack
                        }
                        // For future: replace HStack with a grid for more actions
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                            .background(Color.black.opacity(0.95))
                    )
                    .overlay(
                        // Subtle shadow and line at the bottom only
                        VStack(spacing: 0) {
                            Spacer()
                            Rectangle()
                                .fill(Color.black.opacity(0.18))
                                .frame(height: 1)
                                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1001)
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.15), value: isPresented)

            // Ladybug button (always visible, toggles drawer)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { withAnimation { isPresented.toggle() } }) {
                        Image(systemName: "ladybug.fill")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                            .rotationEffect(.degrees(isPresented ? 180 : 0))
                            .animation(.easeInOut(duration: 0.15), value: isPresented)
                    }
                    .padding()
                }
                Spacer()
            }
            .zIndex(1002)
        }
        .allowsHitTesting(true)
    }
}

// VisualEffectBlur for background blur
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Helper extension for corner radius on specific corners
private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = 12.0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
#endif 
