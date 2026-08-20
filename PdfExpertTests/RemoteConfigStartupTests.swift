//
//  RemoteConfigStartupTests.swift
//  PdfExpertTests
//
//  When the remote configuration is asked for, and what the app is left with
//  until it arrives. No network and no Firebase project are involved: the
//  defect these cover was one of lifecycle, not of Firebase.
//
//  The story, so the tests are not mistaken for ceremony: the fetch used to be
//  triggered only by `UIApplication.didBecomeActiveNotification`. On Mac
//  Catalyst that notification never reached the view listening for it, so the
//  app ran on in-app defaults for the whole session — `proxy_base_url` empty,
//  and with it ChatPDF, the online tools and the Office fallback quietly gone,
//  while the iPhone downloaded the same five values in seconds.
//

import Combine
import XCTest
@testable import PdfExpert

final class RemoteConfigStartupTests: XCTestCase {

    private var cancelBag: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        self.cancelBag = []
    }

    override func tearDown() {
        self.cancelBag = nil
        super.tearDown()
    }

    // MARK: - The defect

    func testLaunchingAsksForTheConfigurationWithoutWaitingToBecomeActive() async {
        let source = SpyConfigSource(fetched: RemoteConfigData(proxyBaseUrl: Self.proxyUrl))
        let manager = RemoteConfigManager(source: source)

        XCTAssertEqual(source.fetchCount, 0, "nothing should be asked for before the app starts")

        let arrived = self.expectValue(from: manager, matching: Self.proxyUrl)
        manager.start()
        await self.fulfillment(of: [arrived], timeout: 2)

        XCTAssertEqual(source.fetchCount, 1)
        XCTAssertEqual(manager.remoteConfigData.value.proxyBaseUrl, Self.proxyUrl)
    }

    /// What the app is left with when nobody asks — the Mac's whole session.
    func testWithoutStartTheAppIsLeftOnTheDefaultsAndTheOnlineToolsStayOff() {
        let source = SpyConfigSource(fetched: RemoteConfigData(proxyBaseUrl: Self.proxyUrl))
        let manager = RemoteConfigManager(source: source)

        XCTAssertEqual(source.fetchCount, 0)
        XCTAssertTrue(manager.remoteConfigData.value.proxyBaseUrl.isEmpty,
                      "the in-app default is empty on purpose")

        // An empty address is what switches the online side of the app off, so
        // the fetch not happening is not a small thing.
        let stirling = StirlingApiManagerImpl(
            isEnabledProvider: { manager.remoteConfigData.value.stirlingApiEnabled },
            baseUrlProvider: { manager.remoteConfigData.value.proxyBaseUrl })
        XCTAssertFalse(stirling.isAvailable)
    }

    func testTheFetchedAddressTurnsTheOnlineToolsBackOn() async {
        let source = SpyConfigSource(fetched: RemoteConfigData(proxyBaseUrl: Self.proxyUrl))
        let manager = RemoteConfigManager(source: source)
        let stirling = StirlingApiManagerImpl(
            isEnabledProvider: { manager.remoteConfigData.value.stirlingApiEnabled },
            baseUrlProvider: { manager.remoteConfigData.value.proxyBaseUrl })

        XCTAssertFalse(stirling.isAvailable)

        let arrived = self.expectValue(from: manager, matching: Self.proxyUrl)
        manager.start()
        await self.fulfillment(of: [arrived], timeout: 2)

        XCTAssertTrue(stirling.isAvailable)
    }

    // MARK: - What must not regress

    func testAnActivationArrivingDuringTheLaunchFetchDoesNotAskTwice() async {
        let source = SpyConfigSource(fetched: RemoteConfigData(proxyBaseUrl: Self.proxyUrl),
                                     holdsTheFetch: true)
        let manager = RemoteConfigManager(source: source)

        let started = self.expectation(description: "the launch fetch is under way")
        source.onFetchStarted = { started.fulfill() }
        let arrived = self.expectValue(from: manager, matching: Self.proxyUrl)

        manager.start()
        await self.fulfillment(of: [started], timeout: 2)

        // The notification does arrive on iPhone, and it arrives early.
        manager.onApplicationDidBecomeActive()
        source.releaseTheFetch()
        await self.fulfillment(of: [arrived], timeout: 2)

        XCTAssertEqual(source.fetchCount, 1,
                       "an activation on top of the launch fetch should share it, not duplicate it")
    }

    func testBecomingActiveLaterAsksAgain() async {
        let source = SpyConfigSource(fetched: RemoteConfigData(proxyBaseUrl: Self.proxyUrl))
        let manager = RemoteConfigManager(source: source)

        let firstArrived = self.expectValue(from: manager, matching: Self.proxyUrl)
        manager.start()
        await self.fulfillment(of: [firstArrived], timeout: 2)

        let secondArrived = self.expectValue(from: manager, matching: Self.proxyUrl)
        manager.onApplicationDidBecomeActive()
        await self.fulfillment(of: [secondArrived], timeout: 2)

        XCTAssertEqual(source.fetchCount, 2, "a later activation is a fresh chance to update")
    }

    func testTheSourceIsPreparedOnceBeforeAnyFetch() {
        let source = SpyConfigSource(fetched: RemoteConfigData())
        _ = RemoteConfigManager(source: source)

        XCTAssertEqual(source.prepareCount, 1)
        XCTAssertEqual(source.fetchCount, 0, "defaults first, network after")
    }

    /// Whatever happens — fetched, throttled, offline — whoever waits is told.
    func testAFailingFetchStillDeliversWhateverIsInForce() async {
        let source = SpyConfigSource(fetched: RemoteConfigData(proxyBaseUrl: Self.proxyUrl),
                                     failsWith: NSError(domain: "test", code: -1009))
        let manager = RemoteConfigManager(source: source)

        let delivered = self.expectation(description: "the subscriber hears back anyway")
        manager.remoteConfigData
            .dropFirst()
            .sink { _ in delivered.fulfill() }
            .store(in: &self.cancelBag)

        manager.start()
        await self.fulfillment(of: [delivered], timeout: 2)

        XCTAssertTrue(manager.remoteConfigData.value.proxyBaseUrl.isEmpty,
                      "a failed fetch leaves the defaults in place")
    }

    // MARK: - Helpers

    private static let proxyUrl = "https://proxy.example.test"

    private func expectValue(from manager: RemoteConfigManager,
                             matching url: String) -> XCTestExpectation {
        let expectation = self.expectation(description: "the configuration reaches its subscribers")
        manager.remoteConfigData
            .dropFirst()
            .filter { $0.proxyBaseUrl == url }
            .first()
            .sink { _ in expectation.fulfill() }
            .store(in: &self.cancelBag)
        return expectation
    }
}

/// A stand-in for Firebase that counts what it is asked, and can be made to
/// hang mid-fetch so a second caller arrives while the first is still in flight.
private final class SpyConfigSource: RemoteConfigSource {

    private(set) var prepareCount = 0
    private(set) var fetchCount = 0
    var onFetchStarted: (() -> Void)?

    private let fetched: RemoteConfigData
    private let holdsTheFetch: Bool
    private let failure: Error?
    private var current = RemoteConfigData()      // the in-app defaults
    private var release: CheckedContinuation<Void, Never>?

    init(fetched: RemoteConfigData, holdsTheFetch: Bool = false, failsWith failure: Error? = nil) {
        self.fetched = fetched
        self.holdsTheFetch = holdsTheFetch
        self.failure = failure
    }

    func prepare() {
        self.prepareCount += 1
    }

    func fetchAndActivate() async throws {
        self.fetchCount += 1
        self.onFetchStarted?()
        if self.holdsTheFetch {
            await withCheckedContinuation { self.release = $0 }
        }
        if let failure = self.failure {
            throw failure
        }
        self.current = self.fetched
    }

    func releaseTheFetch() {
        self.release?.resume()
        self.release = nil
    }

    var data: RemoteConfigData { self.current }
}
