//
//  ContentView.swift
//  Mist
//
//  Created by Nindi Gill on 13/6/2022.
//

import SwiftUI

struct ContentView: View {
    private enum WorkspaceSection: String, CaseIterable, Identifiable {
        case catalog, installerPlanner, multiOS, devices, activity, logs, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .catalog: "Apple Catalog"
            case .installerPlanner: "Installer Planner"
            case .multiOS: "Multi-OS Setup"
            case .devices: "Mac Hardware"
            case .activity: "Activity"
            case .logs: "Logs"
            case .settings: "App Settings"
            }
        }
        var subtitle: String {
            switch self {
            case .catalog: "macOS firmware and installers"
            case .installerPlanner: "Plan macOS media and disk layouts"
            case .multiOS: "Windows, Linux, OCLP & Asahi"
            case .devices: "Intel & Apple Silicon Macs"
            case .activity: "Downloads and installer tasks"
            case .logs: "Mist diagnostic log"
            case .settings: "Downloads, exports and updates"
            }
        }
        var systemImage: String {
            switch self {
            case .catalog: "square.stack.3d.down.right"
            case .installerPlanner: "externaldrive.badge.plus"
            case .multiOS: "macwindow.on.rectangle"
            case .devices: "desktopcomputer"
            case .activity: "waveform.path.ecg"
            case .logs: "doc.text.magnifyingglass"
            case .settings: "gearshape"
            }
        }
    }

    @AppStorage("downloadType") private var downloadType: DownloadType = .firmware
    @AppStorage("includeBetas") private var includeBetas: Bool = false
    @AppStorage("showCompatible") private var showCompatible: Bool = false
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
        var values = firmwares
        if !searchString.isEmpty, workspaceSection == .catalog {
            let value = searchString.lowercased()
            values = values.filter { $0.name.lowercased().contains(value) || $0.version.lowercased().contains(value) || $0.build.lowercased().contains(value) || $0.formattedDate.lowercased().contains(value) }
        }
        if !includeBetas { values = values.filter { !$0.beta } }
        if showCompatible { values = values.filter(\.compatible) }
        return values
    }

    private var filteredInstallers: [Installer] {
        var values = installers
        if !searchString.isEmpty, workspaceSection == .catalog {
            let value = searchString.lowercased()
            values = values.filter { $0.name.lowercased().contains(value) || $0.version.lowercased().contains(value) || $0.build.lowercased().contains(value) || $0.date.lowercased().contains(value) }
        }
        if !includeBetas { values = values.filter { !$0.beta } }
        if showCompatible { values = values.filter(\.compatible) }
        return values
    }

    private var activeTaskCount: Int { taskManager.taskGroups.reduce(0) { $0 + $1.tasks.filter { $0.state == .inProgress }.count } }

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
        .frame(minWidth: 980, idealWidth: 1180, minHeight: 660, idealHeight: 760)
        .toolbar {
            Button { workspaceSection = .activity } label: { Label("Activity", systemImage: "waveform.path.ecg") }
            Button { workspaceSection = .catalog; refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        }
        .searchable(text: $searchString, prompt: workspaceSection == .catalog ? "Search macOS releases" : "Search Apple Catalog")
        .sheet(isPresented: $refreshing) { RefreshView(firmwares: $firmwares, installers: $installers) }
        .onAppear { refresh() }
        .onChange(of: copiedToClipboard) { copied in
            guard copied else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { copiedToClipboard = false } }
        }
        .onChange(of: workspaceSection) { section in if section != .catalog { searchString = "" } }
    }

    private var workspaceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mist Universal").font(.headline)
                Text(workspaceSection.subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Label("Mac hardware only", systemImage: "desktopcomputer").font(.caption).foregroundColor(.secondary)
            if tasksInProgress { Label("Task in progress", systemImage: "arrow.down.circle").font(.caption).foregroundColor(.secondary) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
    }

    private var workspaceSidebar: some View {
        List {
            Section("Library") { workspaceButton(.catalog) }
            Section("Create") { workspaceButton(.installerPlanner); workspaceButton(.multiOS) }
            Section("Devices") {
                workspaceButton(.devices)
                Label("Intel Macs", systemImage: "cpu").font(.caption).foregroundColor(.secondary)
                Label("Apple Silicon Macs", systemImage: "desktopcomputer").font(.caption).foregroundColor(.secondary)
            }
            Section("Activity") { workspaceButton(.activity); workspaceButton(.logs) }
            Section("Settings") { workspaceButton(.settings) }
            Section("Catalog Status") {
                Label("\(firmwares.count) firmwares", systemImage: "shippingbox").font(.caption)
                Label("\(installers.count) installers", systemImage: "macwindow").font(.caption)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 225, idealWidth: 245, maxWidth: 280)
    }

    private func workspaceButton(_ section: WorkspaceSection) -> some View {
        Button { workspaceSection = section } label: {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                    Text(section.subtitle).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                if workspaceSection == section { Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var workspaceDetail: some View {
        switch workspaceSection {
        case .catalog: catalogView
        case .installerPlanner: UniversalInstallerPreviewView(installers: filteredInstallers, embedded: true)
        case .multiOS: MultiOSSetupView(installers: filteredInstallers, embedded: true)
        case .devices: MacDevicesWorkspaceView()
        case .activity: WorkspaceActivityView(taskManager: taskManager)
        case .logs: LogView(logEntries: logManager.logEntries, embedded: true)
        case .settings: SettingsView(sparkleUpdater: sparkleUpdater, embedded: true)
        }
    }

    private var catalogView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Apple Catalog").font(.title2).fontWeight(.semibold)
                    Text("Browse Apple macOS firmware and installers for genuine Intel and Apple Silicon Macs.").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 16)
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
                                        ListRowFirmware(firmware: firmware, savePanel: $savePanel, copiedToClipboard: $copiedToClipboard, tasksInProgress: $tasksInProgress, taskManager: taskManager).tag(firmware)
                                    }
                                case .installer:
                                    ForEach(filteredInstallers(for: releaseName)) { installer in
                                        ListRowInstaller(installer: installer, openPanel: $openPanel, tasksInProgress: $tasksInProgress, taskManager: taskManager).tag(installer)
                                    }
                                }
                            }
                        }
                    }
                    if copiedToClipboard { FloatingAlert(image: "list.bullet.clipboard.fill", message: "Copied to Clipboard") }
                }
            }
            Divider()
            FooterView(includeBetas: $includeBetas, showCompatible: $showCompatible, downloadType: downloadType, firmwares: $firmwares, installers: $installers)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 18) {
            Label(activeTaskCount == 0 ? "Idle" : "\(activeTaskCount) active", systemImage: activeTaskCount == 0 ? "checkmark.circle" : "arrow.down.circle")
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

    private func refresh() { refreshing = true }
    private func releaseNames(for type: DownloadType) -> [String] {
        var names: [String] = []
        let values = type == .firmware ? filteredFirmwares.map(\.name) : filteredInstallers.map(\.name)
        for value in values { let name = value.replacingOccurrences(of: " beta", with: ""); if !names.contains(name) { names.append(name) } }
        return names
    }
    private func filteredFirmwares(for releaseName: String) -> [Firmware] { filteredFirmwares.filter { $0.name.replacingOccurrences(of: " beta", with: "") == releaseName } }
    private func filteredInstallers(for releaseName: String) -> [Installer] { filteredInstallers.filter { $0.name.replacingOccurrences(of: " beta", with: "") == releaseName } }
}

