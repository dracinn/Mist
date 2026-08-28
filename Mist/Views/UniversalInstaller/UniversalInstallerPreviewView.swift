//
//  UniversalInstallerPreviewView.swift
//  Mist
//

import SwiftUI

struct UniversalInstallerPreviewView: View {
    @Environment(\.dismiss)
    private var dismiss: DismissAction
    var installers: [Installer]
    @State private var selectedInstallerIDs: Set<String> = []
    @State private var bootStrategies: [String: BootStrategy] = [:]
    @State private var diskSizeGiB: Int = 64
    @State private var physicalDisks: [PhysicalDisk] = []
    @State private var selectedDiskIdentifier: String = ""
    @State private var diskDiscoveryError: String?
    @State private var isDiscoveringDisks: Bool = false
    private let diskSizesGiB: [Int] = [32, 64, 128, 256, 512]
    private let defaultBootStrategy: BootStrategy

    private var selectedInstallers: [Installer] {
        installers.filter { selectedInstallerIDs.contains($0.id) }
    }

    private var selections: [MacOSInstallerSelection] {
        selectedInstallers.map { installer in
            MacOSInstallerSelection(
                installer: installer,
                bootStrategy: bootStrategies[installer.id] ?? defaultBootStrategy
            )
        }
    }

    private var selectedDisk: PhysicalDisk? {
        physicalDisks.first { $0.identifier == selectedDiskIdentifier }
    }

    private var previewDiskIdentifier: String {
        selectedDisk?.identifier ?? "Capacity Preview"
    }

    private var previewDiskSizeBytes: UInt64 {
        selectedDisk?.sizeBytes ?? UInt64(diskSizeGiB) * 1_024 * 1_024 * 1_024
    }

    private var previewResult: (preview: InstallerPlanPreview?, error: String?) {
        guard !selectedInstallers.isEmpty else {
            return (nil, "Select at least one macOS installer.")
        }

        do {
            let preview: InstallerPlanPreview = try MacOSInstallerPreviewBuilder().preview(
                selections: selections,
                diskIdentifier: previewDiskIdentifier,
                diskSizeBytes: previewDiskSizeBytes
            )
            return (preview, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                installerSelection
                planConfiguration
            }
            Divider()
            safetyFooter
        }
        .frame(width: 760, height: 560)
        .task {
            await refreshPhysicalDisks()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Multi-macOS Drive Preview")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose multiple Apple catalog installers and inspect the proposed layout.")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var installerSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("macOS Installers")
                .font(.headline)
            List(installers) { installer in
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: selectionBinding(for: installer)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(installer.name) \(installer.version)")
                            Text("Build \(installer.build) · \(installer.size.bytesString())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)

                    if selectedInstallerIDs.contains(installer.id) {
                        Picker("Boot strategy", selection: bootStrategyBinding(for: installer)) {
                            ForEach(BootStrategy.allCases, id: \.self) { strategy in
                                Text(strategy.description)
                                    .tag(strategy)
                            }
                        }
                        .labelsHidden()
                        .padding(.leading, 20)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 340)
    }

    private var planConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            diskSelection

            Divider()
            previewContent
            Spacer()
        }
        .padding()
        .frame(minWidth: 360)
    }

