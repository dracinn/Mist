//  UniversalInstallerServices.swift
//  Mist
//

import Foundation

protocol InstallerProvider: Sendable {
    var kind: MacOSInstallerKind { get }

    func validate(target: InstallerTarget) async throws
    func prepare(target: InstallerTarget) async throws
    func install(target: InstallerTarget, to volumeURL: URL) async throws
}

protocol HardwareProfiling: Sendable {
    func importProfile(from url: URL) async throws -> HardwareProfile
    func profileLocalHardware() async throws -> HardwareProfile
}

protocol CompatibilityResolving: Sendable {
    func resolve(
        profile: HardwareProfile,
        target: InstallerTarget
    ) async throws -> CompatibilityReport
}

protocol OpenCoreManaging: Sendable {
    func backupEFI(at url: URL, to destination: URL) async throws
    func validateEFI(at url: URL) async throws
    func generateEFI(
        for profile: HardwareProfile,
        target: InstallerTarget,
        destination: URL
    ) async throws
    func deployEFI(from source: URL, to destination: URL) async throws
}

enum MacOSInstallerTargetError: LocalizedError, Equatable {
    case invalidCatalogMetadata
    case invalidPackageSize
    case missingInstallerSource
    case sizeOverflow

    var errorDescription: String? {
        switch self {
        case .invalidCatalogMetadata:
            "The selected macOS catalog entry is missing its version or build."
        case .invalidPackageSize:
            "The selected macOS catalog entry contains an invalid package size."
        case .missingInstallerSource:
            "The selected macOS catalog entry has no usable installer source."
        case .sizeOverflow:
            "The selected macOS installer is too large to calculate safely."
        }
    }
}

struct MacOSInstallerTargetFactory: Sendable {
    var minimumPartitionBytes: UInt64 = 20 * 1_024 * 1_024 * 1_024
    var partitionOverheadBytes: UInt64 = 4 * 1_024 * 1_024 * 1_024

    func makeTarget(
        from installer: Installer,
        bootStrategy: BootStrategy
    ) throws -> InstallerTarget {
        guard
            !installer.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !installer.build.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw MacOSInstallerTargetError.invalidCatalogMetadata
        }

        let requiredBytes: UInt64 = try packageBytes(for: installer)
        let (recommendedBytes, overflow): (UInt64, Bool) = requiredBytes.addingReportingOverflow(partitionOverheadBytes)
        guard !overflow else {
            throw MacOSInstallerTargetError.sizeOverflow
        }

        return try InstallerTarget(
            name: "Install \(installer.name)",
            version: installer.version,
            build: installer.build,
            kind: .fullInstaller,
            bootStrategy: bootStrategy,
            requiredBytes: requiredBytes,
            minimumPartitionBytes: max(minimumPartitionBytes, recommendedBytes),
            source: sourceURL(for: installer)
        )
    }

    private func packageBytes(for installer: Installer) throws -> UInt64 {
        try installer.packages.reduce(0) { totalBytes, package in
            guard package.size >= 0 else {
                throw MacOSInstallerTargetError.invalidPackageSize
            }

            let (result, overflow): (UInt64, Bool) = totalBytes.addingReportingOverflow(UInt64(package.size))
            guard !overflow else {
                throw MacOSInstallerTargetError.sizeOverflow
            }
            return result
        }
    }

    private func sourceURL(for installer: Installer) throws -> URL {
        let preferredPackage: Package? = installer.packages.first { package in
            package.filename == "InstallAssistant.pkg"
        } ?? installer.packages.first

        guard
            let source = preferredPackage?.url,
            let sourceURL: URL = URL(string: source),
            let scheme: String = sourceURL.scheme,
            scheme.lowercased() == "https"
        else {
            throw MacOSInstallerTargetError.missingInstallerSource
        }

        return sourceURL
    }
}

/// One Apple catalog installer and the boot strategy intended for that target.
struct MacOSInstallerSelection {
    /// The selected Mist catalog installer.
    var installer: Installer
    /// The boot path to use for this installer target.
    var bootStrategy: BootStrategy
}

struct MacOSInstallerPreviewBuilder: Sendable {
    var targetFactory: MacOSInstallerTargetFactory = .init()
    var planBuilder: InstallerPlanBuilder = .init()

