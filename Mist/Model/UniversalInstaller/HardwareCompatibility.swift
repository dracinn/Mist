//  HardwareCompatibility.swift
//  Mist
//

import Foundation

enum HardwareCategory: String, Codable, CaseIterable, Sendable {
    case cpu
    case gpu
    case audio
    case ethernet
    case wifi
    case bluetooth
    case storage
    case usb
    case input
    case acpi
    case other
}

enum HardwareSupportStatus: String, Codable, CaseIterable, Sendable {
    case supported
    case unsupported
    case unknown
    case requiresConfiguration
}

// swiftlint:disable:next file_types_order
struct HardwareDevice: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var category: HardwareCategory
    var name: String
    var vendorID: String?
    var deviceID: String?
    var subsystemID: String?

    init(
        category: HardwareCategory,
        name: String,
        vendorID: String? = nil,
        deviceID: String? = nil,
        subsystemID: String? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.vendorID = vendorID
        self.deviceID = deviceID
        self.subsystemID = subsystemID
    }
}

struct HardwareProfile: Codable, Hashable, Sendable {
    var schemaVersion: Int = 1
    var modelName: String?
    var boardName: String?
    var devices: [HardwareDevice]
    var acpiTableNames: [String]
}

struct CompatibilityRequirement: Codable, Hashable, Sendable {
    var component: String
    var reason: String
    var required: Bool
}

struct HardwareCompatibilityResult: Codable, Hashable, Sendable {
    var device: HardwareDevice
    var status: HardwareSupportStatus
    var minimumOSVersion: String?
    var maximumOSVersion: String?
    var requirements: [CompatibilityRequirement]
    var notes: [String]
}

struct CompatibilityReport: Codable, Hashable, Sendable {
    var targetName: String
    var results: [HardwareCompatibilityResult]
    var warnings: [String]
    var blockingIssues: [String]

    var isBuildable: Bool {
        blockingIssues.isEmpty && !results.contains { $0.status == .unsupported }
    }
}
