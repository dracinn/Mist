//
//  MistTests.swift
//  MistTests
//
//  Created by Nindi Gill on 8/12/2022.
//

@testable import Mist
import XCTest

final class MistTests: XCTestCase {
    func testCancelledTaskManagerState() {
        let task: MistTask = .init(type: .download, state: .cancelled, description: "fixture") {}
        let taskManager: TaskManager = .init(taskGroups: [(section: .download, tasks: [task])])

        XCTAssertEqual(taskManager.currentState, .cancelled)
        XCTAssertEqual(task.currentDescription, "Cancelled download fixture")
    }
}
