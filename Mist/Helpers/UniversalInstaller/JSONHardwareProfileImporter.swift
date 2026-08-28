//
//  JSONHardwareProfileImporter.swift
//  Mist
//

import Foundation

// swiftlint:disable:next file_types_order
struct JSONHardwareProfileImporter: HardwareProfiling {
    var maximumFileBytes: Int = 1_024 * 1_024
    var maximumDeviceCount: Int = 512

    func importProfile(from url: URL) async throws -> HardwareProfile {
        let data: Data = try reportData(from: url)
        let report: JSONHardwareReport = try decodeReport(from: data)

        guard report.schemaVersion == 1 else {
            throw HardwareProfileImportError.unsupportedSchemaVersion(report.schemaVersion)
        }
        guard !report.devices.isEmpty else {
            throw HardwareProfileImportError.emptyDeviceList
        }
        guard report.devices.count <= maximumDeviceCount else {
            throw HardwareProfileImportError.tooManyDevices(maximum: maximumDeviceCount)
        }

        let manufacturer: String = try normalizedRequired(report.manufacturer, field: "manufacturer")
        guard manufacturer.caseInsensitiveCompare("Apple Inc.") == .orderedSame else {
            throw HardwareProfileImportError.unsupportedManufacturer(manufacturer)
        }

        let modelIdentifier: String = try normalizedRequired(report.modelIdentifier, field: "modelIdentifier")
        guard isAppleModelIdentifier(modelIdentifier) else {
            throw HardwareProfileImportError.invalidAppleModelIdentifier(modelIdentifier)
        }

        return try HardwareProfile(
            schemaVersion: report.schemaVersion,
            manufacturer: "Apple Inc.",
            platform: report.platform,
            modelIdentifier: modelIdentifier,
            modelName: normalizedOptional(report.modelName, field: "modelName"),
            boardName: normalizedOptional(report.boardName, field: "boardName"),
            devices: report.devices.map(makeDevice),
            acpiTableNames: report.acpiTableNames.map { name in
                try normalizedRequired(name, field: "acpiTableNames")
            }
        )
    }

    func profileLocalHardware() async throws -> HardwareProfile {
        throw HardwareProfileImportError.localHardwareDiscoveryUnavailable
    }

    private func reportData(from url: URL) throws -> Data {
        guard url.isFileURL else {
            throw HardwareProfileImportError.invalidURL
        }

        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ])
        } catch {
            throw HardwareProfileImportError.unreadableFile
        }

        guard values.isSymbolicLink != true else {
            throw HardwareProfileImportError.symbolicLinkNotAllowed
        }
        guard values.isRegularFile == true else {
            throw HardwareProfileImportError.notRegularFile
        }
        guard let fileSize: Int = values.fileSize, fileSize <= maximumFileBytes else {
            throw HardwareProfileImportError.fileTooLarge(maximumBytes: maximumFileBytes)
        }

        do {
            return try Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
        } catch {
            throw HardwareProfileImportError.unreadableFile
        }
    }

    private func decodeReport(from data: Data) throws -> JSONHardwareReport {
        do {
            return try JSONDecoder().decode(JSONHardwareReport.self, from: data)
        } catch {
            throw HardwareProfileImportError.invalidReport
        }
    }

    private func makeDevice(from report: JSONHardwareDevice) throws -> HardwareDevice {
        let name: String = try normalizedRequired(report.name, field: "devices.name")

        return try HardwareDevice(
            category: report.category,
            name: name,
            vendorID: normalizedOptional(report.vendorID, field: "devices.vendorID"),
            deviceID: normalizedOptional(report.deviceID, field: "devices.deviceID"),
            subsystemID: normalizedOptional(report.subsystemID, field: "devices.subsystemID")
        )
    }

    private func normalizedRequired(_ value: String, field: String) throws -> String {
        let normalized: String = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw HardwareProfileImportError.emptyField(field)
        }
        return normalized
    }

    private func normalizedOptional(_ value: String?, field: String) throws -> String? {
        guard let value else {
            return nil
        }
        return try normalizedRequired(value, field: field)
    }

    private func isAppleModelIdentifier(_ value: String) -> Bool {
        value.range(
            of: #"^(MacBook|MacBookAir|MacBookPro|Macmini|iMac|iMacPro|MacPro|Xserve|Mac)[0-9]+,[0-9]+$"#,
            options: .regularExpression
        ) != nil
    }
}

enum HardwareProfileImportError: LocalizedError, Equatable {
    case invalidURL
    case unreadableFile
    case symbolicLinkNotAllowed
    case notRegularFile
    case fileTooLarge(maximumBytes: Int)
    case invalidReport
    case unsupportedSchemaVersion(Int)
    case emptyDeviceList
    case tooManyDevices(maximum: Int)
    case emptyField(String)
    case unsupportedManufacturer(String)
    case invalidAppleModelIdentifier(String)
    case localHardwareDiscoveryUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Hardware reports must be imported from a local file."
        case .unreadableFile:
            "The selected hardware report could not be read."
        case .symbolicLinkNotAllowed:
            "Hardware reports cannot be imported through a symbolic link."
        case .notRegularFile:
            "The selected hardware report is not a regular file."
        case let .fileTooLarge(maximumBytes):
            "The hardware report exceeds the maximum size of \(maximumBytes) bytes."
        case .invalidReport:
            "The selected file is not a valid hardware report."
        case let .unsupportedSchemaVersion(version):
            "Hardware report schema version \(version) is not supported."
        case .emptyDeviceList:
            "The hardware report does not contain any devices."
        case let .tooManyDevices(maximum):
            "The hardware report contains more than \(maximum) devices."
        case let .emptyField(field):
            "The hardware report contains an empty \(field) field."
        case let .unsupportedManufacturer(manufacturer):
            "Hardware from \(manufacturer) is outside this app's Apple Mac support scope."
        case let .invalidAppleModelIdentifier(identifier):
            "\(identifier) is not a recognized Apple Mac model identifier."
        case .localHardwareDiscoveryUnavailable:
            "Local hardware discovery is not available yet."
        }
    }
}

private struct JSONHardwareReport: Decodable {
    var schemaVersion: Int
    var manufacturer: String
    var platform: AppleHardwarePlatform
    var modelIdentifier: String
    var modelName: String?
    var boardName: String?
    var devices: [JSONHardwareDevice]
    var acpiTableNames: [String]
}

private struct JSONHardwareDevice: Decodable {
    var category: HardwareCategory
    var name: String
    var vendorID: String?
    var deviceID: String?
    var subsystemID: String?
}
