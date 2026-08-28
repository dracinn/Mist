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

        var id: String { rawValue }

        var title: String {
            switch self {
            case .catalog:
                "Apple Catalog"
            case .installerPlanner:
                "Installer Planner"
            case .multiOS:
                "Multi-OS Setup"
            }
        }

        var subtitle: String {
            switch self {
            case .catalog:
                "macOS firmware and installers"
            case .installerPlanner:
                "Intel & Apple Silicon Macs"
            case .multiOS:
                "Windows, Linux, OCLP & Asahi"
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
    @State private var workspaceSection: WorkspaceSection = .catalog
    @State private var firmwares: [Firmware] = []
    @State private var installers: [Installer] = []
    @State private var searchString: String = ""
    @State private var openPanel: NSOpenPanel = .init()
    @State private var savePanel: NSSavePanel = .init()
    @State private var copiedToClipboard: Bool = false
    @StateObject private var taskManager: TaskManager = .shared

    private var filteredFirmwares: [Firmware] {
        var filteredFirmwares: [Firmware] = firmwares

        if !searchString.isEmpty {
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

        if !searchString.isEmpty {
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

    private let width: CGFloat = 1080
    private let height: CGFloat = 720

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            Divider()
            HSplitView {
                workspaceSidebar
                workspaceDetail
            }
        }
        .frame(minWidth: 900, idealWidth: width, minHeight: 620, idealHeight: height)
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
                showLog()
            } label: {
                Label("Show Log", systemImage: "text.and.command.macwindow")
                    .foregroundColor(.accentColor)
            }
            .help("Show Mist Log")
        }
        .searchable(text: $searchString)
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

            Section("Supported Hardware") {
                Label("Intel Macs", systemImage: "cpu")
                    .font(.caption)
                Label("Apple Silicon Macs", systemImage: "desktopcomputer")
                    .font(.caption)
            }

            Section("Catalog Status") {
                Label("\(firmwares.count) firmwares", systemImage: "shippingbox")
                    .font(.caption)
                Label("\(installers.count) installers", systemImage: "macwindow")
                    .font(.caption)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220, idealWidth: 235, maxWidth: 270)
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

    private func showLog() {
        guard let url = URL(string: .logURL) else {
            return
        }

        openURL(url)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(refreshing: .constant(false), tasksInProgress: .constant(false))
    }
}
