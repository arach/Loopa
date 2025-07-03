import SwiftUI

struct BrailleSpinnerView: View {
    @State private var frameIndex = 0
    private let frames = ["⠋","⠙","⠚","⠞","⠖","⠦","⠴","⠲","⠳","⠓"]
    private let timer = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(frames[frameIndex])
            .font(.system(size: 18, weight: .regular, design: .monospaced))
            .foregroundColor(.white)
            .frame(width: 22, alignment: .center)
            .onReceive(timer) { _ in
                frameIndex = (frameIndex + 1) % frames.count
            }
    }
}
