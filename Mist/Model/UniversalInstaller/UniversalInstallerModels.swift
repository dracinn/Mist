//
//  UniversalInstallerModels.swift
//  Mist
//
//  Initial architecture scaffold for multi-installer and OpenCore support.
//

// swiftlint:disable file_name file_types_order

import Foundation

enum BootStrategy: String, Codable, CaseIterable, Sendable {
    case nativeMacIntel
    case openCore
    case genericUEFI
    case appleSilicon
    case asahi
}

enum InstallerPlatform: String, Codable, CaseIterable, Sendable {
    case macOS
    case linux
    case windows
    case recovery
    case utility
    case custom
}

struct InstallerTarget: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var platform: InstallerPlatform
    var bootStrategy: BootStrategy
    var source: URL?
    var requiredBytes: UInt64
    var minimumPartitionBytes: UInt64

    init(
        name: String,
        platform: InstallerPlatform,
        bootStrategy: BootStrategy,
        requiredBytes: UInt64,
        minimumPartitionBytes: UInt64,
        source: URL? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.platform = platform
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
        partitions.reduce(0) { $0 + $1.sizeBytes }
    }

    var fitsOnDisk: Bool {
        allocatedBytes + reserveBytes <= diskSizeBytes
    }
}
