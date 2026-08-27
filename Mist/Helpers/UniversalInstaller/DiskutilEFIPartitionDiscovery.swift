//
//  DiskutilEFIPartitionDiscovery.swift
//  Mist
//

import Foundation

// swiftlint:disable:next file_types_order
actor DiskutilEFIPartitionDiscovery: EFIPartitionDiscovering {
    private let executableURL: URL = .init(fileURLWithPath: "/usr/sbin/diskutil")
    private let parser: DiskutilEFIPartitionParser = .init()

    func efiPartitions(on diskIdentifier: String) throws -> [EFIPartition] {
        guard parser.isWholeDiskIdentifier(diskIdentifier) else {
            throw EFIPartitionDiscoveryError.invalidDiskIdentifier
        }

        let listData: Data = try output(arguments: ["list", "-plist", diskIdentifier])
        let identifiers: [String] = try parser.efiPartitionIdentifiers(
            from: listData,
            parentDiskIdentifier: diskIdentifier
        )

        return try identifiers.compactMap { identifier in
            let infoData: Data = try output(arguments: ["info", "-plist", identifier])
            return try parser.efiPartition(
                from: infoData,
                parentDiskIdentifier: diskIdentifier
            )
        }
    }

    private func output(arguments: [String]) throws -> Data {
        let process: Process = .init()
        let outputPipe: Pipe = .init()
        let errorPipe: Pipe = .init()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData: Data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData: Data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message: String = .init(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw EFIPartitionDiscoveryError.commandFailed(message)
        }

        return outputData
    }
}

protocol EFIPartitionDiscovering: Sendable {
    func efiPartitions(on diskIdentifier: String) async throws -> [EFIPartition]
}

enum EFIPartitionDiscoveryError: LocalizedError, Equatable {
    case commandFailed(String)
    case invalidDiskIdentifier

    var errorDescription: String? {
        switch self {
        case let .commandFailed(message):
            message.isEmpty ? "Unable to inspect EFI partitions." : message
        case .invalidDiskIdentifier:
            "EFI discovery requires a whole-disk identifier."
        }
    }
}

struct DiskutilEFIPartitionParser: Sendable {
    func isWholeDiskIdentifier(_ identifier: String) -> Bool {
        guard identifier.hasPrefix("disk") else {
            return false
        }

        let suffix: Substring = identifier.dropFirst(4)
        return !suffix.isEmpty && suffix.allSatisfy(\.isNumber)
    }

    func efiPartitionIdentifiers(
        from data: Data,
        parentDiskIdentifier: String
    ) throws -> [String] {
        let list: EFIDiskListPropertyList = try PropertyListDecoder().decode(
            EFIDiskListPropertyList.self,
            from: data
        )
        let parentDisk: EFIDiskListDisk? = list.disks.first { disk in
            disk.identifier == parentDiskIdentifier
        }

        return parentDisk?.partitions.compactMap { partition in
            partition.content.caseInsensitiveCompare("EFI") == .orderedSame ? partition.identifier : nil
        } ?? []
    }

    func efiPartition(
        from data: Data,
        parentDiskIdentifier: String
    ) throws -> EFIPartition? {
        let info: EFIPartitionInfoPropertyList = try PropertyListDecoder().decode(
            EFIPartitionInfoPropertyList.self,
            from: data
        )

        guard
            info.content.caseInsensitiveCompare("EFI") == .orderedSame,
            info.parentDiskIdentifier == parentDiskIdentifier,
            !info.wholeDisk,
            info.size > 0
        else {
            return nil
        }

        let mountPoint: URL? = info.mountPoint.flatMap { path in
            path.isEmpty ? nil : URL(fileURLWithPath: path)
        }
        let name: String = info.name.flatMap { value in
            value.isEmpty ? nil : value
        } ?? "EFI"

        return EFIPartition(
            identifier: info.identifier,
            parentDiskIdentifier: info.parentDiskIdentifier,
            name: name,
            sizeBytes: info.size,
            mountPoint: mountPoint
        )
    }
}

private struct EFIDiskListPropertyList: Decodable {
    enum CodingKeys: String, CodingKey {
        case disks = "AllDisksAndPartitions"
    }

    var disks: [EFIDiskListDisk]
}

private struct EFIDiskListDisk: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "DeviceIdentifier"
        case partitions = "Partitions"
    }

    var identifier: String
    var partitions: [EFIDiskListPartition]
}

private struct EFIDiskListPartition: Decodable {
    enum CodingKeys: String, CodingKey {
        case content = "Content"
        case identifier = "DeviceIdentifier"
    }

    var content: String
    var identifier: String
}

private struct EFIPartitionInfoPropertyList: Decodable {
    enum CodingKeys: String, CodingKey {
        case content = "Content"
        case identifier = "DeviceIdentifier"
        case mountPoint = "MountPoint"
        case name = "VolumeName"
        case parentDiskIdentifier = "ParentWholeDisk"
        case size = "Size"
        case wholeDisk = "WholeDisk"
    }

    var content: String
    var identifier: String
    var mountPoint: String?
    var name: String?
    var parentDiskIdentifier: String
    var size: UInt64
    var wholeDisk: Bool
}
