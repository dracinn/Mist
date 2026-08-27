//
//  EFIPartitionDiscoveryTests.swift
//  MistTests
//

import Foundation
@testable import Mist
import XCTest

final class EFIPartitionDiscoveryTests: XCTestCase {
    func testParserReadsOnlyEFIIdentifiersForSelectedDisk() throws {
        let data: Data = try PropertyListSerialization.data(
            fromPropertyList: [
                "AllDisksAndPartitions": [
                    [
                        "DeviceIdentifier": "disk4",
                        "Partitions": [
                            ["Content": "EFI", "DeviceIdentifier": "disk4s1"],
                            ["Content": "Apple_APFS", "DeviceIdentifier": "disk4s2"]
                        ]
                    ],
                    [
                        "DeviceIdentifier": "disk5",
                        "Partitions": [
                            ["Content": "EFI", "DeviceIdentifier": "disk5s1"]
                        ]
                    ]
                ]
            ],
            format: .xml,
            options: 0
        )

        XCTAssertEqual(
            try DiskutilEFIPartitionParser().efiPartitionIdentifiers(
                from: data,
                parentDiskIdentifier: "disk4"
            ),
            ["disk4s1"]
        )
    }

    func testParserAcceptsMountedEFIOnSelectedDisk() throws {
        let partition: EFIPartition? = try DiskutilEFIPartitionParser().efiPartition(
            from: partitionInfoData(),
            parentDiskIdentifier: "disk4"
        )

        XCTAssertEqual(partition?.identifier, "disk4s1")
        XCTAssertEqual(partition?.parentDiskIdentifier, "disk4")
        XCTAssertEqual(partition?.name, "EFI")
        XCTAssertEqual(partition?.sizeBytes, 512 * 1_024 * 1_024)
        XCTAssertEqual(partition?.mountPoint?.path, "/Volumes/EFI")
    }

    func testParserAcceptsUnmountedEFI() throws {
        let data: Data = try partitionInfoData(
            overrides: ["MountPoint": ""]
        )

        XCTAssertNil(
            try DiskutilEFIPartitionParser().efiPartition(
                from: data,
                parentDiskIdentifier: "disk4"
            )?.mountPoint
        )
    }

    func testParserRejectsUnrelatedOrUnsafePartitions() throws {
        let rejectedOverrides: [[String: Any]] = [
            ["Content": "Apple_APFS"],
            ["ParentWholeDisk": "disk5"],
            ["WholeDisk": true],
            ["Size": 0]
        ]

        for overrides in rejectedOverrides {
            XCTAssertNil(
                try DiskutilEFIPartitionParser().efiPartition(
                    from: partitionInfoData(overrides: overrides),
                    parentDiskIdentifier: "disk4"
                )
            )
        }
    }

    func testParserAcceptsOnlyWholeDiskIdentifiers() {
        let parser: DiskutilEFIPartitionParser = .init()

        XCTAssertTrue(parser.isWholeDiskIdentifier("disk4"))
        XCTAssertFalse(parser.isWholeDiskIdentifier("disk4s1"))
        XCTAssertFalse(parser.isWholeDiskIdentifier("/dev/disk4"))
        XCTAssertFalse(parser.isWholeDiskIdentifier("disk"))
    }

    private func partitionInfoData(overrides: [String: Any] = [:]) throws -> Data {
        var propertyList: [String: Any] = [
            "Content": "EFI",
            "DeviceIdentifier": "disk4s1",
            "MountPoint": "/Volumes/EFI",
            "ParentWholeDisk": "disk4",
            "Size": 512 * 1_024 * 1_024,
            "VolumeName": "EFI",
            "WholeDisk": false
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
