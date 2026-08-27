//
//  UniversalInstallerTests.swift
//  MistTests
//

@testable import Mist
import XCTest

final class UniversalInstallerTests: XCTestCase {
    func testPlanIncludesEFIAndTargets() throws {
        let target: InstallerTarget = .init(
            name: "macOS Installer",
            platform: .macOS,
            bootStrategy: .openCore,
            requiredBytes: 16 * 1_024 * 1_024 * 1_024,
            minimumPartitionBytes: 20 * 1_024 * 1_024 * 1_024
        )

        // swiftformat:disable:next redundantType
        let plan: InstallerPlan = try InstallerPlanBuilder().build(
            diskIdentifier: "disk99",
            diskSizeBytes: 64 * 1_024 * 1_024 * 1_024,
            targets: [target]
        )

        XCTAssertEqual(plan.partitions.count, 2)
        XCTAssertEqual(plan.partitions.first?.name, "EFI")
        XCTAssertTrue(plan.fitsOnDisk)
    }

    func testPlanRejectsInsufficientDiskSpace() {
        let target: InstallerTarget = .init(
            name: "Large Installer",
            platform: .linux,
            bootStrategy: .genericUEFI,
            requiredBytes: 30 * 1_024 * 1_024 * 1_024,
            minimumPartitionBytes: 32 * 1_024 * 1_024 * 1_024
        )

        XCTAssertThrowsError(
            try InstallerPlanBuilder().build(
                diskIdentifier: "disk99",
                diskSizeBytes: 32 * 1_024 * 1_024 * 1_024,
                targets: [target]
            )
        )
    }

    func testUnsupportedHardwareBlocksBuild() {
        let device: HardwareDevice = .init(category: .gpu, name: "Unsupported GPU")
        let result: HardwareCompatibilityResult = .init(
            device: device,
            status: .unsupported,
            minimumOSVersion: nil,
            maximumOSVersion: nil,
            requirements: [],
            notes: []
        )
        let report: CompatibilityReport = .init(
            targetName: "macOS",
            results: [result],
            warnings: [],
            blockingIssues: []
        )

        XCTAssertFalse(report.isBuildable)
    }
}
