import AppCore
import Foundation
import Testing

@MainActor
private final class UnauthorizedCounter {
    private(set) var count = 0
    func record() { count += 1 }
}

@MainActor
private final class ReentrantSendBox {
    var task: Task<Void, Never>?
    var viewModel: HomeViewModel?
}

@MainActor
private struct Harness {
    let counter = UnauthorizedCounter()
    let fake = FakeAPIClient()
    let link: FakeWatchLink
    let viewModel: HomeViewModel

    init(delivery: WatchDelivery = .sent) {
        link = FakeWatchLink(delivery: delivery)
        let counter = counter
        viewModel = HomeViewModel(
            apiClient: fake,
            onUnauthorized: { counter.record() },
            watchLink: link
        )
    }
}

@MainActor
@Suite struct HomeViewModelTests {
    @Test func sendStoresCardAndForwardsToWatch() async {
        let harness = Harness(delivery: .sent)
        let card = makeTestCard(kind: .prompt)
        await harness.fake.queueCreateDemoCard(.success(card))

        await harness.viewModel.send(kind: .prompt)

        #expect(harness.viewModel.lastCard == card)
        #expect(harness.link.receivedCards == [card])
        #expect(harness.viewModel.lastDelivery == .sent)
        #expect(harness.viewModel.errorMessage == nil)
        #expect(!harness.viewModel.isSending)
        #expect(await harness.fake.lastCreateDemoCardKind == .prompt)
    }

    @Test func sendWithUnavailableWatchStillShowsCard() async {
        let harness = Harness(delivery: .unavailable)
        let card = makeTestCard()
        await harness.fake.queueCreateDemoCard(.success(card))

        await harness.viewModel.send(kind: .message)

        #expect(harness.viewModel.lastCard == card)
        #expect(harness.viewModel.lastDelivery == .unavailable)
        #expect(harness.viewModel.errorMessage == nil)
        #expect(harness.link.receivedCards == [card])
        #expect(await harness.fake.lastCreateDemoCardKind == .message)
    }

    @Test func sendFailureSetsErrorAndKeepsPreviousCard() async {
        let harness = Harness()
        let previous = makeTestCard()
        await harness.fake.queueCreateDemoCard(.success(previous))
        await harness.viewModel.send(kind: .message)

        await harness.fake.queueCreateDemoCard(
            .failure(.server(code: "DEMO_FAILED", message: "The demo is down", status: 500))
        )
        await harness.viewModel.send(kind: .message)

        #expect(harness.viewModel.errorMessage == "The demo is down")
        #expect(harness.viewModel.lastCard == previous)
        #expect(harness.link.receivedCards == [previous])
        #expect(!harness.viewModel.isSending)
        #expect(harness.counter.count == 0)
    }

    @Test func sendNetworkFailureSetsConnectionMessage() async {
        let harness = Harness()
        await harness.fake.queueCreateDemoCard(.failure(.network))

        await harness.viewModel.send(kind: .message)

        #expect(harness.viewModel.errorMessage == "Can't reach the server. Check your connection.")
        #expect(harness.viewModel.lastCard == nil)
        #expect(harness.link.receivedCards.isEmpty)
    }

    @Test func sendUnauthorizedCallsOnUnauthorized() async {
        let harness = Harness()
        await harness.fake.queueCreateDemoCard(.failure(.unauthorized))

        await harness.viewModel.send(kind: .message)

        #expect(harness.counter.count == 1)
        #expect(harness.link.receivedCards.isEmpty)
        #expect(harness.viewModel.lastCard == nil)
        #expect(!harness.viewModel.isSending)
    }

    @Test func sendIgnoresSecondCallWhileSending() async {
        let harness = Harness()
        let card = makeTestCard()
        await harness.fake.holdCreateDemoCard()
        await harness.fake.queueCreateDemoCard(.success(card))

        let first = Task { await harness.viewModel.send(kind: .message) }
        await harness.fake.waitForCreateDemoCardToBeEntered()
        #expect(harness.viewModel.isSending)

        await harness.viewModel.send(kind: .prompt)
        await harness.fake.releaseCreateDemoCard()
        await first.value

        #expect(await harness.fake.createDemoCardCallCount == 1)
        #expect(await harness.fake.lastCreateDemoCardKind == .message)
        #expect(harness.viewModel.lastCard == card)
        #expect(harness.link.receivedCards == [card])
        #expect(!harness.viewModel.isSending)
    }

