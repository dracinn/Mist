//
//  HardwareProfileImporterTests.swift
//  MistTests
//

@testable import Mist
import XCTest

final class HardwareProfileImporterTests: XCTestCase {
    private var temporaryDirectory: URL = FileManager.default.temporaryDirectory

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testImportsVersionOneJSONReport() async throws {
        let report: String =
            #"{"schemaVersion":1,"modelName":"  Test Mac  ","boardName":"TestBoard","devices":["#
                + #"{"category":"cpu","name":" Intel Core CPU ","vendorID":" 8086 "},"#
                + #"{"category":"gpu","name":"Example GPU","deviceID":"1234"}],"#
                + #""acpiTableNames":[" DSDT ","SSDT-EC"]}"#
        let url: URL = try writeReport(report)

        let profile: HardwareProfile = try await JSONHardwareProfileImporter().importProfile(from: url)

        XCTAssertEqual(profile.schemaVersion, 1)
        XCTAssertEqual(profile.modelName, "Test Mac")
        XCTAssertEqual(profile.boardName, "TestBoard")
        XCTAssertEqual(profile.devices.map(\.category), [.cpu, .gpu])
        XCTAssertEqual(profile.devices.map(\.name), ["Intel Core CPU", "Example GPU"])
        XCTAssertEqual(profile.devices.first?.vendorID, "8086")
        XCTAssertEqual(profile.acpiTableNames, ["DSDT", "SSDT-EC"])
    }

    func testRejectsRemoteURL() async throws {
        let url: URL = try XCTUnwrap(.init(string: "https://example.com/hardware.json"))

        await assertThrowsErrorAsync {
            try await JSONHardwareProfileImporter().importProfile(from: url)
        } errorHandler: { error in
            XCTAssertEqual(error as? HardwareProfileImportError, .invalidURL)
        }
    }

    func testRejectsUnsupportedSchemaVersion() async throws {
        let url: URL = try writeReport(
            #"{"schemaVersion":2,"devices":[{"category":"cpu","name":"CPU"}],"acpiTableNames":[]}"#
        )

        await assertThrowsErrorAsync {
            try await JSONHardwareProfileImporter().importProfile(from: url)
        } errorHandler: { error in
            XCTAssertEqual(
                error as? HardwareProfileImportError,
                .unsupportedSchemaVersion(2)
            )
        }
    }

    func testRejectsEmptyDeviceList() async throws {
        let url: URL = try writeReport(
            #"{"schemaVersion":1,"devices":[],"acpiTableNames":[]}"#
        )

        await assertThrowsErrorAsync {
            try await JSONHardwareProfileImporter().importProfile(from: url)
        } errorHandler: { error in
            XCTAssertEqual(error as? HardwareProfileImportError, .emptyDeviceList)
        }
    }

    func testRejectsOversizedReportBeforeDecoding() async throws {
        let url: URL = temporaryDirectory.appendingPathComponent("large.json")
        try Data(repeating: 0x20, count: 257).write(to: url)
        let importer: JSONHardwareProfileImporter = .init(maximumFileBytes: 256)

        await assertThrowsErrorAsync {
            try await importer.importProfile(from: url)
        } errorHandler: { error in
            XCTAssertEqual(
                error as? HardwareProfileImportError,
                .fileTooLarge(maximumBytes: 256)
            )
        }
    }

    func testRejectsEmptyDeviceName() async throws {
        let url: URL = try writeReport(
            #"{"schemaVersion":1,"devices":[{"category":"cpu","name":"  "}],"acpiTableNames":[]}"#
        )

        await assertThrowsErrorAsync {
            try await JSONHardwareProfileImporter().importProfile(from: url)
        } errorHandler: { error in
            XCTAssertEqual(
                error as? HardwareProfileImportError,
                .emptyField("devices.name")
            )
        }
    }

    func testRejectsSymbolicLink() async throws {
        let targetURL: URL = try writeReport(
            #"{"schemaVersion":1,"devices":[{"category":"cpu","name":"CPU"}],"acpiTableNames":[]}"#
        )
        let linkURL: URL = temporaryDirectory.appendingPathComponent("hardware-link.json")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        await assertThrowsErrorAsync {
            try await JSONHardwareProfileImporter().importProfile(from: linkURL)
        } errorHandler: { error in
            XCTAssertEqual(
                error as? HardwareProfileImportError,
                .symbolicLinkNotAllowed
            )
        }
    }

    func testLocalHardwareDiscoveryRemainsUnavailable() async {
        await assertThrowsErrorAsync {
            try await JSONHardwareProfileImporter().profileLocalHardware()
        } errorHandler: { error in
            XCTAssertEqual(
                error as? HardwareProfileImportError,
                .localHardwareDiscoveryUnavailable
            )
        }
    }

    private func writeReport(_ contents: String) throws -> URL {
        let url: URL = temporaryDirectory.appendingPathComponent("hardware.json")
        try Data(contents.utf8).write(to: url)
        return url
    }
}

/// Asserts that an asynchronous expression throws and forwards the captured error.
private func assertThrowsErrorAsync(
    _ expression: () async throws -> some Any,
    errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw an error.", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
