//
//  UniversalInstallerTests.swift
//  MistTests
//

@testable import Mist
import XCTest

final class UniversalInstallerTests: XCTestCase {
    func testPlanIncludesEFIAndMultipleMacOSInstallers() throws {
        let tahoe: InstallerTarget = .init(
            name: "Install macOS Tahoe",
            version: "26.0",
            build: "25A354",
            kind: .fullInstaller,
            bootStrategy: .openCore,
            requiredBytes: 16 * 1_024 * 1_024 * 1_024,
            minimumPartitionBytes: 20 * 1_024 * 1_024 * 1_024
        )
        let sequoia: InstallerTarget = .init(
            name: "Install macOS Sequoia",
            version: "15.7",
            build: "24G222",
            kind: .fullInstaller,
            bootStrategy: .nativeMacIntel,
            requiredBytes: 15 * 1_024 * 1_024 * 1_024,
            minimumPartitionBytes: 19 * 1_024 * 1_024 * 1_024
        )

        // swiftformat:disable:next redundantType
        let plan: InstallerPlan = try InstallerPlanBuilder().build(
            diskIdentifier: "disk99",
            diskSizeBytes: 64 * 1_024 * 1_024 * 1_024,
            targets: [tahoe, sequoia]
        )

        XCTAssertEqual(plan.partitions.count, 3)
        XCTAssertEqual(plan.partitions.first?.name, "EFI")
        XCTAssertEqual(plan.partitions.dropFirst().map(\.fileSystem), ["HFS+", "HFS+"])
        XCTAssertEqual(plan.targets.map(\.build), ["25A354", "24G222"])
        XCTAssertTrue(plan.fitsOnDisk)
    }

    func testPlanRejectsInsufficientDiskSpace() {
        let target: InstallerTarget = .init(
            name: "Install macOS Tahoe",
            version: "26.0",
            build: "25A354",
            kind: .fullInstaller,
            bootStrategy: .openCore,
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

    func testPlanRejectsDuplicateMacOSBuilds() {
        let target: InstallerTarget = .init(
            name: "Install macOS Tahoe",
            version: "26.0",
            build: "25A354",
            kind: .fullInstaller,
            bootStrategy: .openCore,
            requiredBytes: 16 * 1_024 * 1_024 * 1_024,
            minimumPartitionBytes: 20 * 1_024 * 1_024 * 1_024
        )

        XCTAssertThrowsError(
            try InstallerPlanBuilder().build(
                diskIdentifier: "disk99",
                diskSizeBytes: 64 * 1_024 * 1_024 * 1_024,
                targets: [target, target]
            )
        ) { error in
            XCTAssertEqual(
                error as? InstallerPlanningError,
                .duplicateInstallerBuild("25A354")
            )
        }
    }

    func testPlanRejectsSizeOverflow() {
        let target: InstallerTarget = .init(
            name: "Install macOS Tahoe",
            version: "26.0",
            build: "25A354",
            kind: .fullInstaller,
            bootStrategy: .openCore,
            requiredBytes: 1,
            minimumPartitionBytes: .max
        )

        XCTAssertThrowsError(
            try InstallerPlanBuilder().build(
                diskIdentifier: "disk99",
                diskSizeBytes: .max,
                targets: [target]
            )
        ) { error in
            XCTAssertEqual(error as? InstallerPlanningError, .planSizeOverflow)
        }
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
