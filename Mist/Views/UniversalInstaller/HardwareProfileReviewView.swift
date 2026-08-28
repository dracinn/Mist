//
//  HardwareProfileReviewView.swift
//  Mist
//

import SwiftUI
import UniformTypeIdentifiers

struct HardwareProfileReviewView: View {
    @Binding var profile: HardwareProfile?
    @Binding var reportName: String?
    @Binding var importError: String?
    @State private var isImporting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if let profile {
                summary(for: profile)
            } else {
                Text("Import a read-only Apple Mac JSON report to review the target model. An Intel Mac report is required for OCLP previews.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let importError {
                Label(importError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Apple Mac Hardware")
                .font(.headline)
            Spacer()
            if profile != nil {
                Button("Clear") {
                    clearProfile()
                }
            }
            Button(profile == nil ? "Import Report…" : "Replace Report…") {
                importReport()
            }
            .disabled(isImporting)
        }
    }

    private func summary(for profile: HardwareProfile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(profile.modelName ?? profile.modelIdentifier)
                .fontWeight(.medium)
            Text("\(profile.platform.description) · \(profile.modelIdentifier) · \(profile.devices.count) devices")
                .font(.caption)
                .foregroundColor(.secondary)
            if let reportName {
                Text(reportName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(platformNote(for: profile.platform))
                .font(.caption)
        }
    }

    private func platformNote(for platform: AppleHardwarePlatform) -> String {
        switch platform {
        case .intelMac:
            "OCLP model eligibility will be checked against the official supported-model data."
        case .appleSiliconMac:
            "Apple silicon uses Apple's native installer and restore path."
        }
    }

    @MainActor
    private func importReport() {
        let panel: NSOpenPanel = .init()
        panel.title = "Import Apple Mac Hardware Report"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url: URL = panel.url else {
            return
        }

        isImporting = true
        importError = nil

        Task {
            defer {
                isImporting = false
            }

            do {
                profile = try await JSONHardwareProfileImporter().importProfile(from: url)
                reportName = url.lastPathComponent
            } catch {
                profile = nil
                reportName = nil
                importError = error.localizedDescription
            }
        }
    }

    private func clearProfile() {
        profile = nil
        reportName = nil
        importError = nil
    }
}
