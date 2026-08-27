//
//  UniversalInstallerTests.swift
//  MistTests
//

@testable import Mist
import XCTest

final class UniversalInstallerTests: XCTestCase {
    func testPlanIncludesEFIAndTargets() throws {
        let target = InstallerTarget(
            name: "macOS Installer",
            platform: .macOS,
            bootStrategy: .openCore,
            requiredBytes: 16 * 1_024 * 1_024 * 1_024,
            minimumPartitionBytes: 20 * 1_024 * 1_024 * 1_024
        )

        let plan = try InstallerPlanBuilder().build(
            diskIdentifier: "disk99",
            diskSizeBytes: 64 * 1_024 * 1_024 * 1_024,
            targets: [target]
        )

        XCTAssertEqual(plan.partitions.count, 2)
        XCTAssertEqual(plan.partitions.first?.name, "EFI")
        XCTAssertTrue(plan.fitsOnDisk)
    }

    func testPlanRejectsInsufficientDiskSpace() {
        let target = InstallerTarget(
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
        let device = HardwareDevice(category: .gpu, name: "Unsupported GPU")
        let result = HardwareCompatibilityResult(
            device: device,
            status: .unsupported,
            minimumOSVersion: nil,
            maximumOSVersion: nil,
            requirements: [],
            notes: []
        )
        let report = CompatibilityReport(
            targetName: "macOS",
            results: [result],
            warnings: [],
            blockingIssues: []
        )

        XCTAssertFalse(report.isBuildable)
    }
}
