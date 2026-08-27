//  UniversalInstallerServices.swift
//  Mist
//

import Foundation

protocol InstallerProvider: Sendable {
    var platform: InstallerPlatform { get }

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
    func discoverEFIs() async throws -> [URL]
    func backupEFI(at url: URL, to destination: URL) async throws
    func validateEFI(at url: URL) async throws
    func generateEFI(
        for profile: HardwareProfile,
        target: InstallerTarget,
        destination: URL
    ) async throws
    func deployEFI(from source: URL, to destination: URL) async throws
}

enum InstallerPlanningError: LocalizedError {
    case emptySelection
    case invalidDiskSize
    case targetTooLarge(String)
    case planExceedsDisk(required: UInt64, available: UInt64)

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            "At least one installer target must be selected."
        case .invalidDiskSize:
            "The selected disk size is invalid."
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

        var partitions: [PlannedPartition] = [
            PlannedPartition(
                name: "EFI",
                sizeBytes: efiPartitionBytes,
                fileSystem: "FAT32"
            )
        ]

        for target in targets {
            guard target.minimumPartitionBytes >= target.requiredBytes else {
                throw InstallerPlanningError.targetTooLarge(target.name)
            }

            partitions.append(
                PlannedPartition(
                    name: target.name,
                    sizeBytes: target.minimumPartitionBytes,
                    fileSystem: defaultFileSystem(for: target.platform),
                    targetID: target.id
                )
            )
        }

        let plan: InstallerPlan = .init(
            diskIdentifier: diskIdentifier,
            diskSizeBytes: diskSizeBytes,
            partitions: partitions,
            targets: targets,
            reserveBytes: reserveBytes
        )

        guard plan.fitsOnDisk else {
            throw InstallerPlanningError.planExceedsDisk(
                required: plan.allocatedBytes + reserveBytes,
                available: diskSizeBytes
            )
        }

        return plan
    }

    private func defaultFileSystem(for platform: InstallerPlatform) -> String {
        switch platform {
        case .macOS, .recovery:
            "HFS+"
        case .windows:
            "exFAT/NTFS"
        case .linux, .utility, .custom:
            "FAT32/exFAT"
        }
    }
}
