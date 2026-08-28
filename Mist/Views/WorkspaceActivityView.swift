//
//  WorkspaceActivityView.swift
//  Mist
//

import SwiftUI

struct WorkspaceActivityView: View {
    @ObservedObject var taskManager: TaskManager

    private var taskCount: Int {
        taskManager.taskGroups.reduce(0) { $0 + $1.tasks.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            taskList
            Divider()
            Label(
                "This pane observes the shared task queue; it does not start or repeat operations.",
                systemImage: "eye"
            )
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Live view of downloads and installer work managed by Mist.")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Label("\(taskCount) tasks", systemImage: "list.bullet.rectangle")
                .foregroundColor(.secondary)
        }
        .padding(20)
    }

    @ViewBuilder private var taskList: some View {
        if taskManager.taskGroups.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 34))
                    .foregroundColor(.secondary)
                Text("No active tasks")
                    .font(.headline)
                Text("Downloads and installer operations will appear here while they run.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(taskManager.taskGroups, id: \.section) { group in
                    Section(header: ActivitySectionHeaderView(section: group.section)) {
                        ForEach(group.tasks.indices, id: \.self) { index in
                            ActivityRowView(
                                state: group.tasks[index].state,
                                description: group.tasks[index].currentDescription,
                                degrees: group.tasks[index].state == .inProgress ? 360 : 0
                            )
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }
}
