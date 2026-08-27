//  UniversalInstallerModels.swift
//  Mist
//
//  Initial architecture scaffold for multi-macOS installer and OpenCore support.
//

import Foundation

enum BootStrategy: String, Codable, CaseIterable, Sendable {
    case nativeMacIntel
    case openCore
    case appleSilicon

    var description: String {
        switch self {
        case .nativeMacIntel:
            "Native Intel Mac"
        case .openCore:
            "OpenCore"
        case .appleSilicon:
            "Apple Silicon"
        }
    }
}

enum MacOSInstallerKind: String, Codable, CaseIterable, Sendable {
    case fullInstaller
    case recovery
}

struct PhysicalDisk: Identifiable, Hashable, Sendable {
    var id: String {
        identifier
    }

    var identifier: String
    var name: String
    var sizeBytes: UInt64
    var busProtocol: String
}

// swiftlint:disable:next file_types_order
struct InstallerTarget: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var version: String
    var build: String
    var kind: MacOSInstallerKind
    var bootStrategy: BootStrategy
    var source: URL?
    var requiredBytes: UInt64
    var minimumPartitionBytes: UInt64

    init(
        name: String,
        version: String,
        build: String,
        kind: MacOSInstallerKind,
        bootStrategy: BootStrategy,
        requiredBytes: UInt64,
        minimumPartitionBytes: UInt64,
        source: URL? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.build = build
        self.kind = kind
        self.bootStrategy = bootStrategy
        self.source = source
        self.requiredBytes = requiredBytes
        self.minimumPartitionBytes = minimumPartitionBytes
    }
}

struct PlannedPartition: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var sizeBytes: UInt64
    var fileSystem: String
    var targetID: UUID?

    init(
        name: String,
        sizeBytes: UInt64,
        fileSystem: String,
        targetID: UUID? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.sizeBytes = sizeBytes
        self.fileSystem = fileSystem
        self.targetID = targetID
    }
}

struct InstallerPlan: Codable, Hashable, Sendable {
    var diskIdentifier: String
    var diskSizeBytes: UInt64
    var partitions: [PlannedPartition]
    var targets: [InstallerTarget]
    var reserveBytes: UInt64

    var allocatedBytes: UInt64 {
        partitions.reduce(0) { partialResult, partition in
            let (result, overflow): (UInt64, Bool) = partialResult.addingReportingOverflow(partition.sizeBytes)
            return overflow ? .max : result
        }
    }

    var fitsOnDisk: Bool {
        let (requiredBytes, overflow): (UInt64, Bool) = allocatedBytes.addingReportingOverflow(reserveBytes)
        return !overflow && requiredBytes <= diskSizeBytes
    }
}

struct InstallerPlanPreview: Equatable, Sendable {
    var diskIdentifier: String
    var diskSizeBytes: UInt64
    var allocatedBytes: UInt64
    var reserveBytes: UInt64
    var remainingBytes: UInt64
    var partitions: [PlannedPartition]

    init(plan: InstallerPlan) {
        let (usedBytes, overflow): (UInt64, Bool) = plan.allocatedBytes.addingReportingOverflow(plan.reserveBytes)

        diskIdentifier = plan.diskIdentifier
        diskSizeBytes = plan.diskSizeBytes
        allocatedBytes = plan.allocatedBytes
        reserveBytes = plan.reserveBytes
        remainingBytes = overflow || usedBytes > plan.diskSizeBytes ? 0 : plan.diskSizeBytes - usedBytes
        partitions = plan.partitions
    }
}
