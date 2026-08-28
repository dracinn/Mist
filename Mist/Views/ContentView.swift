//
//  ContentView.swift
//  Mist
//
//  Created by Nindi Gill on 13/6/2022.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("downloadType")
    private var downloadType: DownloadType = .firmware
    @AppStorage("includeBetas")
    private var includeBetas: Bool = false
    @AppStorage("showCompatible")
    private var showCompatible: Bool = false
    @Binding var refreshing: Bool
    @Binding var tasksInProgress: Bool
    @ObservedObject var sparkleUpdater: SparkleUpdater
    @State private var workspaceSection: WorkspaceSection = .catalog
    @State private var firmwares: [Firmware] = []
    @State private var installers: [Installer] = []
    @State private var searchString: String = ""
    @State private var openPanel: NSOpenPanel = .init()
    @State private var savePanel: NSSavePanel = .init()
    @State private var copiedToClipboard: Bool = false
    @StateObject private var taskManager: TaskManager = .shared
    @StateObject private var logManager: LogManager = .shared

    private var filteredFirmwares: [Firmware] {
        var values: [Firmware] = firmwares

        if !searchString.isEmpty {
            let value: String = searchString.lowercased()
            values = values.filter {
                $0.name.lowercased().contains(value)
                    || $0.version.lowercased().contains(value)
                    || $0.build.lowercased().contains(value)
                    || $0.formattedDate.lowercased().contains(value)
            }
        }
        if !includeBetas {
            values = values.filter { !$0.beta }
        }
        if showCompatible {
            values = values.filter(\.compatible)
        }
        return values
    }

    private var filteredInstallers: [Installer] {
        var values: [Installer] = installers

        if !searchString.isEmpty {
            let value: String = searchString.lowercased()
            values = values.filter {
                $0.name.lowercased().contains(value)
                    || $0.version.lowercased().contains(value)
                    || $0.build.lowercased().contains(value)
                    || $0.date.lowercased().contains(value)
            }
        }
        if !includeBetas {
            values = values.filter { !$0.beta }
        }
        if showCompatible {
            values = values.filter(\.compatible)
        }
        return values
    }

    private var activeTaskCount: Int {
        taskManager.taskGroups.reduce(0) { count, group in
            count + group.tasks.filter { $0.state == .inProgress }.count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            Divider()
            HSplitView {
                workspaceSidebar
                workspaceDetail
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 980, idealWidth: 1_180, minHeight: 660, idealHeight: 760)
        .toolbar {
            Button {
                workspaceSection = .activity
            } label: {
                Label("Activity", systemImage: "waveform.path.ecg")
            }
            Button {
                workspaceSection = .catalog
                refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .sheet(isPresented: $refreshing) {
            RefreshView(firmwares: $firmwares, installers: $installers)
        }
        .onAppear {
            refresh()
        }
        .onChange(of: copiedToClipboard) { copied in
            guard copied else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    copiedToClipboard = false
                }
            }
        }
        .onChange(of: workspaceSection) { section in
            if section != .catalog {
                searchString = ""
            }
        }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mist Universal")
                    .font(.headline)
                Text(workspaceSection.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Label("Mac hardware only", systemImage: "desktopcomputer")
                .font(.caption)
                .foregroundColor(.secondary)
            if tasksInProgress {
                Label("Task in progress", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
    }

    private var workspaceSidebar: some View {
        List {
            Section("Library") {
                workspaceButton(.catalog)
            }
            Section("Create") {
                workspaceButton(.installerPlanner)
                workspaceButton(.multiOS)
            }
            Section("Devices") {
                workspaceButton(.devices)
            }
            Section("Activity") {
                workspaceButton(.activity)
                workspaceButton(.logs)
            }
            Section("Settings") {
                workspaceButton(.settings)
            }
            Section("Catalog Status") {
                Label("\(firmwares.count) firmwares", systemImage: "shippingbox")
                    .font(.caption)
                Label("\(installers.count) installers", systemImage: "macwindow")
                    .font(.caption)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 225, idealWidth: 245, maxWidth: 280)
    }

    @ViewBuilder private var workspaceDetail: some View {
        switch workspaceSection {
        case .catalog:
            catalogView
        case .installerPlanner:
            UniversalInstallerPreviewView(installers: filteredInstallers, embedded: true)
        case .multiOS:
            MultiOSSetupView(installers: filteredInstallers, embedded: true)
        case .devices:
            MacDevicesWorkspaceView()
        case .activity:
            WorkspaceActivityView(taskManager: taskManager)
        case .logs:
            LogView(logEntries: logManager.logEntries, embedded: true)
        case .settings:
            SettingsView(sparkleUpdater: sparkleUpdater, embedded: true)
        }
    }

    private func workspaceButton(_ section: WorkspaceSection) -> some View {
        Button {
            workspaceSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                    Text(section.subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if workspaceSection == section {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func refresh() {
        refreshing = true
    }
}

private extension ContentView {
    /// The searchable Apple catalog workspace.
    var catalogView: some View {
        VStack(spacing: 0) {
            catalogHeader
            HeaderView(downloadType: $downloadType)
            Divider()
            catalogContent
            Divider()
            FooterView(
                includeBetas: $includeBetas,
                showCompatible: $showCompatible,
                downloadType: downloadType,
                firmwares: $firmwares,
                installers: $installers
            )
        }
        .searchable(text: $searchString, prompt: "Search macOS releases")
    }

    /// The Apple catalog heading.
    var catalogHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Catalog")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Browse Apple macOS firmware and installers for genuine Intel and Apple Silicon Macs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    /// The current catalog results or empty state.
    @ViewBuilder var catalogContent: some View {
        if
            downloadType == .firmware && filteredFirmwares.isEmpty
            || downloadType == .installer && filteredInstallers.isEmpty {
            EmptyCollectionView("No macOS \(downloadType.description)s found!\n\nಥ_ಥ")
        } else {
            ZStack {
                catalogList
                if copiedToClipboard {
                    FloatingAlert(image: "list.bullet.clipboard.fill", message: "Copied to Clipboard")
                }
            }
        }
    }

    /// The grouped firmware or installer rows.
    var catalogList: some View {
        List {
            ForEach(releaseNames(for: downloadType), id: \.self) { releaseName in
                Section(header: Text(releaseName)) {
                    switch downloadType {
                    case .firmware:
                        ForEach(filteredFirmwares(for: releaseName)) { firmware in
                            ListRowFirmware(
                                firmware: firmware,
                                savePanel: $savePanel,
                                copiedToClipboard: $copiedToClipboard,
                                tasksInProgress: $tasksInProgress,
                                taskManager: taskManager
                            )
                            .tag(firmware)
                        }
                    case .installer:
                        ForEach(filteredInstallers(for: releaseName)) { installer in
                            ListRowInstaller(
                                installer: installer,
                                openPanel: $openPanel,
                                tasksInProgress: $tasksInProgress,
                                taskManager: taskManager
                            )
                            .tag(installer)
                        }
                    }
                }
            }
        }
    }

    /// The persistent workspace status summary.
    var statusBar: some View {
        HStack(spacing: 18) {
            Label(
                activeTaskCount == 0 ? "Idle" : "\(activeTaskCount) active",
                systemImage: activeTaskCount == 0 ? "checkmark.circle" : "arrow.down.circle"
            )
            Text("\(filteredInstallers.count) installers")
            Text("\(filteredFirmwares.count) firmwares")
            Spacer()
            Text("Mist Universal")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(.ultraThinMaterial)
    }

    /// Returns unique catalog release names in source order.
    ///
    /// - Parameter type: The selected catalog download type.
    ///
    /// - Returns: Unique release names in source order.
    func releaseNames(for type: DownloadType) -> [String] {
        var names: [String] = []
        let values: [String] = type == .firmware
            ? filteredFirmwares.map(\.name)
            : filteredInstallers.map(\.name)

        for value in values {
            let name: String = value.replacingOccurrences(of: " beta", with: "")
            if !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    /// Returns firmware rows for one macOS release.
    ///
    /// - Parameter releaseName: The normalized macOS release name.
    ///
    /// - Returns: Firmware rows matching the release name.
    func filteredFirmwares(for releaseName: String) -> [Firmware] {
        filteredFirmwares.filter { $0.name.replacingOccurrences(of: " beta", with: "") == releaseName }
    }

    /// Returns installer rows for one macOS release.
    ///
    /// - Parameter releaseName: The normalized macOS release name.
    ///
    /// - Returns: Installer rows matching the release name.
    func filteredInstallers(for releaseName: String) -> [Installer] {
        filteredInstallers.filter { $0.name.replacingOccurrences(of: " beta", with: "") == releaseName }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            refreshing: .constant(false),
            tasksInProgress: .constant(false),
            sparkleUpdater: .init()
        )
    }
}
