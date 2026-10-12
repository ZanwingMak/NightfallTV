import XCTest
import StoreKit
import StoreKitTest
@testable import NightfallTV

@MainActor
final class TipTests: XCTestCase {
    /// 商店配置不正确时停止用例，避免误用真实商品继续模拟购买。
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private var activeSession: SKTestSession?

    /// 测试失败也清理模拟错误，避免下一次购买继承旧错误配置。
    override func tearDown() { activeSession?.resetToDefaultState(); activeSession?.clearTransactions(); activeSession = nil; super.tearDown() }

    /// 每个用例从干净的本地商店开始，绝不沿用实际 App Store 配置。
    private func session() async throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "NightfallTips")
        activeSession = session
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    /// 本地模拟商店不产生真实扣款，四项消费型赞助可以验证后重复购买。
    func testConsumableTipsAndRepeatPurchases() async throws {
        let session = try await session()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = TipStore()
        await store.load()
        XCTAssertEqual(store.products.map(\.id), TipStore.productIDs)
        XCTAssertEqual(store.products.map(\.price), [Decimal(string: "0.99")!, Decimal(string: "2.99")!, Decimal(string: "4.99")!, Decimal(string: "9.99")!])
        for product in store.products {
            XCTAssertEqual(product.type, .consumable)
            XCTAssertFalse(product.displayPrice.isEmpty)
            await store.purchase(product)
            XCTAssertEqual(store.status, .thanks)
        }
        await store.purchase(try XCTUnwrap(store.products.first))
        XCTAssertEqual(store.status, .thanks)
        XCTAssertEqual(session.allTransactions().count, 5)
    }

    /// 商店失败、用户取消和等待批准分别反馈，不提前显示支付成功。
    func testFailureCancellationAndPendingApproval() async throws {
        let session = try await session()
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = TipStore()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        await store.load()
        XCTAssertEqual(store.status, .unavailable)
        XCTAssertTrue(store.products.isEmpty)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.load()
        let product = try XCTUnwrap(store.products.first)
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await store.purchase(product)
        XCTAssertEqual(store.status, .cancelled)
        XCTAssertTrue(session.allTransactions().allSatisfy { $0.state != .purchased })
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)
        await store.purchase(product)
        XCTAssertEqual(store.status, .failed)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        session.askToBuyEnabled = true
        await store.purchase(product)
        XCTAssertEqual(store.status, .pending)
        let pending = try XCTUnwrap(session.allTransactions().last(where: \.pendingAskToBuyConfirmation))
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        for _ in 0..<50 where store.status != .thanks { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(store.status, .thanks)
    }
}
