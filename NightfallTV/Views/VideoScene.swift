import SwiftUI
import AVFoundation

private final class VideoSurface: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct VideoScene: UIViewRepresentable {
    let kind: SceneKind
    let paused: Bool
    let speed: Double

    /// 创建无控件、无焦点的原生视频层，遥控器统一由屏保界面处理。
    func makeUIView(context: Context) -> UIView {
        let view = VideoSurface()
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = context.coordinator.player
        return view
    }

    /// 根据实际场景、暂停和速度更新唯一的静音循环播放器。
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(kind: kind, paused: paused, speed: speed)
    }

    /// 将播放器与视图生命周期绑定，不为库内预览启动解码。
    func makeCoordinator() -> Coordinator { Coordinator() }

    /// 离开屏保或切入纯黑时立即释放解码队列。
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
        (uiView as? VideoSurface)?.playerLayer.player = nil
    }

    final class Coordinator {
        let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var scene: SceneKind?

        /// 视频原文件已无音轨，额外静音并禁止外部视频接管。
        init() {
            player.isMuted = true
            player.allowsExternalPlayback = false
        }

        /// 仅场景变化时创建循环队列，速度变化不重新加载视频。
        func update(kind: SceneKind, paused: Bool, speed: Double) {
            if scene != kind {
                stop()
                scene = kind
                if let url = Bundle.main.url(forResource: kind.rawValue, withExtension: "mp4") {
                    looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
                }
            }
            let rate: Float = paused ? 0 : Float(speed)
            if player.rate != rate { player.rate = rate }
        }

        /// 停止并清空循环器，避免黑屏或后台仍解码自然场景。
        func stop() {
            player.pause()
            looper?.disableLooping()
            looper = nil
            player.removeAllItems()
            scene = nil
        }
    }
}
