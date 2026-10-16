import SwiftUI

struct SceneArtwork: View {
    let kind: SceneKind
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if !kind.isPlayerMode, let image = poster {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
            }
        }.accessibilityHidden(true)
    }

    /// UIKit 会自动寻找 PNG；可下载素材的 JPEG 海报需要显式扩展名。
    private var poster: UIImage? {
        let name = "\(kind.rawValue)-poster"
        return UIImage(named: name) ?? UIImage(named: name + ".jpg")
    }
}