    @Test func endSessionDuringSendDropsCardAndDoesNotForward() async {
        let harness = Harness()
        await harness.fake.holdCreateDemoCard()
        await harness.fake.queueCreateDemoCard(.success(makeTestCard()))

        let pending = Task { await harness.viewModel.send(kind: .message) }
        await harness.fake.waitForCreateDemoCardToBeEntered()
        harness.viewModel.endSession()
        await harness.fake.releaseCreateDemoCard()
        await pending.value

        #expect(harness.viewModel.lastCard == nil)
        #expect(harness.link.receivedCards.isEmpty)
        #expect(harness.viewModel.errorMessage == nil)
        #expect(!harness.viewModel.isSending)
    }

    @Test func endSessionDuringFailingSendSetsNoError() async {
        let harness = Harness()
        await harness.fake.holdCreateDemoCard()
        await harness.fake.queueCreateDemoCard(.failure(.network))

        let pending = Task { await harness.viewModel.send(kind: .message) }
        await harness.fake.waitForCreateDemoCardToBeEntered()
        harness.viewModel.endSession()
        await harness.fake.releaseCreateDemoCard()
        await pending.value

        #expect(harness.viewModel.errorMessage == nil)
        #expect(harness.viewModel.lastCard == nil)
        #expect(harness.link.receivedCards.isEmpty)
    }

    @Test func sendAfterEndSessionDoesNotCallAPI() async {
        let harness = Harness()
        await harness.fake.queueCreateDemoCard(.success(makeTestCard()))
        harness.viewModel.endSession()

        await harness.viewModel.send(kind: .message)

        #expect(await harness.fake.createDemoCardCallCount == 0)
        #expect(harness.viewModel.lastCard == nil)
        #expect(harness.link.receivedCards.isEmpty)
    }

    @Test func endSessionDoesNotCallWatchLink() {
        let harness = Harness()

        harness.viewModel.endSession()

        #expect(harness.link.clearCallCount == 0)
        #expect(harness.link.receivedCards.isEmpty)
    }

    @Test func unauthorizedSendEndsSessionSoLaterSendDoesNotCallAPI() async {
        let harness = Harness()
        await harness.fake.queueCreateDemoCard(.failure(.unauthorized))
        await harness.fake.queueCreateDemoCard(.success(makeTestCard()))

        await harness.viewModel.send(kind: .message)
        await harness.viewModel.send(kind: .message)

        #expect(harness.counter.count == 1)
        #expect(await harness.fake.createDemoCardCallCount == 1)
        #expect(harness.viewModel.lastCard == nil)
        #expect(harness.link.receivedCards.isEmpty)
    }

    @Test func unauthorizedAfterEndSessionDoesNotCallOnUnauthorized() async {
        let harness = Harness()
        await harness.fake.holdCreateDemoCard()
        await harness.fake.queueCreateDemoCard(.failure(.unauthorized))

        let pending = Task { await harness.viewModel.send(kind: .message) }
        await harness.fake.waitForCreateDemoCardToBeEntered()
        harness.viewModel.endSession()
        await harness.fake.releaseCreateDemoCard()
        await pending.value

        #expect(harness.counter.count == 0)
        #expect(harness.viewModel.errorMessage == nil)
        #expect(harness.viewModel.lastCard == nil)
        #expect(!harness.viewModel.isSending)
        #expect(harness.link.receivedCards.isEmpty)
    }

    @Test func unauthorizedEndsSessionBeforeOnUnauthorizedRuns() async {
        let fake = FakeAPIClient()
        let link = FakeWatchLink()
        let counter = UnauthorizedCounter()
        let box = ReentrantSendBox()
        let viewModel = HomeViewModel(
            apiClient: fake,
            onUnauthorized: {
                counter.record()
                box.task = Task { await box.viewModel?.send(kind: .prompt) }
            },
            watchLink: link
        )
        box.viewModel = viewModel
        await fake.queueCreateDemoCard(.failure(.unauthorized))
        await fake.queueCreateDemoCard(.success(makeTestCard()))

        await viewModel.send(kind: .message)
        await box.task?.value

        #expect(counter.count == 1)
        #expect(await fake.createDemoCardCallCount == 1)
        #expect(viewModel.lastCard == nil)
        #expect(link.receivedCards.isEmpty)
    }

    @Test func successfulSendClearsPreviousError() async {
        let harness = Harness()
        await harness.fake.queueCreateDemoCard(.failure(.network))
        await harness.viewModel.send(kind: .message)
        #expect(harness.viewModel.errorMessage != nil)

        let card = makeTestCard()
        await harness.fake.queueCreateDemoCard(.success(card))
        await harness.viewModel.send(kind: .message)

        #expect(harness.viewModel.errorMessage == nil)
        #expect(harness.viewModel.lastCard == card)
    }
}