private struct WorkspaceActivityView: View {
    @ObservedObject var taskManager: TaskManager
    private var taskCount: Int { taskManager.taskGroups.reduce(0) { $0 + $1.tasks.count } }
    var body: some View {
        VStack(spacing: 0) {
            HStack { VStack(alignment: .leading, spacing: 4) { Text("Activity").font(.title2).fontWeight(.semibold); Text("Live view of downloads and installer work managed by Mist.").foregroundColor(.secondary) }; Spacer(); Label("\(taskCount) tasks", systemImage: "list.bullet.rectangle").foregroundColor(.secondary) }.padding(20)
            Divider()
            if taskManager.taskGroups.isEmpty {
                VStack(spacing: 12) { Image(systemName: "checkmark.circle").font(.system(size: 34)).foregroundColor(.secondary); Text("No active tasks").font(.headline); Text("Downloads and installer operations will appear here while they run.").font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List { ForEach(taskManager.taskGroups, id: \.section) { group in Section(header: ActivitySectionHeaderView(section: group.section)) { ForEach(group.tasks.indices, id: \.self) { index in ActivityRowView(state: group.tasks[index].state, description: group.tasks[index].currentDescription, degrees: group.tasks[index].state == .inProgress ? 360 : 0).padding(.vertical, 4) } } } }
            }
            Divider(); Label("This pane observes the shared task queue; it does not start or repeat operations.", systemImage: "eye").font(.caption).foregroundColor(.secondary).padding(12).frame(maxWidth: .infinity, alignment: .leading)
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
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            HStack { VStack(alignment: .leading, spacing: 4) { Text("Mac Hardware").font(.title2).fontWeight(.semibold); Text("Review genuine Intel and Apple Silicon Mac hardware, external disks and EFI partitions.").foregroundColor(.secondary) }; Spacer(); Button { Task { await refreshDevices() } } label: { if discovering { ProgressView().controlSize(.small) } else { Label("Refresh", systemImage: "arrow.clockwise") } }.disabled(discovering) }
            GroupBox { HardwareProfileReviewView(profile: $hardwareProfile, reportName: $hardwareReportName, importError: $hardwareImportError).padding(4) } label: { Label("Compatibility Profile", systemImage: "desktopcomputer") }
            GroupBox { VStack(alignment: .leading, spacing: 8) { if disks.isEmpty { Text(discovering ? "Discovering external physical disks…" : "No eligible external physical disks found.").foregroundColor(.secondary) } else { ForEach(disks) { disk in HStack { VStack(alignment: .leading) { Text(disk.name).fontWeight(.medium); Text(disk.identifier).font(.caption).foregroundColor(.secondary) }; Spacer(); Text(ByteCountFormatter.string(fromByteCount: Int64(disk.sizeBytes), countStyle: .file)); Text(disk.busProtocol).font(.caption).foregroundColor(.secondary) }; Divider() } } }.frame(maxWidth: .infinity, alignment: .leading).padding(4) } label: { Label("External Physical Disks", systemImage: "externaldrive") }
            GroupBox { VStack(alignment: .leading, spacing: 8) { if efiPartitions.isEmpty { Text(discovering ? "Inspecting EFI partitions…" : "No EFI partitions discovered on eligible external disks.").foregroundColor(.secondary) } else { ForEach(efiPartitions) { efi in HStack { VStack(alignment: .leading) { Text(efi.name.isEmpty ? "EFI" : efi.name).fontWeight(.medium); Text("\(efi.identifier) • \(efi.parentDiskIdentifier)").font(.caption).foregroundColor(.secondary) }; Spacer(); Text(ByteCountFormatter.string(fromByteCount: Int64(efi.sizeBytes), countStyle: .file)); Text(efi.mountPoint == nil ? "Not mounted" : "Mounted").font(.caption).foregroundColor(.secondary) }; Divider() } } }.frame(maxWidth: .infinity, alignment: .leading).padding(4) } label: { Label("EFI Partitions", systemImage: "internaldrive") }
            if let discoveryError { Label(discoveryError, systemImage: "exclamationmark.triangle").foregroundColor(.orange) }
            Label("Read-only discovery. Mist Universal does not modify disks or EFI partitions from this screen.", systemImage: "lock.shield").font(.caption).foregroundColor(.secondary)
        }.padding(20) }.task { await refreshDevices() }
    }
    @MainActor private func refreshDevices() async {
        discovering = true; discoveryError = nil
        do {
            let discovered = try await DiskutilPhysicalDiskDiscovery().externalPhysicalDisks(); disks = discovered
            var partitions: [EFIPartition] = []
            for disk in discovered { partitions.append(contentsOf: try await DiskutilEFIPartitionDiscovery().efiPartitions(on: disk.identifier)) }
            efiPartitions = partitions
        } catch { disks = []; efiPartitions = []; discoveryError = error.localizedDescription }
        discovering = false
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView(refreshing: .constant(false), tasksInProgress: .constant(false), sparkleUpdater: .shared) }
}
