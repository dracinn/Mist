//
//  MacDevicesWorkspaceView.swift
//  Mist
//

import SwiftUI

struct MacDevicesWorkspaceView: View {
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
                header
                compatibilityProfile
                externalDisks
                efiPartitionList
                if let discoveryError {
                    Label(discoveryError, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
                Label(
                    "Read-only discovery. Mist Universal does not modify disks or EFI partitions from this screen.",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(20)
        }
        .task {
            await refreshDevices()
        }
    }

    private var header: some View {
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
    }

    private var compatibilityProfile: some View {
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
    }

    private var externalDisks: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if disks.isEmpty {
                    Text(discovering ? "Discovering external physical disks…" : "No eligible external physical disks found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(disks) { disk in
                        diskRow(disk)
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Label("External Physical Disks", systemImage: "externaldrive")
        }
    }

    private var efiPartitionList: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if efiPartitions.isEmpty {
                    Text(discovering ? "Inspecting EFI partitions…" : "No EFI partitions discovered on eligible external disks.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(efiPartitions) { partition in
                        efiRow(partition)
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Label("EFI Partitions", systemImage: "internaldrive")
        }
    }

    private func diskRow(_ disk: PhysicalDisk) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(disk.name)
                    .fontWeight(.medium)
                Text(disk.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: Int64(disk.sizeBytes), countStyle: .file))
            Text(disk.busProtocol)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func efiRow(_ partition: EFIPartition) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(partition.name.isEmpty ? "EFI" : partition.name)
                    .fontWeight(.medium)
                Text("\(partition.identifier) • \(partition.parentDiskIdentifier)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: Int64(partition.sizeBytes), countStyle: .file))
            Text(partition.mountPoint == nil ? "Not mounted" : "Mounted")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @MainActor
    private func refreshDevices() async {
        discovering = true
        discoveryError = nil
        defer { discovering = false }

        let discovered: [PhysicalDisk]

        do {
            discovered = try await DiskutilPhysicalDiskDiscovery().externalPhysicalDisks()
        } catch {
            disks = []
            efiPartitions = []
            discoveryError = error.localizedDescription
            return
        }

        disks = discovered
        var partitions: [EFIPartition] = []
        var inspectionFailures: [String] = []

        for disk in discovered {
            do {
                let diskPartitions: [EFIPartition] = try await DiskutilEFIPartitionDiscovery()
                    .efiPartitions(on: disk.identifier)
                partitions.append(contentsOf: diskPartitions)
            } catch {
                inspectionFailures.append("\(disk.identifier): \(error.localizedDescription)")
            }
        }

        efiPartitions = partitions
        if !inspectionFailures.isEmpty {
            discoveryError = "Some EFI partitions could not be inspected. \(inspectionFailures.joined(separator: " "))"
        }
    }
}