    func preview(
        selections: [MacOSInstallerSelection],
        diskIdentifier: String,
        diskSizeBytes: UInt64
    ) throws -> InstallerPlanPreview {
        let targets: [InstallerTarget] = try selections.map { selection in
            try targetFactory.makeTarget(
                from: selection.installer,
                bootStrategy: selection.bootStrategy
            )
        }

        return try planBuilder.preview(
            diskIdentifier: diskIdentifier,
            diskSizeBytes: diskSizeBytes,
            targets: targets
        )
    }
}

enum InstallerPlanningError: LocalizedError, Equatable {
    case emptySelection
    case invalidDiskSize
    case duplicateInstallerBuild(String)
    case planSizeOverflow
    case targetTooLarge(String)
    case planExceedsDisk(required: UInt64, available: UInt64)

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            "At least one installer target must be selected."
        case .invalidDiskSize:
            "The selected disk size is invalid."
        case let .duplicateInstallerBuild(build):
            "The macOS installer build \(build) was selected more than once."
        case .planSizeOverflow:
            "The requested installer plan is too large to calculate safely."
        case let .targetTooLarge(name):
            "The requested partition for \(name) is smaller than its minimum size."
        case let .planExceedsDisk(required, available):
            "The installer plan requires \(required) bytes but the disk has \(available) bytes available."
        }
    }
}

struct InstallerPlanBuilder: Sendable {
    var efiPartitionBytes: UInt64 = 512 * 1_024 * 1_024
    var reserveBytes: UInt64 = 1_024 * 1_024 * 1_024

    func build(
        diskIdentifier: String,
        diskSizeBytes: UInt64,
        targets: [InstallerTarget]
    ) throws -> InstallerPlan {
        guard diskSizeBytes > 0 else {
            throw InstallerPlanningError.invalidDiskSize
        }
        guard !targets.isEmpty else {
            throw InstallerPlanningError.emptySelection
        }

        try validate(targets: targets)

        let plan: InstallerPlan = .init(
            diskIdentifier: diskIdentifier,
            diskSizeBytes: diskSizeBytes,
            partitions: partitions(for: targets),
            targets: targets,
            reserveBytes: reserveBytes
        )

        let (requiredBytes, overflow): (UInt64, Bool) = plan.allocatedBytes.addingReportingOverflow(reserveBytes)
        guard !overflow else {
            throw InstallerPlanningError.planSizeOverflow
        }

        guard requiredBytes <= diskSizeBytes else {
            throw InstallerPlanningError.planExceedsDisk(
                required: requiredBytes,
                available: diskSizeBytes
            )
        }

        return plan
    }

    func preview(
        diskIdentifier: String,
        diskSizeBytes: UInt64,
        targets: [InstallerTarget]
    ) throws -> InstallerPlanPreview {
        let plan: InstallerPlan = try build(
            diskIdentifier: diskIdentifier,
            diskSizeBytes: diskSizeBytes,
            targets: targets
        )
        return InstallerPlanPreview(plan: plan)
    }

    private func validate(targets: [InstallerTarget]) throws {
        let builds: [String] = targets.map(\.build)
        guard Set(builds).count == builds.count else {
            let duplicateBuild: String = builds.first { build in
                builds.filter { $0 == build }.count > 1
            } ?? "unknown"
            throw InstallerPlanningError.duplicateInstallerBuild(duplicateBuild)
        }

        for target in targets where target.minimumPartitionBytes < target.requiredBytes {
            throw InstallerPlanningError.targetTooLarge(target.name)
        }
    }

    private func partitions(for targets: [InstallerTarget]) -> [PlannedPartition] {
        var partitions: [PlannedPartition] = [
            PlannedPartition(
                name: "EFI",
                sizeBytes: efiPartitionBytes,
                fileSystem: "FAT32"
            )
        ]

        for target in targets {
            partitions.append(
                PlannedPartition(
                    name: target.name,
                    sizeBytes: target.minimumPartitionBytes,
                    fileSystem: "HFS+",
                    targetID: target.id
                )
            )
        }

        return partitions
    }
}
