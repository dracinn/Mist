//
//  ContentView.swift
//  Mist
//
//  Created by Nindi Gill on 13/6/2022.
//

import SwiftUI

struct ContentView: View {
    private enum WorkspaceSection: String, CaseIterable, Identifiable {
        case catalog
        case installerPlanner
        case multiOS
        case devices
        case activity
        case logs
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .catalog:
                "Apple Catalog"
            case .installerPlanner:
                "Installer Planner"
            case .multiOS:
                "Multi-OS Setup"
            case .devices:
                "Mac Hardware"
            case .activity:
                "Activity"
            case .logs:
                "Logs"
            case .settings:
                "App Settings"
            }
        }

        var subtitle: String {
            switch self {
            case .catalog:
                "macOS firmware and installers"
            case .installerPlanner:
                "Plan macOS media and disk layouts"
            case .multiOS:
                "Windows, Linux, OCLP & Asahi"
            case .devices:
                "Intel & Apple Silicon Macs"
            case .activity:
                "Downloads and installer tasks"
            case .logs:
                "Mist diagnostic log"
            case .settings:
                "Downloads, exports and updates"
            }
        }

        var systemImage: String {
            switch self {
            case .catalog:
                "square.stack.3d.down.right"
            case .installerPlanner:
                "externaldrive.badge.plus"
            case .multiOS:
                "macwindow.on.rectangle"
            case .devices:
                "desktopcomputer"
            case .activity:
                "arrow.down.circle"
            case .logs:
                "doc.text.magnifyingglass"
            case .settings:
                "gearshape"
            }
        }
    }

    @Environment(\.openURL)
    var openURL: OpenURLAction
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
        var filteredFirmwares: [Firmware] = firmwares

        if !searchString.isEmpty, workspaceSection == .catalog {
            let string: String = searchString.lowercased()
            filteredFirmwares = filteredFirmwares.filter {
                $0.name.lowercased().contains(string) ||
                    $0.version.lowercased().contains(string) ||
                    $0.build.lowercased().contains(string) ||
                    $0.formattedDate.lowercased().contains(string)
            }
        }

        if !includeBetas {
            filteredFirmwares = filteredFirmwares.filter { !$0.beta }
        }

        if showCompatible {
            filteredFirmwares = filteredFirmwares.filter(\.compatible)
        }

        return filteredFirmwares
    }

    private var filteredInstallers: [Installer] {
        var filteredInstallers: [Installer] = installers

        if !searchString.isEmpty, workspaceSection == .catalog {
            let string: String = searchString.lowercased()
            filteredInstallers = filteredInstallers.filter {
                $0.name.lowercased().contains(string) ||
                    $0.version.lowercased().contains(string) ||
                    $0.build.lowercased().contains(string) ||
                    $0.date.lowercased().contains(string)
            }
        }

        if !includeBetas {
            filteredInstallers = filteredInstallers.filter { !$0.beta }
        }

        if showCompatible {
            filteredInstallers = filteredInstallers.filter(\.compatible)
        }

        return filteredInstallers
    }

    private let width: CGFloat = 1120
    private let height: CGFloat = 740

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            Divider()
            HSplitView {
                workspaceSidebar
                workspaceDetail
            }
        }
        .frame(minWidth: 920, idealWidth: width, minHeight: 640, idealHeight: height)
        .toolbar {
            Button {
                workspaceSection = .catalog
                refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .foregroundColor(.accentColor)
            }
            .help("Refresh Apple catalogs")

            Button {
                workspaceSection = .activity
            } label: {
                Label("Activity", systemImage: "arrow.down.circle")
                    .foregroundColor(.accentColor)
            }
            .help("Show downloads and installer tasks")
        }
        .searchable(text: $searchString, prompt: workspaceSection == .catalog ? "Search macOS releases" : "Search Apple Catalog")
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
            Image(systemName: "macwindow.on.rectangle")
                .font(.title2)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                Label("Intel Macs", systemImage: "cpu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("Apple Silicon Macs", systemImage: "desktopcomputer")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var workspaceDetail: some View {
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

    private var catalogView: some View {
        VStack(spacing: 0) {
            HeaderView(downloadType: $downloadType)
            Divider()

            if downloadType == .firmware && filteredFirmwares.isEmpty || downloadType == .installer && filteredInstallers.isEmpty {
                EmptyCollectionView("No macOS \(downloadType.description)s found!\n\nಥ_ಥ")
            } else {
                ZStack {
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

                    if copiedToClipboard {
                        FloatingAlert(image: "list.bullet.clipboard.fill", message: "Copied to Clipboard")
                    }
                }
            }

            Divider()
            FooterView(
                includeBetas: $includeBetas,
                showCompatible: $showCompatible,
                downloadType: downloadType,
                firmwares: $firmwares,
                installers: $installers
            )
        }
    }

    private func refresh() {
        refreshing = true
    }

    private func releaseNames(for type: DownloadType) -> [String] {
        var releaseNames: [String] = []

        switch type {
        case .firmware:
            for firmware in filteredFirmwares {
                let releaseName: String = firmware.name.replacingOccurrences(of: " beta", with: "")

                if !releaseNames.contains(releaseName) {
                    releaseNames.append(releaseName)
                }
            }
        case .installer:
            for installer in filteredInstallers {
                let releaseName: String = installer.name.replacingOccurrences(of: " beta", with: "")

                if !releaseNames.contains(releaseName) {
                    releaseNames.append(releaseName)
                }
            }
        }

        return releaseNames
    }

    private func filteredFirmwares(for releaseName: String) -> [Firmware] {
        filteredFirmwares.filter { $0.name.replacingOccurrences(of: " beta", with: "") == releaseName }
    }

    private func filteredInstallers(for releaseName: String) -> [Installer] {
        filteredInstallers.filter { $0.name.replacingOccurrences(of: " beta", with: "") == releaseName }
    }
}

