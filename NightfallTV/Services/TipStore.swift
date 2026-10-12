import StoreKit
import Combine

@MainActor
final class TipStore: ObservableObject {
    static let productIDs = ["small", "kind", "warm", "generous"].map { "com.zanwingmak.nightfalltv.tip." + $0 }
    enum Status { case idle, loading, purchasing, thanks, pending, cancelled, unavailable, failed }
    @Published private(set) var products: [Product] = []
    @Published private(set) var status: Status = .idle
    private var updates: Task<Void, Never>?

    /// 只监听本应用四项赞助的已验证交易，延迟批准后也能完成交易。
    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                if case .verified(let transaction) = result, transaction.productType == .consumable, Self.productIDs.contains(transaction.productID) {
                    await transaction.finish()
                    if self?.status != .purchasing { self?.status = .thanks }
                }
            }
        }
    }

    /// 服务结束时取消交易监听。
    deinit { updates?.cancel() }

    /// 从Apple加载真实商品与本地价格，失败时不显示可点击的虚构价格。
    func load() async {
        guard status != .loading && status != .purchasing else { return }
        status = .loading
        do {
            products = try await Product.products(for: Self.productIDs).filter { $0.type == .consumable }.sorted { $0.price < $1.price }
            status = products.isEmpty ? .unavailable : .idle
        } catch { products = []; status = .unavailable }
    }

    /// 只在用户主动选择后调用Apple购买界面，区分批准、取消、待批准和验证失败。
    func purchase(_ product: Product) async {
        guard status != .purchasing, Self.productIDs.contains(product.id), products.contains(where: { $0.id == product.id }) else { return }
        status = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { status = .failed; return }
                await transaction.finish()
                status = .thanks
            case .pending: status = .pending
            case .userCancelled: status = .cancelled
            @unknown default: status = .failed
            }
        } catch StoreKitError.userCancelled { status = .cancelled }
        catch { status = .failed }
    }
}
