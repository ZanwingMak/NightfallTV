import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("NightfallTV/Resources/Assets.xcassets")
let info: [String: Any] = ["author": "xcode", "version": 1]

/// 将资源目录元数据写入格式化 JSON。
func json(_ value: [String: Any], at directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
}

/// 绘制原创极光背景或透明月牙前景，导出无损 PNG。
func render(width: Int, height: Int, foreground: Bool, at url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let w = CGFloat(width), h = CGFloat(height)
    if foreground {
        let path = NSBezierPath()
        let x = w * 0.5, y = h * 0.54, r = h * 0.19
        path.appendArc(withCenter: NSPoint(x: x, y: y), radius: r, startAngle: 65, endAngle: 295, clockwise: false)
        path.curve(to: NSPoint(x: x + cos(65 * .pi / 180) * r, y: y + sin(65 * .pi / 180) * r), controlPoint1: NSPoint(x: x - r * 0.6, y: y - r * 0.5), controlPoint2: NSPoint(x: x - r * 0.6, y: y + r * 0.5))
        path.close()
        NSColor(calibratedRed: 0.86, green: 0.84, blue: 1, alpha: 1).setFill(); path.fill()
        let text = "nightfall" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: h * 0.075, weight: .light), .foregroundColor: NSColor(calibratedWhite: 0.85, alpha: 1), .kern: h * 0.01]
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (w - size.width) / 2, y: h * 0.22), withAttributes: attrs)
    } else {
        NSGradient(colors: [NSColor(calibratedRed: 0.025, green: 0.04, blue: 0.095, alpha: 1), NSColor(calibratedRed: 0.015, green: 0.015, blue: 0.035, alpha: 1)])!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 90)
        for layer in 0..<36 {
            let n = CGFloat(layer)
            let ribbon = NSBezierPath()
            for step in 0...120 {
                let x = CGFloat(step) / 120
                let y = 0.55 + sin(x * 6 + n * 0.035) * 0.17 + n * 0.004
                let p = NSPoint(x: x * w, y: y * h)
                if step == 0 { ribbon.move(to: p) } else { ribbon.line(to: p) }
            }
            NSColor(calibratedRed: 0.2 + n * 0.007, green: 0.4, blue: 0.78, alpha: 0.03).setStroke()
            ribbon.lineWidth = h * 0.018; ribbon.stroke()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

/// 创建多尺寸 tvOS 分层图标和顶部展示资源。
func createAssets() throws {
    try json(["info": info], at: root)
    for (name, components) in [("LaunchBlack", ["0.000", "0.000", "0.000"]), ("AccentColor", ["0.680", "0.600", "1.000"])] {
        try json(["info": info, "colors": [["idiom": "universal", "color": ["color-space": "srgb", "components": ["red": components[0], "green": components[1], "blue": components[2], "alpha": "1.000"]]]]], at: root.appendingPathComponent("\(name).colorset"))
    }
    let brand = root.appendingPathComponent("App Icon & Top Shelf Image.brandassets")
    var assets: [[String: String]] = []
    for (name, dimensions) in [("App Icon", [(400, 240, "1x"), (800, 480, "2x")]), ("App Icon - App Store", [(1280, 768, "1x")])] {
        let stack = brand.appendingPathComponent("\(name).imagestack")
        try json(["info": info, "layers": [["filename": "Foreground.imagestacklayer"], ["filename": "Background.imagestacklayer"]]], at: stack)
        for layer in ["Background", "Foreground"] {
            let dir = stack.appendingPathComponent("\(layer).imagestacklayer")
            try json(["info": info], at: dir)
            let images = dir.appendingPathComponent("Content.imageset")
            try json(["info": info, "images": dimensions.map { ["filename": "\($0.0).png", "idiom": "tv", "scale": $0.2] }], at: images)
            for (w, h, _) in dimensions { try render(width: w, height: h, foreground: layer == "Foreground", at: images.appendingPathComponent("\(w).png")) }
        }
        assets.append(["filename": "\(name).imagestack", "idiom": "tv", "role": "primary-app-icon", "size": name == "App Icon" ? "400x240" : "1280x768"])
    }
    for (name, width) in [("Top Shelf Image", 1920), ("Top Shelf Image Wide", 2320)] {
        let dir = brand.appendingPathComponent("\(name).imageset")
        try json(["info": info, "images": [["filename": "1x.png", "idiom": "tv", "scale": "1x"], ["filename": "2x.png", "idiom": "tv", "scale": "2x"]]], at: dir)
        for scale in 1...2 { try render(width: width * scale, height: 720 * scale, foreground: false, at: dir.appendingPathComponent("\(scale)x.png")) }
        assets.append(["filename": "\(name).imageset", "idiom": "tv", "role": name.hasSuffix("Wide") ? "top-shelf-image-wide" : "top-shelf-image", "size": "\(width)x720"])
    }
    try json(["info": info, "assets": assets], at: brand)
    print("Generated layered tvOS icon and top shelf images")
}

try createAssets()