    private var diskSelection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if physicalDisks.isEmpty {
                    Picker("Preview capacity", selection: $diskSizeGiB) {
                        ForEach(diskSizesGiB, id: \.self) { size in
                            Text("\(size) GiB")
                                .tag(size)
                        }
                    }
                } else {
                    Picker("External disk", selection: $selectedDiskIdentifier) {
                        ForEach(physicalDisks) { disk in
                            Text("\(disk.name) (\(disk.identifier), \(disk.busProtocol)) — \(disk.sizeBytes.bytesString())")
                                .tag(disk.identifier)
                        }
                    }
                }
                refreshDisksButton
            }

            if let diskDiscoveryError: String = diskDiscoveryError {
                Text(diskDiscoveryError)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder private var previewContent: some View {
        let result: (preview: InstallerPlanPreview?, error: String?) = previewResult

        if let preview: InstallerPlanPreview = result.preview {
            Text("Proposed Partitions")
                .font(.headline)

            ForEach(Array(preview.partitions.enumerated()), id: \.offset) { _, partition in
                HStack {
                    Image(systemName: partition.targetID == nil ? "externaldrive.fill" : "macos")
                    Text(partition.name)
                        .lineLimit(1)
                    Spacer()
                    Text(partition.sizeBytes.bytesString())
                        .foregroundColor(.secondary)
                }
            }

            Divider()
            sizeRow("Reserved", bytes: preview.reserveBytes)
            sizeRow("Remaining", bytes: preview.remainingBytes)
        } else if let error: String = result.error {
            Label(error, systemImage: "info.circle")
                .foregroundColor(.secondary)
        }
    }

    private var safetyFooter: some View {
        Label(
            "Preview only — no disk, EFI, or OCLP changes are performed.",
            systemImage: "checkmark.shield"
        )
        .foregroundColor(.secondary)
        .padding()
    }

    private var refreshDisksButton: some View {
        Button {
            Task {
                await refreshPhysicalDisks()
            }
        } label: {
            if isDiscoveringDisks {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(isDiscoveringDisks)
        .help("Refresh external physical disks")
    }

    init(installers: [Installer]) {
        self.installers = installers
        defaultBootStrategy = Hardware.architecture == .appleSilicon ? .appleSilicon : .nativeMacIntel
    }
}

private extension UniversalInstallerPreviewView {
    /// Binds an installer row to the current multi-selection.
    ///
    /// - Parameter installer: The catalog installer represented by the row.
    ///
    /// - Returns: A binding that adds or removes the installer selection.
    func selectionBinding(for installer: Installer) -> Binding<Bool> {
        Binding(
            get: {
                selectedInstallerIDs.contains(installer.id)
            },
            set: { selected in
                if selected {
                    selectedInstallerIDs.insert(installer.id)
                    bootStrategies[installer.id] = bootStrategies[installer.id] ?? defaultBootStrategy
                } else {
                    selectedInstallerIDs.remove(installer.id)
                    bootStrategies.removeValue(forKey: installer.id)
                }
            }
        )
    }

    /// Binds an installer row to its independently selected boot strategy.
    ///
    /// - Parameter installer: The selected catalog installer.
    ///
    /// - Returns: A binding to the installer's boot strategy.
    func bootStrategyBinding(for installer: Installer) -> Binding<BootStrategy> {
        Binding(
            get: {
                bootStrategies[installer.id] ?? defaultBootStrategy
            },
            set: { strategy in
                bootStrategies[installer.id] = strategy
            }
        )
    }

    /// Displays a labeled byte count in the plan summary.
    ///
    /// - Parameters:
    ///   - label: The summary row label.
    ///   - bytes: The byte count to format.
    ///
    /// - Returns: A summary row containing the label and formatted byte count.
    func sizeRow(_ label: String, bytes: UInt64) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(bytes.bytesString())
                .foregroundColor(.secondary)
        }
    }

    /// Refreshes the read-only list of eligible external physical disks.
    @MainActor
    func refreshPhysicalDisks() async {
        isDiscoveringDisks = true
        defer {
            isDiscoveringDisks = false
        }

        do {
            let disks: [PhysicalDisk] = try await DiskutilPhysicalDiskDiscovery().externalPhysicalDisks()
            physicalDisks = disks
            diskDiscoveryError = nil

            if !disks.contains(where: { $0.identifier == selectedDiskIdentifier }) {
                selectedDiskIdentifier = disks.first?.identifier ?? ""
            }
        } catch {
            physicalDisks = []
            selectedDiskIdentifier = ""
            diskDiscoveryError = error.localizedDescription
        }
    }
}

struct UniversalInstallerPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        UniversalInstallerPreviewView(installers: [.example])
    }
}
