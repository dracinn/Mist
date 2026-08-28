//
//  UniversalInstallerTests.swift
//  MistTests
//

@testable import Mist
import XCTest

final class UniversalInstallerTests: XCTestCase {
    func testCatalogInstallerConvertsToMacOSTarget() throws {
        let installer: Installer = .example
        let target: InstallerTarget = try MacOSInstallerTargetFactory().makeTarget(
            from: installer,
            bootStrategy: .openCoreLegacyPatcher
        )

        XCTAssertEqual(target.name, "Install macOS Tahoe")
        XCTAssertEqual(target.version, "26.0")
        XCTAssertEqual(target.build, "25A354")
        XCTAssertEqual(target.kind, .fullInstaller)
        XCTAssertEqual(target.bootStrategy, .openCoreLegacyPatcher)
        XCTAssertEqual(target.requiredBytes, installer.size)
        XCTAssertGreaterThanOrEqual(target.minimumPartitionBytes, target.requiredBytes)
        XCTAssertEqual(target.source?.lastPathComponent, "InstallAssistant.pkg")
    }

    func testCatalogInstallerRequiresUsableSource() {
        let installer: Installer = .init(
            id: "missing-source",
            version: "15.7",
            build: "24G222",
            date: "2025-09-15",
            distributionURL: "",
            distributionSize: 0,
            packages: [],
            boardIDs: [],
            deviceIDs: [],
            unsupportedModelIdentifiers: []
        )

        XCTAssertThrowsError(
            try MacOSInstallerTargetFactory().makeTarget(
                from: installer,
                bootStrategy: .nativeMacIntel
            )
        ) { error in
            XCTAssertEqual(error as? MacOSInstallerTargetError, .missingInstallerSource)
        }
    }

    func testCatalogInstallerRejectsInvalidPackageSize() {
        let installer: Installer = .init(
            id: "invalid-size",
            version: "15.7",
            build: "24G222",
            date: "2025-09-15",
            distributionURL: "",
            distributionSize: 0,
            packages: [
                Package(
                    url: "https://swcdn.apple.com/InstallAssistant.pkg",
                    size: -1,
                    integrityDataURL: nil,
                    integrityDataSize: nil
                )
            ],
            boardIDs: [],
            deviceIDs: [],
            unsupportedModelIdentifiers: []
        )

        XCTAssertThrowsError(
            try MacOSInstallerTargetFactory().makeTarget(
                from: installer,
                bootStrategy: .nativeMacIntel
            )
        ) { error in
            XCTAssertEqual(error as? MacOSInstallerTargetError, .invalidPackageSize)
        }
    }

    func testCatalogSelectionBuildsMultiMacOSPreview() throws {
        let installers: [Installer] = [.example] + Installer.legacyInstallers.prefix(1)
        let selections: [MacOSInstallerSelection] = [
            MacOSInstallerSelection(installer: installers[0], bootStrategy: .openCoreLegacyPatcher),
            MacOSInstallerSelection(installer: installers[1], bootStrategy: .nativeMacIntel)
        ]
        let preview: InstallerPlanPreview = try MacOSInstallerPreviewBuilder().preview(
            selections: selections,
            diskIdentifier: "Preview",
            diskSizeBytes: 64 * 1_024 * 1_024 * 1_024
        )

        XCTAssertEqual(preview.diskIdentifier, "Preview")
        XCTAssertEqual(preview.partitions.count, 3)
        XCTAssertEqual(preview.partitions.first?.name, "EFI")
        XCTAssertEqual(preview.targets.map(\.bootStrategy), [.openCoreLegacyPatcher, .nativeMacIntel])
        XCTAssertGreaterThan(preview.remainingBytes, 0)
    }

    func testMultiOSResourcesKeepArchitectureBoundaries() {
        let intelNames: Set<String> = Set(OperatingSystemResource.intelMacOptions.map(\.name))

        XCTAssertEqual(
            intelNames,
            ["Windows 10", "Windows 11", "Ubuntu Desktop", "Fedora Workstation", "Debian"]
        )
        XCTAssertEqual(OperatingSystemResource.fedoraAsahi.architecture, "Apple Silicon / ARM64")
        XCTAssertTrue(
            OperatingSystemResource.intelMacOptions
                .first { $0.name == "Windows 11" }?
                .supportNote.contains("Not an Apple-supported Boot Camp target") == true
        )
    }

    func testMultiOSResourcesUseSecureOfficialLinks() {
        let resources: [OperatingSystemResource] = OperatingSystemResource.intelMacOptions + [
            .openCoreLegacyPatcher,
            .fedoraAsahi
        ]

        for resource in resources {
            let downloadURL: URL? = URL(string: resource.downloadPage)
            let guideURL: URL? = URL(string: resource.setupGuide)

            XCTAssertEqual(downloadURL?.scheme, "https", resource.name)
            XCTAssertNotNil(downloadURL?.host, resource.name)
            XCTAssertEqual(guideURL?.scheme, "https", resource.name)
            XCTAssertNotNil(guideURL?.host, resource.name)
        }
    }

    func testPlanIncludesEFIAndMultipleMacOSInstallers() throws {
        let tahoe: InstallerTarget = .init(
            name: "Install macOS Tahoe",
            version: "26.0",
            build: "25A354",
            kind: .fullInstaller,
            bootStrategy: .openCoreLegacyPatcher,
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

        let preview: InstallerPlanPreview = try InstallerPlanBuilder().preview(
            diskIdentifier: "disk99",
            diskSizeBytes: 64 * 1_024 * 1_024 * 1_024,
            targets: [tahoe, sequoia]
        )
        XCTAssertEqual(preview.partitions.map(\.name), plan.partitions.map(\.name))
        XCTAssertEqual(preview.partitions.map(\.sizeBytes), plan.partitions.map(\.sizeBytes))
        XCTAssertEqual(
            preview.remainingBytes,
            plan.diskSizeBytes - plan.allocatedBytes - plan.reserveBytes
        )
    }

    func testPlanRejectsInsufficientDiskSpace() {
        let target: InstallerTarget = .init(
            name: "Install macOS Tahoe",
            version: "26.0",
            build: "25A354",
            kind: .fullInstaller,
            bootStrategy: .openCoreLegacyPatcher,
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
            bootStrategy: .openCoreLegacyPatcher,
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
            bootStrategy: .openCoreLegacyPatcher,
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
