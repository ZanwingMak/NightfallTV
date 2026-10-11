import SwiftUI

struct SceneArtwork: View {
    let kind: SceneKind
    var time: Double = 32

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(.black))
            switch kind {
            case .black: break
            case .aurora: aurora(&context, size, time)
            case .stars: stars(&context, size, time)
            case .ocean: ocean(&context, size, time)
            case .ember: ember(&context, size, time)
            case .dunes, .gallery: dunes(&context, size, time)
            case .prism: prism(&context, size, time)
            case .rain: rain(&context, size, time)
            case .clock: backdrop(&context, size, [Color(red: 0.025, green: 0.025, blue: 0.06), .black])
            }
        }
        .accessibilityHidden(true)
    }

    /// 创建稳定的伪随机数，让粒子随时间连续移动而非重新随机闪烁。
    private func noise(_ seed: Double) -> Double {
        let value = sin(seed * 127.1 + 311.7) * 43758.5453
        return value - floor(value)
    }

    /// 以竖直渐变填充整个画面。
    private func backdrop(_ context: inout GraphicsContext, _ size: CGSize, _ colors: [Color]) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    /// 绘制柔和的径向光晕，作为极光、月亮和暖光的基础。
    private func glow(_ context: inout GraphicsContext, _ center: CGPoint, _ radius: CGFloat, _ color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                     with: .radialGradient(Gradient(colors: [color, color.opacity(0)]), center: center, startRadius: 0, endRadius: radius))
    }

    /// 绘制夜空的点状星光，位置由固定种子决定。
    private func starDots(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double, count: Int = 120) {
        for i in 0..<count {
            let seed = Double(i + 1)
            let x = (noise(seed) + t * 0.0008 * (0.5 + noise(seed + 9))).truncatingRemainder(dividingBy: 1) * size.width
            let y = noise(seed + 77) * size.height * 0.88
            let r = (0.7 + noise(seed + 200) * 1.4) * max(0.6, size.width / 1920)
            let alpha = 0.2 + 0.6 * (0.5 + 0.5 * sin(t * 0.3 + seed))
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha)))
        }
    }

    /// 画出流动的半透明极光幕、星点与暗色群山。
    private func aurora(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        backdrop(&context, size, [Color(red: 0.015, green: 0.035, blue: 0.095), Color(red: 0.015, green: 0.07, blue: 0.105), .black])
        glow(&context, CGPoint(x: size.width * 0.62, y: size.height * 0.34), size.width * 0.48, Color.cyan.opacity(0.1))
        starDots(&context, size, t, count: 140)
        for layer in 0..<4 {
            let l = Double(layer)
            var ribbon = Path()
            for step in 0...140 {
                let x = Double(step) / 140
                let y = 0.3 + l * 0.05 + sin(x * 5.4 + t * 0.07 + l * 0.55) * 0.14 + sin(x * 12 - t * 0.05) * 0.018
                let point = CGPoint(x: x * size.width, y: y * size.height)
                if step == 0 { ribbon.move(to: point) } else { ribbon.addLine(to: point) }
            }
            for step in (0...140).reversed() {
                let x = Double(step) / 140
                let y = 0.3 + l * 0.05 + sin(x * 5.4 + t * 0.07 + l * 0.55) * 0.14 + sin(x * 12 - t * 0.05) * 0.018
                ribbon.addLine(to: CGPoint(x: x * size.width, y: (y + 0.1 + 0.055 * sin(x * 9 + t * 0.03)) * size.height))
            }
            ribbon.closeSubpath()
            var mist = context
            mist.addFilter(.blur(radius: size.height * 0.012))
            mist.fill(ribbon, with: .linearGradient(Gradient(colors: [Color.mint.opacity(0.03), Color.cyan.opacity(0.12), Color.mint.opacity(0.56 - l * 0.1), Color.purple.opacity(0.04)]), startPoint: .zero, endPoint: CGPoint(x: size.width * 0.8, y: size.height * 0.7)))
        }
        for layer in 0..<3 {
            var mountain = Path()
            mountain.move(to: CGPoint(x: 0, y: size.height))
            for step in 0...80 {
                let x = Double(step) / 80
                let y = 0.8 + Double(layer) * 0.065 - abs(sin(x * 9 + Double(layer) * 2)) * 0.13 - noise(Double(step + layer * 90)) * 0.026
                mountain.addLine(to: CGPoint(x: x * size.width, y: y * size.height))
            }
            mountain.addLine(to: CGPoint(x: size.width, y: size.height)); mountain.closeSubpath()
            context.fill(mountain, with: .color(Color(red: 0.015 - Double(layer) * 0.005, green: 0.033 - Double(layer) * 0.01, blue: 0.052 - Double(layer) * 0.018)))
        }
    }

    /// 绘制深空星云和缓慢漂移的多层星点。
    private func stars(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        backdrop(&context, size, [Color(red: 0.015, green: 0.01, blue: 0.045), .black])
        for i in 0..<14 {
            let x = Double(i) / 13
            glow(&context, CGPoint(x: x * size.width, y: (0.8 - x * 0.6 + sin(t * 0.015) * 0.03) * size.height), size.width * 0.17, Color(red: 0.26, green: 0.16, blue: 0.55).opacity(0.055))
        }
        starDots(&context, size, t, count: 380)
        glow(&context, CGPoint(x: size.width * 0.73, y: size.height * 0.22), size.height * 0.009, .white.opacity(0.8))
    }

    /// 绘制月亮、远海与连续流动的细波纹。
    private func ocean(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        backdrop(&context, size, [Color(red: 0.015, green: 0.035, blue: 0.095), Color(red: 0.03, green: 0.12, blue: 0.18), Color(red: 0.005, green: 0.025, blue: 0.055)])
        let moon = CGPoint(x: size.width * 0.7, y: size.height * 0.22)
        glow(&context, moon, size.height * 0.23, Color.cyan.opacity(0.12))
        context.fill(Path(ellipseIn: CGRect(x: moon.x - size.height * 0.024, y: moon.y - size.height * 0.024, width: size.height * 0.048, height: size.height * 0.048)), with: .color(Color(red: 0.66, green: 0.81, blue: 0.9)))
        for i in 0..<40 {
            let n = Double(i) / 40
            var wave = Path()
            for step in 0...100 {
                let x = Double(step) / 100
                let y = 0.44 + pow(n, 1.5) * 0.58 + sin(x * (14 + n * 19) + t * (0.2 + n * 0.2) + n * 20) * (0.002 + n * 0.008)
                let point = CGPoint(x: x * size.width, y: y * size.height)
                if step == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
            }
            context.stroke(wave, with: .linearGradient(Gradient(colors: [.cyan.opacity(0.025), .cyan.opacity(0.16 + n * 0.1), .white.opacity(0.16), .cyan.opacity(0.015)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), lineWidth: max(1, size.height * 0.0014))
        }
    }

    /// 绘制暖色余烬、风格化火焰与缓慢升起的火星。
    private func ember(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        glow(&context, CGPoint(x: size.width * 0.5, y: size.height * 0.76), size.width * 0.38, Color.orange.opacity(0.2))
        for i in 0..<11 {
            let seed = Double(i)
            let x = size.width * (0.29 + seed * 0.042)
            let base = size.height * 0.83
            let height = size.height * (0.12 + noise(seed) * 0.25 + sin(t * 0.6 + seed) * 0.022)
            let lean = sin(t * 0.3 + seed * 1.7) * size.width * 0.035
            let width = size.width * 0.034
            var flame = Path()
            flame.move(to: CGPoint(x: x - width, y: base))
            flame.addCurve(to: CGPoint(x: x + lean, y: base - height), control1: CGPoint(x: x - width * 2, y: base - height * 0.5), control2: CGPoint(x: x + lean + width * 0.5, y: base - height * 0.75))
            flame.addCurve(to: CGPoint(x: x + width, y: base), control1: CGPoint(x: x + lean + width, y: base - height * 0.3), control2: CGPoint(x: x + width * 2, y: base - height * 0.2))
            flame.closeSubpath()
            var soft = context; soft.addFilter(.blur(radius: size.height * 0.004))
            soft.fill(flame, with: .linearGradient(Gradient(colors: [Color(red: 0.95, green: 0.27, blue: 0.055).opacity(0.02), .orange.opacity(0.4), Color(red: 0.86, green: 0.13, blue: 0.025).opacity(0.7)]), startPoint: CGPoint(x: x, y: base - height), endPoint: CGPoint(x: x, y: base)))
        }
        for i in 0..<55 {
            let seed = Double(i + 1)
            let rise = (noise(seed) + t * 0.018).truncatingRemainder(dividingBy: 1)
            let x = (0.32 + noise(seed + 8) * 0.36 + sin(rise * 8 + seed) * 0.015) * size.width
            let y = (0.84 - rise * 0.5) * size.height
            let r = max(1, size.width / 1100)
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r * 2)), with: .color(.orange.opacity((1 - rise) * 0.6)))
        }
    }

    /// 绘制日落圆盘与六层原创沙丘轮廓。
    private func dunes(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        backdrop(&context, size, [Color(red: 0.12, green: 0.09, blue: 0.2), Color(red: 0.53, green: 0.25, blue: 0.23), Color(red: 0.75, green: 0.44, blue: 0.29)])
        let sun = CGPoint(x: size.width * 0.68, y: size.height * 0.33)
        glow(&context, sun, size.height * 0.32, Color.orange.opacity(0.15))
        context.fill(Path(ellipseIn: CGRect(x: sun.x - size.height * 0.065, y: sun.y - size.height * 0.065, width: size.height * 0.13, height: size.height * 0.13)), with: .color(Color(red: 0.92, green: 0.63, blue: 0.4)))
        for i in 0..<6 {
            let n = Double(i)
            var dune = Path(); dune.move(to: CGPoint(x: 0, y: size.height))
            for step in 0...100 {
                let x = Double(step) / 100
                let y = 0.5 + n * 0.087 + sin(x * (3.8 + n * 0.5) + n * 1.8 + t * 0.008) * 0.06
                dune.addLine(to: CGPoint(x: x * size.width, y: y * size.height))
            }
            dune.addLine(to: CGPoint(x: size.width, y: size.height)); dune.closeSubpath()
            context.fill(dune, with: .linearGradient(Gradient(colors: [Color(red: 0.5 - n * 0.07, green: 0.24 - n * 0.031, blue: 0.25 - n * 0.025), Color(red: 0.3 - n * 0.045, green: 0.12 - n * 0.016, blue: 0.19 - n * 0.024)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
        }
    }

    /// 绘制流动的丝带色谱，使用低速运动避免闪烁。
    private func prism(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        backdrop(&context, size, [Color(red: 0.025, green: 0.018, blue: 0.075), .black])
        let colors: [Color] = [.purple, .indigo, .cyan, .pink, .orange]
        for i in 0..<5 {
            let seed = Double(i)
            let center = CGPoint(x: (0.5 + sin(t * 0.025 + seed * 1.2) * 0.33) * size.width, y: (0.5 + cos(t * 0.03 + seed * 1.5) * 0.26) * size.height)
            glow(&context, center, size.width * 0.38, colors[i].opacity(0.18))
        }
        for i in 0..<70 {
            let n = Double(i) / 70
            var ribbon = Path()
            for step in 0...100 {
                let x = Double(step) / 100
                let y = 0.45 + (n - 0.5) * 0.35 + sin(x * 7 + t * 0.055 + n * 2.5) * 0.22
                let point = CGPoint(x: x * size.width, y: y * size.height)
                if step == 0 { ribbon.move(to: point) } else { ribbon.addLine(to: point) }
            }
            context.stroke(ribbon, with: .linearGradient(Gradient(colors: [.pink.opacity(0.05), .purple.opacity(0.2), .cyan.opacity(0.25), .orange.opacity(0.1)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), lineWidth: max(1, size.height * 0.0012))
        }
    }

    /// 绘制窗外暖色散景和沿玻璃滑落的雨滴。
    private func rain(_ context: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        backdrop(&context, size, [Color(red: 0.015, green: 0.027, blue: 0.05), Color(red: 0.045, green: 0.07, blue: 0.09), .black])
        for i in 0..<30 {
            let seed = Double(i + 1)
            glow(&context, CGPoint(x: noise(seed) * size.width, y: (0.35 + noise(seed + 22) * 0.45) * size.height), size.height * (0.012 + noise(seed + 3) * 0.038), (i % 3 == 0 ? Color.orange : Color.cyan).opacity(0.2))
        }
        for i in 0..<110 {
            let seed = Double(i + 1)
            let x = noise(seed + 13) * size.width
            let y = (noise(seed) + t * (0.025 + noise(seed + 4) * 0.03)).truncatingRemainder(dividingBy: 1) * size.height
            let length = size.height * (0.02 + noise(seed + 41) * 0.08)
            var drop = Path(); drop.move(to: CGPoint(x: x, y: y)); drop.addLine(to: CGPoint(x: x - size.width * 0.003, y: y + length))
            context.stroke(drop, with: .linearGradient(Gradient(colors: [.white.opacity(0), .cyan.opacity(0.18)]), startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x, y: y + length)), lineWidth: max(1, size.width * 0.0007))
        }
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
