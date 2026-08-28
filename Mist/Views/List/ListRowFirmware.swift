//
//  ListRowFirmware.swift
//  Mist
//
//  Created by Nindi Gill on 13/6/2022.
//

import Blessed
import SwiftUI

struct ListRowFirmware: View {
    @AppStorage("firmwareFilename")
    private var firmwareFilename: String = .firmwareFilenameTemplate
    @AppStorage("retries")
    private var retries: Int = 10
    @AppStorage("retryDelay")
    private var retryDelay: Int = 30
    var firmware: Firmware
    @Binding var savePanel: NSSavePanel
    @Binding var copiedToClipboard: Bool
    @Binding var tasksInProgress: Bool
    @ObservedObject var taskManager: TaskManager
    var presentation: CatalogRowPresentation = .standard
    @State private var alertType: FirmwareAlertType = .compatibility
    @State private var showAlert: Bool = false
    @State private var showSavePanel: Bool = false
    @State private var error: Error?
    private let length: CGFloat = 48
    private let spacing: CGFloat = 5
    private let padding: CGFloat = 3
    private var compatibilityMessage: String {
        guard let architecture: Architecture = Hardware.architecture else {
            return "Invalid architecture!"
        }

        return "This macOS Firmware download cannot be used to restore macOS on this \(architecture.description) Mac.\n\nAre you sure you want to continue?"
    }

    private var errorMessage: String {
        if let error: BlessError = error as? BlessError {
            return error.description
        }

        return error?.localizedDescription ?? ""
    }

    var body: some View {
        rowContent
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .compatibility:
                    Alert(
                        title: Text("macOS Firmware not compatible!"),
                        message: Text(compatibilityMessage),
                        primaryButton: .default(Text("Cancel")),
                        secondaryButton: .default(Text("Continue")) { Task { validate() } }
                    )
                case .helperTool:
                    Alert(
                        title: Text("Privileged Helper Tool not installed!"),
                        message: Text("The Mist Privileged Helper Tool is required to perform Administrator tasks when downloading macOS Firmwares."),
                        primaryButton: .default(Text("Install...")) { Task { installPrivilegedHelperTool() } },
                        secondaryButton: .default(Text("Cancel"))
                    )
                case .error:
                    Alert(
                        title: Text("An error has occured!"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .onChange(of: showSavePanel) { boolean in
                if boolean {
                    save()
                }
            }
    }

    @ViewBuilder private var rowContent: some View {
        switch presentation {
        case .standard:
            standardRow
        case .catalogTable:
            catalogTableRow
        }
    }

    private var standardRow: some View {
        HStack {
            ListRowDetail(
                imageName: firmware.imageName,
                beta: firmware.beta,
                version: firmware.version,
                build: firmware.build,
                date: firmware.formattedDate,
                size: firmware.size.bytesString(),
                tooltip: firmware.tooltip
            )
            HStack(spacing: 1) {
                Button {
                    firmware.compatible ? validate() : showCompatibilityWarning()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .padding(.vertical, 1.5)
                }
                .help("Download macOS Firmware")
                .buttonStyle(.mistAction)
                .disabled(tasksInProgress)
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: "list.bullet.clipboard")
                }
                .help("Copy macOS Firmware URL to Clipboard")
                .buttonStyle(.mistAction)
            }
            .clipShape(Capsule())
        }
    }

    private var catalogTableRow: some View {
        // swiftlint:disable:next closure_body_length
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                ScaledImage(name: firmware.imageName, length: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(firmware.name) \(firmware.version)")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(firmware.build)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Restore IPSW")
                .frame(width: 90, alignment: .leading)
            Text(firmware.formattedDate)
                .frame(width: 92, alignment: .leading)
            Text(firmware.size.bytesString())
                .frame(width: 72, alignment: .trailing)
            HStack(spacing: 6) {
                Button {
                    firmware.compatible ? validate() : showCompatibilityWarning()
                } label: {
                    Image(systemName: "icloud.and.arrow.down")
                }
                .help("Download macOS Firmware")
                .disabled(tasksInProgress)
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: "link")
                }
                .help("Copy macOS Firmware URL")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 118)
        }
        .font(.callout)
        .padding(.vertical, 5)
    }

    private func copyToClipboard() {
        NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(firmware.url, forType: .string)
        withAnimation(.easeIn) {
            copiedToClipboard = true
        }
    }

    private func save() {
        showSavePanel = false
        savePanel.title = "Download Firmware"
        savePanel.nameFieldStringValue = firmwareFilename.stringWithSubstitutions(name: firmware.name, version: firmware.version, build: firmware.build)
        savePanel.canCreateDirectories = true
        savePanel.canSelectHiddenExtension = true
        savePanel.isExtensionHidden = false

        _ = Task {
            let response: NSApplication.ModalResponse = savePanel.runModal()

            guard response == .OK else {
                return
            }

            taskManager.taskGroups = try TaskManager.taskGroups(for: firmware, destination: savePanel.url, retries: retries, delay: retryDelay)
            tasksInProgress = true
            ActivityWindowPresenter.present(
                downloadType: .firmware,
                imageName: firmware.imageName,
                name: firmware.name,
                version: firmware.version,
                build: firmware.build,
                beta: firmware.beta,
                destinationURL: savePanel.url,
                taskManager: taskManager
            ) {
                tasksInProgress = false
            }
        }
    }

    private func showCompatibilityWarning() {
        alertType = .compatibility
        showAlert = true
    }

    private func validate() {
        guard PrivilegedHelperTool.isInstalled() else {
            alertType = .helperTool
            showAlert = true
            return
        }

        showSavePanel = true
    }

    private func installPrivilegedHelperTool() {
        do {
            try PrivilegedHelperManager.shared.authorizeAndBless()
        } catch {
            self.error = error
            alertType = .error
            showAlert = true
        }
    }
}

struct ListRowFirmware_Previews: PreviewProvider {
    static var previews: some View {
        ListRowFirmware(firmware: .example, savePanel: .constant(NSSavePanel()), copiedToClipboard: .constant(false), tasksInProgress: .constant(false), taskManager: .shared)
    }
}
