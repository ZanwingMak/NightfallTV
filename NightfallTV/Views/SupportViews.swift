import SwiftUI
import CoreImage.CIFilterBuiltins

struct SupportView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var tips: TipStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack {
                PageHeading(eyebrow: "MADE WITH CARE", title: settings.l("谢谢你，让安静继续。", "Thank you for keeping the quiet going."), subtitle: settings.l("自愿赞助开发。所有功能与内容始终免费。", "Voluntary support for development. All features and content remain free."))
                QuietButton(title: settings.l("关闭", "Close"), symbol: "xmark", id: "close-support") { dismiss() }
            }.focusSection()
            HStack(alignment: .top, spacing: 48) {
                Image(systemName: "heart.circle").font(.system(size: 150, weight: .ultraLight)).foregroundStyle(Palette.accent).frame(width: 220)
                VStack(alignment: .leading, spacing: 20) {
                    Text(settings.l("一份支持，更多真实风景。", "A little support. More real places.")).font(.title2)
                    Text(settings.l("这是一笔一次性打赏，可重复购买，不会订阅或解锁特权。", "This is a one-time tip you can repeat. No subscription or extra privileges.")).font(.callout).foregroundStyle(Palette.muted)
                    Text(settings.l("美国区价格：US$0.99、2.99、4.99、9.99。实际金额以Apple购买界面显示的当地价格为准。", "US prices: $0.99, $2.99, $4.99 and $9.99. Your local Apple purchase sheet shows the final price.")).font(.caption).foregroundStyle(Palette.muted)
                }
            }
            if tips.status == .loading { ProgressView(settings.l("正在连接App Store…", "Connecting to the App Store…")) }
            HStack(spacing: 24) {
                ForEach(tips.products, id: \.id) { product in
                    QuietButton(title: product.displayPrice, symbol: "heart", id: "tip-\(product.id)") { Task { await tips.purchase(product) } }
                        .disabled(tips.status == .purchasing)
                }
            }.focusSection()
            Text(statusText).font(.callout).foregroundStyle(tips.status == .thanks ? Palette.accent : Palette.muted).accessibilityIdentifier("tip-status")
            if tips.status == .unavailable || tips.status == .failed {
                QuietButton(title: settings.l("重试", "Try again"), symbol: "arrow.clockwise", id: "reload-tips") { Task { await tips.load() } }
            }
            Text(settings.l("付款与退款由Apple处理。消耗型打赏不需要恢复，也不会改变你的使用权限。", "Apple handles payments and refunds. Consumable tips need no restore and never change your access.")).font(.caption).foregroundStyle(Palette.muted)
        }.padding(56).frame(width: 1320).background(Palette.background)
            .task { await tips.load() }
            .onExitCommand { dismiss() }
    }

    /// 对不同购买状态提供明确反馈，取消和等待批准都不显示成功。
    private var statusText: String {
        switch tips.status {
        case .idle, .loading: return settings.l("只有在Apple确认付款后才会完成赞助。", "A tip completes only after Apple confirms payment.")
        case .purchasing: return settings.l("请在Apple购买界面确认。", "Please confirm in Apple's purchase sheet.")
        case .thanks: return settings.l("感谢你的支持。祝你今晚好眠。", "Thank you for your support. Have a peaceful night.")
        case .pending: return settings.l("正在等待购买批准，目前尚未完成。", "Waiting for purchase approval. Not completed yet.")
        case .cancelled: return settings.l("已取消，没有完成赞助。", "Cancelled. No tip was completed.")
        case .unavailable: return settings.l("赞助商品暂不可用，请稍后重试。你仍可使用全部功能。", "Tips are temporarily unavailable. Try again later; every feature is still available.")
        case .failed: return settings.l("未能确认交易，请检查网络或联系Apple支持。", "Unable to verify the transaction. Check your connection or contact Apple Support.")
        }
    }
}

enum SitePage: String, CaseIterable, Identifiable {
    case home, privacy, terms, support
    var id: String { rawValue }
    var url: URL { URL(string: "https://zanwingmak.github.io/NightfallTV/" + (self == .home ? "" : rawValue + ".html"))! }

    /// 统一应用中官网与法律页面标题。
    @MainActor func title(_ settings: SettingsStore) -> String {
        switch self {
        case .home: return settings.l("官方网站", "Official website")
        case .privacy: return settings.l("隐私政策", "Privacy policy")
        case .terms: return settings.l("服务条款", "Terms of service")
        case .support: return settings.l("帮助与支持", "Help and support")
        }
    }
}

struct SiteLinkView: View {
    let page: SitePage
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack {
                Text(page.title(settings)).font(.title2)
                Spacer()
                QuietButton(title: settings.l("关闭", "Close"), symbol: "xmark", id: "close-site-link") { dismiss() }
            }.focusSection()
            HStack(spacing: 56) {
                if let code = qrImage {
                    Image(uiImage: code).interpolation(.none).resizable().frame(width: 280, height: 280)
                        .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 24) {
                    Text(settings.l("用手机相机扫描，打开完整页面。", "Scan with your phone camera to open the full page.")).font(.title3)
                    Text(page.url.absoluteString).font(.callout).foregroundStyle(Palette.accent).lineLimit(3)
                    Text(settings.l("无需账号。扫描会访问GitHub Pages，网站托管方可能记录常规访问日志。", "No account needed. Scanning visits GitHub Pages; the host may record standard access logs.")).font(.caption).foregroundStyle(Palette.muted)
                }
            }
            Text(settings.l("设置、收藏、照片地址和睡前方案保存在本机。可选素材在主动下载时访问GitHub；Apple独立处理购买及TestFlight。应用不含广告或追踪SDK。", "Settings, favorites, photo URLs and bedtime routines stay on your device. Optional downloads contact GitHub only when requested. Apple separately handles purchases and TestFlight. No advertising or tracking SDKs.")).font(.callout).foregroundStyle(Palette.muted)
            Text(settings.l("赞助是可重复的一次性打赏，不解锁功能。媒体保留原许可。应用不能替换系统屏保或控制电视背光；下载缓存可能被tvOS清理。退款通过Apple申请。", "Support is a repeatable one-time tip that unlocks no features. Media retain their licenses. The app cannot replace the system screensaver or control TV backlight. tvOS may clear downloaded caches. Request refunds through Apple.")).font(.caption).foregroundStyle(Palette.muted)
        }.padding(56).frame(width: 1320).background(Palette.background).onExitCommand { dismiss() }
    }

    /// 在本机生成真实目标地址二维码，电视无需浏览器也能访问完整法律文件。
    private var qrImage: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(page.url.absoluteString.utf8)
        guard let output = filter.outputImage, let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