private struct WorkspaceActivityView: View {
    @ObservedObject var taskManager: TaskManager

    private var taskCount: Int {
        taskManager.taskGroups.reduce(0) { $0 + $1.tasks.count }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            Divider()

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
                    ForEach(taskManager.taskGroups, id: \.section) { taskGroup in
                        Section(header: ActivitySectionHeaderView(section: taskGroup.section)) {
                            ForEach(taskGroup.tasks.indices, id: \.self) { index in
                                ActivityRowView(
                                    state: taskGroup.tasks[index].state,
                                    description: taskGroup.tasks[index].currentDescription,
                                    degrees: taskGroup.tasks[index].state == .inProgress ? 360 : 0
                                )
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }

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
}

private struct MacDevicesWorkspaceView: View {
    @State private var hardwareProfile: HardwareProfile?
    @State private var hardwareReportName: String?
    @State private var hardwareImportError: String?
    @State private var disks: [PhysicalDisk] = []
    @State private var efiPartitions: [EFIPartition] = []
    @State private var discoveryError: String?
    @State private var discovering: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mac Hardware")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Review genuine Intel and Apple Silicon Mac hardware, external disks and EFI partitions.")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        Task {
                            await refreshDevices()
                        }
                    } label: {
                        if discovering {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(discovering)
                }

                GroupBox {
                    HardwareProfileReviewView(
                        profile: $hardwareProfile,
                        reportName: $hardwareReportName,
                        importError: $hardwareImportError
                    )
                    .padding(4)
                } label: {
                    Label("Compatibility Profile", systemImage: "desktopcomputer")
                }

                GroupBox {
                    if disks.isEmpty {
                        Text(discovering ? "Discovering external physical disks…" : "No eligible external physical disks found.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(disks) { disk in
                                HStack(spacing: 12) {
                                    Image(systemName: "externaldrive")
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(disk.name)
                                            .fontWeight(.medium)
                                        Text("\(disk.identifier) · \(disk.busProtocol)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(disk.sizeBytes.bytesString())
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                if disk.id != disks.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } label: {
                    Label("External Physical Disks", systemImage: "externaldrive.connected.to.line.below")
                }

                GroupBox {
                    if efiPartitions.isEmpty {
                        Text(discovering ? "Inspecting EFI partitions…" : "No EFI partitions found on eligible external disks.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(efiPartitions) { partition in
                                HStack(spacing: 12) {
                                    Image(systemName: "internaldrive")
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(partition.name)
                                            .fontWeight(.medium)
                                        Text("\(partition.identifier) · parent \(partition.parentDiskIdentifier)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(partition.sizeBytes.bytesString())
                                        Text(partition.mountPoint?.path ?? "Not mounted")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)
                                if partition.id != efiPartitions.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                } label: {
                    Label("EFI Partitions", systemImage: "internaldrive")
                }

                if let discoveryError {
                    Label(discoveryError, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }

                Label(
                    "Read-only inspection only — this screen does not mount, erase, partition or modify EFI content.",
                    systemImage: "checkmark.shield"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await refreshDevices()
        }
    }

    @MainActor
    private func refreshDevices() async {
        discovering = true
        defer {
            discovering = false
        }

        do {
            let discoveredDisks: [PhysicalDisk] = try await DiskutilPhysicalDiskDiscovery().externalPhysicalDisks()
            disks = discoveredDisks
            var discoveredEFI: [EFIPartition] = []

            for disk in discoveredDisks {
                let partitions: [EFIPartition] = try await DiskutilEFIPartitionDiscovery().efiPartitions(on: disk.identifier)
                discoveredEFI.append(contentsOf: partitions)
            }

            efiPartitions = discoveredEFI
            discoveryError = nil
        } catch {
            disks = []
            efiPartitions = []
            discoveryError = error.localizedDescription
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            refreshing: .constant(false),
            tasksInProgress: .constant(false),
            sparkleUpdater: SparkleUpdater()
        )
    }
}
