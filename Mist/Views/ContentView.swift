//
//  ContentView.swift
//  Mist
//
//  Created by Nindi Gill on 13/6/2022.
//

import SwiftUI

// swiftlint:disable file_length

private enum CatalogArchitectureFilter: String, CaseIterable, Identifiable {
    case all = "All Architectures"
    case intel = "Intel — x86/x64"
    case appleSilicon = "Apple Silicon — aarch64"

    var id: String {
        rawValue
    }
}

private enum CatalogOSFilter: String, CaseIterable, Identifiable {
    case all = "All Operating Systems"
    case macOS
    case windows = "Windows"
    case linux = "Linux"
    case asahi = "Asahi Linux"

    var id: String {
        rawValue
    }
}

// swiftlint:disable:next type_body_length
struct ContentView: View {
    @Environment(\.openURL)
    private var openURL: OpenURLAction
    @AppStorage("downloadType")
    private var downloadType: DownloadType = .installer
    @Binding var refreshing: Bool
    @Binding var tasksInProgress: Bool
    @ObservedObject var sparkleUpdater: SparkleUpdater
    @State private var workspaceSection: WorkspaceSection = .catalog
    @State private var firmwares: [Firmware] = []
    @State private var installers: [Installer] = []
    @State private var selectedFirmware: Firmware?
    @State private var selectedInstaller: Installer?
    @State private var selectedResource: OperatingSystemResource?
    @State private var architectureFilter: CatalogArchitectureFilter = .all
    @State private var osFilter: CatalogOSFilter = .all
    @State private var searchString: String = ""
    @State private var openPanel: NSOpenPanel = .init()
    @State private var savePanel: NSSavePanel = .init()
    @State private var copiedToClipboard: Bool = false
    @State private var lastRefreshDate: Date = .init()
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
            HStack(spacing: 0) {
                workspaceSidebar
                Divider()
                workspaceDetail
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 1_180, idealWidth: 1_440, minHeight: 720, idealHeight: 860)
        .background(workspaceBackground)
        .preferredColorScheme(.dark)
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
        .onChange(of: installers) { values in
            if selectedInstaller == nil {
                selectedInstaller = values.first
            }
        }
        .onChange(of: firmwares) { values in
            if selectedFirmware == nil {
                selectedFirmware = values.first
            }
        }
    }

    private var workspaceBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.055, green: 0.075, blue: 0.12),
                Color(red: 0.035, green: 0.05, blue: 0.085)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var workspaceHeader: some View {
        ZStack {
            Text("Mist Universal")
                .font(.headline)
                .fontWeight(.semibold)

            HStack(spacing: 18) {
                Spacer()
                Label("Mac hardware only", systemImage: "info.circle")
                    .foregroundColor(.secondary)
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
            .buttonStyle(.plain)
            .font(.callout)
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(.ultraThinMaterial)
    }

    private var workspaceSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandBlock
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sidebarGroup("LIBRARY", sections: [.catalog])
                    sidebarGroup("CREATE", sections: [.installerPlanner, .multiOS])
                    sidebarGroup("DEVICES", sections: [.devices])
                    sidebarGroup("ACTIVITY", sections: [.activity, .logs])
                    sidebarGroup("SETTINGS", sections: [.settings])
                }
                .padding(.horizontal, 12)
            }
            catalogStatusCard
        }
        .frame(width: 230)
        .background(Color.black.opacity(0.12))
    }

    private var brandBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 32))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.accentColor)
                .frame(width: 42, height: 48)
            VStack(alignment: .leading, spacing: 1) {
                Text("Mist")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Universal")
                    .font(.headline)
                Text("macOS firmware\nand installers")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }

    private var catalogStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATALOG STATUS")
                .font(.caption2)
                .foregroundColor(.secondary)
            Label("\(firmwares.count)  Firmware available", systemImage: "shippingbox")
            Label("\(installers.count)  Installers available", systemImage: "macwindow")
            Divider()
            Label(lastRefreshDate.formatted(date: .abbreviated, time: .shortened), systemImage: "circle.fill")
                .font(.caption2)
                .foregroundColor(.secondary)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.green, .secondary)
        }
        .font(.caption)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.06))
        }
        .padding(12)
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

    private func sidebarGroup(_ title: String, sections: [WorkspaceSection]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            ForEach(sections) { section in
                workspaceButton(section)
            }
        }
    }

    private func workspaceButton(_ section: WorkspaceSection) -> some View {
        Button {
            workspaceSection = section
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 16))
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(section.subtitle)
                        .font(.caption2)
                        .foregroundColor(workspaceSection == section ? .white.opacity(0.78) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(workspaceSection == section ? Color.accentColor.opacity(0.72) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func refresh() {
        lastRefreshDate = Date()
        refreshing = true
    }
}

// swiftlint:disable type_contents_order
private extension ContentView {
    /// The mockup-inspired Apple catalog workspace.
    var catalogView: some View {
        VStack(alignment: .leading, spacing: 10) {
            catalogHeader
            catalogToolbar
            catalogResults
        }
        .padding(18)
        .background(Color.white.opacity(0.025))
    }

    /// The Apple catalog heading.
    var catalogHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Universal Catalog")
                .font(.title2)
                .fontWeight(.bold)
            Text("Browse macOS, Windows, Linux, and Asahi resources for genuine Intel and Apple Silicon Macs.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }

    /// Catalog type and search controls aligned on one row.
    var catalogToolbar: some View {
        HStack(spacing: 12) {
            Picker("Download Type", selection: $downloadType) {
                Text("Installers").tag(DownloadType.installer)
                Text("Firmware").tag(DownloadType.firmware)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .onChange(of: downloadType) { _ in
                selectedResource = nil
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter catalog…", text: $searchString)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 11)
            .frame(width: 235, height: 32)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08))
            }
            catalogFilterMenu
        }
    }

    /// Architecture and operating-system filters.
    var catalogFilterMenu: some View {
        Menu {
            Menu("Architecture") {
                ForEach(CatalogArchitectureFilter.allCases) { option in
                    Button {
                        architectureFilter = option
                        selectedResource = nil
                    } label: {
                        filterLabel(option.rawValue, selected: architectureFilter == option)
                    }
                }
            }
            Menu("Operating System") {
                ForEach(CatalogOSFilter.allCases) { option in
                    Button {
                        osFilter = option
                        selectedResource = nil
                    } label: {
                        filterLabel(option.rawValue, selected: osFilter == option)
                    }
                }
            }
            Divider()
            Button("Clear Filters") {
                architectureFilter = .all
                osFilter = .all
                selectedResource = nil
            }
            .disabled(architectureFilter == .all && osFilter == .all)
        } label: {
            Image(systemName: filtersAreActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .frame(width: 30, height: 30)
        }
        .menuStyle(.borderlessButton)
        .help("Filter by architecture and operating system")
    }

    /// A checked label used in the filter menu.
    func filterLabel(_ title: String, selected: Bool) -> some View {
        Label(title, systemImage: selected ? "checkmark" : "circle")
    }

    /// The catalog table and selected-item inspector.
    @ViewBuilder var catalogResults: some View {
        if
            downloadType == .firmware && catalogFirmwares.isEmpty
            || downloadType == .installer && catalogInstallers.isEmpty && filteredExternalResources.isEmpty {
            EmptyCollectionView("No macOS \(downloadType.description)s found!\n\nಥ_ಥ")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    catalogTableHeader
                    catalogList
                    catalogCountFooter
                }
                .background(Color.black.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.08))
                }
                catalogInspector
            }
        }
    }

    /// Column labels for the catalog table.
    var catalogTableHeader: some View {
        HStack(spacing: 12) {
            Text("Operating System")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Type")
                .frame(width: 90, alignment: .leading)
            Text("Release Date")
                .frame(width: 92, alignment: .leading)
            Text("Size")
                .frame(width: 72, alignment: .trailing)
            Text("Actions")
                .frame(width: 118, alignment: .center)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.white.opacity(0.025))
    }

    /// Selectable installer or firmware rows.
    @ViewBuilder var catalogList: some View {
        switch downloadType {
        case .firmware:
            List {
                Section("Apple Silicon — aarch64") {
                    ForEach(catalogFirmwares) { firmware in
                        ListRowFirmware(
                            firmware: firmware,
                            savePanel: $savePanel,
                            copiedToClipboard: $copiedToClipboard,
                            tasksInProgress: $tasksInProgress,
                            taskManager: taskManager,
                            presentation: .catalogTable
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFirmware = firmware
                            selectedResource = nil
                        }
                    }
                }
            }
        case .installer:
            List {
                Section("Apple Silicon — aarch64") {
                    ForEach(catalogInstallers.filter(\.bigSurOrNewer)) { installer in
                        installerCatalogRow(installer)
                    }
                    if filteredExternalResources.contains(OperatingSystemResource.fedoraAsahi) {
                        catalogResourceRow(OperatingSystemResource.fedoraAsahi)
                    }
                }
                Section("Intel — x86/x64") {
                    ForEach(catalogInstallers.filter(\.supportsIntelMacs)) { installer in
                        installerCatalogRow(installer)
                    }
                    ForEach(filteredIntelResources) { resource in
                        catalogResourceRow(resource)
                    }
                }
            }
        }
    }

    /// A selectable macOS installer row.
    func installerCatalogRow(_ installer: Installer) -> some View {
        ListRowInstaller(
            installer: installer,
            openPanel: $openPanel,
            tasksInProgress: $tasksInProgress,
            taskManager: taskManager,
            presentation: .catalogTable
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedInstaller = installer
            selectedResource = nil
        }
    }

    // swiftlint:disable function_body_length
    /// A Windows, Linux, or Asahi catalog row with safe external actions.
    func catalogResourceRow(_ resource: OperatingSystemResource) -> some View {
        // swiftlint:disable:next closure_body_length
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                resourceIcon(resource)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.name)
                        .font(.callout.weight(.medium))
                    Text(resource.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .help(resource.summary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(resourceKind(resource))
                .frame(width: 90, alignment: .leading)
            Text("Official site")
                .foregroundColor(.secondary)
                .frame(width: 92, alignment: .leading)
            Text("—")
                .foregroundColor(.secondary)
                .frame(width: 72, alignment: .trailing)
            HStack(spacing: 6) {
                Button {
                    open(resource.downloadPage)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .help("Open official download")
                Button {
                    open(resource.setupGuide)
                } label: {
                    Image(systemName: "book")
                }
                .help("Open setup guide")
                Button {
                    copy(resource.downloadPage)
                } label: {
                    Image(systemName: "link")
                }
                .help("Copy official download link")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 118)
        }
        .font(.callout)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedResource = resource
        }
    }

    // swiftlint:enable function_body_length

    /// Compact OS-specific artwork for an external catalog resource.
    func resourceIcon(_ resource: OperatingSystemResource, length: CGFloat = 38) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.08))
            Image(resource.iconAssetName)
                .resizable()
                .scaledToFit()
                .padding(length * 0.12)
        }
        .frame(width: length, height: length)
        .accessibilityLabel(resource.name)
    }

    /// Result count beneath the catalog rows.
    var catalogCountFooter: some View {
        HStack {
            Text("Showing \(visibleCatalogCount) \(downloadType.description.lowercased())s")
            Spacer()
            Text("\(visibleCatalogCount) total")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color.white.opacity(0.025))
    }

    /// Inspector for the selected installer or firmware.
    var catalogInspector: some View {
        Group {
            if let resource = selectedResource {
                resourceInspector(resource)
            } else {
                switch downloadType {
                case .installer:
                    if let installer = selectedInstaller ?? catalogInstallers.first {
                        installerInspector(installer)
                    }
                case .firmware:
                    if let firmware = selectedFirmware ?? catalogFirmwares.first {
                        firmwareInspector(firmware)
                    }
                }
            }
        }
        .frame(width: 265)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.09))
        }
    }

    /// Inspector contents for a macOS installer.
    ///
    /// - Parameter installer: The selected installer.
    ///
    /// - Returns: A detailed installer summary and actions.
    func installerInspector(_ installer: Installer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                catalogInspectorTitle(
                    imageName: installer.imageName,
                    name: "\(installer.name) \(installer.version)",
                    build: installer.build
                )
                inspectorMetadata(type: "Full Installer", size: installer.size.bytesString(), date: installer.date)
                Divider()
                compatibilitySection(
                    supportsAppleSilicon: installer.bigSurOrNewer,
                    supportsIntel: installer.supportsIntelMacs
                )
                Divider()
                Text("Description")
                    .fontWeight(.semibold)
                Text("The \(installer.name) installer for compatible Mac computers. Use it to upgrade macOS or create bootable install media.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
    }

    /// Inspector contents for macOS firmware.
    ///
    /// - Parameter firmware: The selected firmware.
    ///
    /// - Returns: A detailed firmware summary and actions.
    func firmwareInspector(_ firmware: Firmware) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                catalogInspectorTitle(
                    imageName: firmware.imageName,
                    name: "\(firmware.name) \(firmware.version)",
                    build: firmware.build
                )
                inspectorMetadata(type: "Restore Firmware", size: firmware.size.bytesString(), date: firmware.formattedDate)
                Divider()
                compatibilitySection(supportsAppleSilicon: true, supportsIntel: false)
                Divider()
                Text("Description")
                    .fontWeight(.semibold)
                Text("Apple restore firmware for compatible Apple Silicon Mac computers.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
    }

    /// Inspector contents for an external operating-system resource.
    func resourceInspector(_ resource: OperatingSystemResource) -> some View {
        // swiftlint:disable:next closure_body_length
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    resourceIcon(resource, length: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(resource.name)
                            .font(.headline)
                        Text(resourceKind(resource))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compatibility")
                        .fontWeight(.semibold)
                    Label(resource.architecture, systemImage: "checkmark")
                        .foregroundColor(.green)
                }
                .font(.callout)
                Divider()
                Text("Description")
                    .fontWeight(.semibold)
                Text(resource.summary.isEmpty ? "Official distribution download for supported Mac hardware." : resource.summary)
                    .font(.callout)
                    .foregroundColor(.secondary)
                if !resource.supportNote.isEmpty {
                    Text(resource.supportNote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
    }

    /// Title block used by both catalog inspectors.
    func catalogInspectorTitle(imageName: String, name: String, build: String) -> some View {
        HStack(spacing: 12) {
            ScaledImage(name: imageName, length: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.headline)
                Text(build)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Metadata shown beneath an inspector title.
    func inspectorMetadata(type: String, size: String, date: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(type)
            Text(size)
            Text("Released \(date)")
        }
        .font(.callout)
        .foregroundColor(.secondary)
    }

    /// Compatibility labels for a selected catalog item.
    func compatibilitySection(supportsAppleSilicon: Bool, supportsIntel: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compatibility")
                .fontWeight(.semibold)
            if supportsAppleSilicon {
                Label("Apple Silicon Macs", systemImage: "checkmark")
                    .foregroundColor(.green)
            }
            if supportsIntel {
                Label("Intel Macs", systemImage: "checkmark")
                    .foregroundColor(.green)
            }
            if !supportsAppleSilicon, !supportsIntel {
                Label("\(Hardware.architecture?.description ?? "Compatible") Macs", systemImage: "checkmark")
                    .foregroundColor(.green)
            }
        }
        .font(.callout)
    }

    /// Number of results visible in the current catalog tab.
    var visibleCatalogCount: Int {
        if downloadType == .firmware {
            return catalogFirmwares.count
        }
        return catalogInstallers.count + filteredExternalResources.count
    }

    /// Intel Windows and Linux resources matching the current search.
    var filteredIntelResources: [OperatingSystemResource] {
        filteredExternalResources.filter { $0 != OperatingSystemResource.fedoraAsahi }
    }

    /// macOS installers matching the architecture and OS filters.
    var catalogInstallers: [Installer] {
        guard osFilter == .all || osFilter == .macOS else {
            return []
        }
        return filteredInstallers.filter { installer in
            switch architectureFilter {
            case .all:
                true
            case .intel:
                installer.supportsIntelMacs
            case .appleSilicon:
                installer.bigSurOrNewer
            }
        }
    }

    /// Firmware matching the architecture and OS filters.
    var catalogFirmwares: [Firmware] {
        guard
            osFilter == .all || osFilter == .macOS,
            architectureFilter != .intel
        else {
            return []
        }
        return filteredFirmwares
    }

    /// Windows, Linux, and Asahi resources matching all active filters.
    var filteredExternalResources: [OperatingSystemResource] {
        (OperatingSystemResource.intelMacOptions + [OperatingSystemResource.fedoraAsahi]).filter { resource in
            resourceMatchesSearch(resource)
                && resourceMatchesArchitecture(resource)
                && resourceMatchesOS(resource)
        }
    }

    /// Whether an external resource matches the current catalog search.
    func resourceMatchesSearch(_ resource: OperatingSystemResource) -> Bool {
        searchString.isEmpty
            || resource.name.localizedCaseInsensitiveContains(searchString)
            || resource.architecture.localizedCaseInsensitiveContains(searchString)
    }

    /// Whether an external resource matches the architecture filter.
    func resourceMatchesArchitecture(_ resource: OperatingSystemResource) -> Bool {
        switch architectureFilter {
        case .all:
            true
        case .intel:
            resource != OperatingSystemResource.fedoraAsahi
        case .appleSilicon:
            resource == OperatingSystemResource.fedoraAsahi
        }
    }

    /// Whether an external resource matches the operating-system filter.
    func resourceMatchesOS(_ resource: OperatingSystemResource) -> Bool {
        switch osFilter {
        case .all:
            true
        case .macOS:
            false
        case .windows:
            OperatingSystemResource.intelWindowsOptions.contains(resource)
        case .linux:
            OperatingSystemResource.intelLinuxOptions.contains(resource)
        case .asahi:
            resource == OperatingSystemResource.fedoraAsahi
        }
    }

    /// Whether either catalog filter is active.
    var filtersAreActive: Bool {
        architectureFilter != .all || osFilter != .all
    }

    /// Human-readable category for an external operating-system resource.
    func resourceKind(_ resource: OperatingSystemResource) -> String {
        if resource == OperatingSystemResource.fedoraAsahi {
            return "Asahi Linux"
        }
        return OperatingSystemResource.intelWindowsOptions.contains(resource) ? "Windows" : "Linux"
    }

    /// Opens a validated external resource URL.
    func open(_ value: String) {
        guard let url = URL(string: value), url.scheme == "https" else {
            return
        }
        openURL(url)
    }

    /// Copies an official resource URL.
    func copy(_ value: String) {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(value, forType: .string)
        copiedToClipboard = true
    }

    /// Persistent workspace status matching the mockup footer.
    var statusBar: some View {
        HStack(spacing: 20) {
            Label(
                activeTaskCount == 0 ? "Ready" : "\(activeTaskCount) tasks running",
                systemImage: "circle.fill"
            )
            .foregroundColor(activeTaskCount == 0 ? .green : .orange)
            Label("Downloads: \(activeTaskCount) active", systemImage: "arrow.down.to.line")
            Spacer()
            Text("Mist Universal \(appVersion)")
            Image(systemName: "checkmark.circle")
                .foregroundColor(.green)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 34)
        .background(.ultraThinMaterial)
    }

    /// The visible application version.
    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    }
}

// swiftlint:enable type_contents_order

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            refreshing: .constant(false),
            tasksInProgress: .constant(false),
            sparkleUpdater: .init()
        )
    }
}
