import Foundation
import IOKit.pwr_mgt
import XCTest
@testable import HandySwitch

@MainActor
private final class FakePreventSleepAssertionManager: PreventSleepAssertionManaging {
    var createCount = 0
    var releaseCount = 0
    var shouldCreate = true

    func createAssertion(timeout: TimeInterval) -> IOPMAssertionID? {
        createCount += 1
        guard shouldCreate else { return nil }
        return 42
    }

    func releaseAssertion(_ id: IOPMAssertionID) {
        releaseCount += 1
    }
}

@MainActor
final class PreventSleepServiceTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "HandySwitch.PreventSleepTests.\(UUID().uuidString)")!
    }

    func testDefaultEnablePersistsFiveHourDeadline() {
        let defaults = makeDefaults()
        let current = Date(timeIntervalSince1970: 1_000)
        let manager = FakePreventSleepAssertionManager()
        let service = PreventSleepService(defaults: defaults, now: { current }, assertionManager: manager)

        service.setEnabled(true)

        XCTAssertTrue(service.isEnabled)
        XCTAssertEqual(service.awakeDurationMinutes, 300)
        XCTAssertEqual(service.awakeDeadline, current.addingTimeInterval(5 * 60 * 60))
        XCTAssertEqual(manager.createCount, 1)
        XCTAssertTrue(defaults.bool(forKey: "preventSleepEnabled"))
    }

    func testRestoreKeepsRemainingTimeAndMigratesLegacyState() {
        let defaults = makeDefaults()
        let current = Date(timeIntervalSince1970: 2_000)
        defaults.set(true, forKey: "preventSleepEnabled")
        let oldDeadline = current.addingTimeInterval(90 * 60)
        defaults.set(oldDeadline.timeIntervalSince1970, forKey: "awakeDeadline")
        let manager = FakePreventSleepAssertionManager()
        let service = PreventSleepService(defaults: defaults, now: { current }, assertionManager: manager)

        service.restorePersistedState()
        XCTAssertEqual(service.awakeDeadline, oldDeadline)
        XCTAssertEqual(manager.createCount, 1)

        let legacyDefaults = makeDefaults()
        legacyDefaults.set(true, forKey: "preventSleepEnabled")
        let legacy = PreventSleepService(defaults: legacyDefaults, now: { current }, assertionManager: manager)
        legacy.restorePersistedState()
        XCTAssertEqual(legacy.awakeDeadline, current.addingTimeInterval(5 * 60 * 60))
    }

    func testChangingDurationWhileEnabledResetsFromNowButClosedOnlySelects() {
        let defaults = makeDefaults()
        var current = Date(timeIntervalSince1970: 3_000)
        let manager = FakePreventSleepAssertionManager()
        let service = PreventSleepService(defaults: defaults, now: { current }, assertionManager: manager)

        service.setAwakeDuration(minutes: 60)
        XCTAssertFalse(service.isEnabled)
        XCTAssertNil(service.awakeDeadline)
        service.setEnabled(true)
        current = Date(timeIntervalSince1970: 4_000)
        service.setAwakeDuration(minutes: 15)
        XCTAssertEqual(service.awakeDeadline, current.addingTimeInterval(15 * 60))
    }

    func testExpiryReleasesAssertionAndClearsPersistedState() {
        let defaults = makeDefaults()
        var current = Date(timeIntervalSince1970: 5_000)
        let manager = FakePreventSleepAssertionManager()
        let service = PreventSleepService(defaults: defaults, now: { current }, assertionManager: manager)
        service.setEnabled(true)

        current = current.addingTimeInterval(5 * 60 * 60)
        service.checkExpiration()

        XCTAssertFalse(service.isEnabled)
        XCTAssertNil(service.awakeDeadline)
        XCTAssertEqual(manager.releaseCount, 1)
        XCTAssertFalse(defaults.bool(forKey: "preventSleepEnabled"))
        XCTAssertNil(defaults.object(forKey: "awakeDeadline"))
    }

    func testTerminationReleasesButPreservesScheduleForRestart() {
        let defaults = makeDefaults()
        let current = Date(timeIntervalSince1970: 6_000)
        let manager = FakePreventSleepAssertionManager()
        let service = PreventSleepService(defaults: defaults, now: { current }, assertionManager: manager)
        service.setEnabled(true)
        let deadline = service.awakeDeadline

        service.endForTermination()

        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.awakeDeadline, deadline)
        XCTAssertTrue(defaults.bool(forKey: "preventSleepEnabled"))
        XCTAssertEqual(manager.releaseCount, 1)
    }

    func testAssertionCreationFailureClearsEnabledAndDeadline() {
        let defaults = makeDefaults()
        let manager = FakePreventSleepAssertionManager()
        manager.shouldCreate = false
        let service = PreventSleepService(
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 7_000) },
            assertionManager: manager
        )

        service.setEnabled(true)

        XCTAssertFalse(service.isEnabled)
        XCTAssertNil(service.awakeDeadline)
        XCTAssertFalse(defaults.bool(forKey: "preventSleepEnabled"))
        XCTAssertNil(defaults.object(forKey: "awakeDeadline"))
    }

    func testExpiredScheduleDoesNotRestoreInNewService() {
        let defaults = makeDefaults()
        var current = Date(timeIntervalSince1970: 8_000)
        let manager = FakePreventSleepAssertionManager()
        let service = PreventSleepService(defaults: defaults, now: { current }, assertionManager: manager)
        service.setEnabled(true)
        current = current.addingTimeInterval(5 * 60 * 60)
        service.checkExpiration()

        let restarted = PreventSleepService(defaults: defaults, now: { current }, assertionManager: manager)
        restarted.restorePersistedState()

        XCTAssertFalse(restarted.isEnabled)
        XCTAssertNil(restarted.awakeDeadline)
        XCTAssertEqual(manager.createCount, 1)
    }
}
