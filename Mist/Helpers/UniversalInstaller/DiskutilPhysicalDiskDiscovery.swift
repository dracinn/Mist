//
//  DiskutilPhysicalDiskDiscovery.swift
//  Mist
//

import Foundation

// swiftlint:disable:next file_types_order
actor DiskutilPhysicalDiskDiscovery: PhysicalDiskDiscovering {
    private let executableURL: URL = .init(fileURLWithPath: "/usr/sbin/diskutil")
    private let parser: DiskutilPhysicalDiskParser = .init()

    func externalPhysicalDisks() throws -> [PhysicalDisk] {
        let listData: Data = try output(arguments: ["list", "-plist", "external", "physical"])
        let identifiers: [String] = try parser.wholeDiskIdentifiers(from: listData)

        return try identifiers.compactMap { identifier in
            let infoData: Data = try output(arguments: ["info", "-plist", identifier])
            return try parser.physicalDisk(from: infoData)
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
            throw PhysicalDiskDiscoveryError.commandFailed(message)
        }

        return outputData
    }
}

protocol PhysicalDiskDiscovering: Sendable {
    func externalPhysicalDisks() async throws -> [PhysicalDisk]
}

enum PhysicalDiskDiscoveryError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(message):
            message.isEmpty ? "Unable to inspect external physical disks." : message
        }
    }
}

struct DiskutilPhysicalDiskParser: Sendable {
    func wholeDiskIdentifiers(from data: Data) throws -> [String] {
        try PropertyListDecoder().decode(DiskListPropertyList.self, from: data).wholeDisks
    }

    func physicalDisk(from data: Data) throws -> PhysicalDisk? {
        let info: DiskInfoPropertyList = try PropertyListDecoder().decode(DiskInfoPropertyList.self, from: data)

        guard
            !info.internalDisk,
            info.wholeDisk,
            info.virtualOrPhysical == "Physical",
            info.externalDevice,
            info.writableMedia,
            info.size > 0
        else {
            return nil
        }

        return PhysicalDisk(
            identifier: info.deviceIdentifier,
            name: info.mediaName.isEmpty ? info.deviceIdentifier : info.mediaName,
            sizeBytes: info.size,
            busProtocol: info.busProtocol.isEmpty ? "External" : info.busProtocol
        )
    }
}

private struct DiskListPropertyList: Decodable {
    enum CodingKeys: String, CodingKey {
        case wholeDisks = "WholeDisks"
    }

    var wholeDisks: [String]
}

private struct DiskInfoPropertyList: Decodable {
    enum CodingKeys: String, CodingKey {
        case busProtocol = "BusProtocol"
        case deviceIdentifier = "DeviceIdentifier"
        case externalDevice = "RemovableMediaOrExternalDevice"
        case internalDisk = "Internal"
        case mediaName = "MediaName"
        case size = "Size"
        case virtualOrPhysical = "VirtualOrPhysical"
        case wholeDisk = "WholeDisk"
        case writableMedia = "WritableMedia"
    }

    var busProtocol: String
    var deviceIdentifier: String
    var externalDevice: Bool
    var internalDisk: Bool
    var mediaName: String
    var size: UInt64
    var virtualOrPhysical: String
    var wholeDisk: Bool
    var writableMedia: Bool
}
