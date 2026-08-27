//
//  PhysicalDiskDiscoveryTests.swift
//  MistTests
//

import Foundation
@testable import Mist
import XCTest

final class PhysicalDiskDiscoveryTests: XCTestCase {
    func testParserAcceptsSafeExternalPhysicalDisk() throws {
        let disk: PhysicalDisk? = try DiskutilPhysicalDiskParser().physicalDisk(
            from: diskInfoData()
        )

        XCTAssertEqual(disk?.identifier, "disk4")
        XCTAssertEqual(disk?.name, "Test Media")
        XCTAssertEqual(disk?.sizeBytes, 64 * 1_024 * 1_024 * 1_024)
        XCTAssertEqual(disk?.busProtocol, "USB")
    }

    func testParserRejectsInternalDisk() throws {
        let data: Data = try diskInfoData(
            overrides: [
                "DeviceIdentifier": "disk0",
                "Internal": true,
                "RemovableMediaOrExternalDevice": false
            ]
        )

        XCTAssertNil(try DiskutilPhysicalDiskParser().physicalDisk(from: data))
    }

    func testParserRejectsUnsafeDiskKinds() throws {
        let unsafeOverrides: [[String: Any]] = [
            ["VirtualOrPhysical": "Virtual"],
            ["WholeDisk": false],
            ["WritableMedia": false],
            ["Size": 0]
        ]

        for overrides in unsafeOverrides {
            XCTAssertNil(
                try DiskutilPhysicalDiskParser().physicalDisk(
                    from: diskInfoData(overrides: overrides)
                )
            )
        }
    }

    func testParserReadsWholeDiskIdentifiers() throws {
        let data: Data = try PropertyListSerialization.data(
            fromPropertyList: ["WholeDisks": ["disk4", "disk5"]],
            format: .xml,
            options: 0
        )

        XCTAssertEqual(
            try DiskutilPhysicalDiskParser().wholeDiskIdentifiers(from: data),
            ["disk4", "disk5"]
        )
    }

    private func diskInfoData(overrides: [String: Any] = [:]) throws -> Data {
        var propertyList: [String: Any] = [
            "BusProtocol": "USB",
            "DeviceIdentifier": "disk4",
            "Internal": false,
            "MediaName": "Test Media",
            "RemovableMediaOrExternalDevice": true,
            "Size": 64 * 1_024 * 1_024 * 1_024,
            "VirtualOrPhysical": "Physical",
            "WholeDisk": true,
            "WritableMedia": true
        ]

        for (key, value) in overrides {
            propertyList[key] = value
        }

        return try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
    }
}
