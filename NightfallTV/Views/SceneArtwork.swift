import SwiftUI

struct SceneArtwork: View {
    let kind: SceneKind
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if kind == .clock {
                    LinearGradient(colors: [Color(red: 0.025, green: 0.025, blue: 0.06), .black], startPoint: .top, endPoint: .bottom)
                } else if kind != .black, let image = UIImage(named: "\(kind == .gallery ? SceneKind.dunes.rawValue : kind.rawValue)-poster") {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
            }
        }.accessibilityHidden(true)
    }
}

struct FloatingClock: View {
    let date: Date
    let english: Bool
    let format24: Bool
    var large = false
    var body: some View {
        GeometryReader { geometry in
            let slot = Double(Int(date.timeIntervalSince1970 / 60) % 12)
            VStack(alignment: .leading, spacing: 16) {
                Text(clockText).font(.system(size: large ? 132 : 38, weight: .ultraLight, design: .rounded)).monospacedDigit()
                if large { Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(Locale(identifier: english ? "en_US" : "zh_CN")))).font(.title3) }
            }
            .foregroundStyle(.white.opacity(large ? 0.36 : 0.45))
            .position(x: geometry.size.width * (large ? 0.5 + sin(slot * 1.7) * 0.1 : 0.82 + sin(slot) * 0.035),
                      y: geometry.size.height * (large ? 0.5 + cos(slot * 1.3) * 0.1 : 0.85 + cos(slot) * 0.025))
        }
        .accessibilityLabel(clockText)
    }
    private var clockText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: english ? "en_US" : "zh_CN")
        formatter.dateFormat = format24 ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
}

struct GalleryArtwork: View {
    let address: String?
    @State private var image: UIImage?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().frame(width: geometry.size.width, height: geometry.size.height)
                        .transition(.opacity)
                } else if address == nil {
                    SceneArtwork(kind: .dunes).opacity(0.35)
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 88, weight: .ultraLight)).foregroundStyle(.white.opacity(0.18))
                }
            }
        }
        .task(id: address) {
            image = nil
            guard let address else { return }
            let result = try? await PhotoLoader.shared.load(address)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.5)) { image = result }
        }
        .accessibilityHidden(true)
    }
}
