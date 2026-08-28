//
//  MultiOSSetupView.swift
//  Mist
//

import SwiftUI

struct MultiOSSetupView: View {
    @Environment(\.dismiss)
    private var dismiss: DismissAction
    @Environment(\.openURL)
    private var openURL: OpenURLAction
    var installers: [Installer]
    var embedded: Bool = false
    @State private var selection: MultiOSSection = .macOS
    @State private var showMacOSPlanner: Bool = false
    @State private var copiedAsahiCommand: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if !embedded {
                header
                Divider()
            }

            if embedded {
                embeddedNavigation
                Divider()
                detail
            } else {
                HSplitView {
                    sidebar
                    detail
                }
            }

            Divider()
            safetyFooter
        }
        .frame(
            minWidth: embedded ? 680 : 900,
            idealWidth: 900,
            minHeight: embedded ? 540 : 660,
            idealHeight: 660
        )
        .sheet(isPresented: $showMacOSPlanner) {
            UniversalInstallerPreviewView(installers: installers)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Multi-OS Setup")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Official downloads and safe planning for genuine Intel and Apple Silicon Macs.")
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

    private var embeddedNavigation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Multi-OS Setup")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Mac hardware only — choose an Intel Mac or Apple Silicon workflow.")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Picker("Platform", selection: $selection) {
                ForEach(MultiOSSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(20)
    }

    private var sidebar: some View {
        List {
            Section("Mac Platforms") {
                ForEach(MultiOSSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        HStack {
                            Label(section.title, systemImage: section.systemImage)
                            Spacer()
                            if selection == section {
                                Image(systemName: "checkmark")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 210, idealWidth: 230, maxWidth: 260)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch selection {
                case .macOS:
                    macOSSection
                case .intel:
                    intelSection
                case .appleSilicon:
                    appleSiliconSection
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 540)
    }

    private var macOSSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                "macOS & OpenCore Legacy Patcher",
                subtitle: "Native macOS installers for Apple Macs, plus OCLP planning for eligible Intel Macs."
            )

            nativeMacOSCard
            oclpCard

            if installers.isEmpty {
                Label("Refresh the macOS installer catalog before opening the planner.", systemImage: "info.circle")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var nativeMacOSCard: some View {
        setupCard(.nativeMacOS) {
            Button("Open Multi-macOS Planner") {
                showMacOSPlanner = true
            }
            .disabled(installers.isEmpty)
        }
    }

    private var oclpCard: some View {
        setupCard(.openCoreLegacyPatcher) {
            Button("Open OCLP Planner") {
                showMacOSPlanner = true
            }
            .disabled(installers.isEmpty)
            Button("Official OCLP Models") {
                open(OperatingSystemResource.openCoreLegacyPatcher.downloadPage)
            }
        }
    }

    private var intelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                "Intel Macs — x86-64",
                subtitle: "Official Windows and Linux download pages for genuine Intel-based Macs."
            )

            Label(
                "These links do not guarantee model-specific drivers or boot support. Windows 11 is not an Apple-supported Boot Camp target.",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundColor(.orange)

            ForEach(OperatingSystemResource.intelWindowsOptions) { option in
                operatingSystemCard(option)
            }

            linuxDistributionList
        }
    }

    private var linuxDistributionList: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
            ForEach(OperatingSystemResource.intelLinuxOptions) { distribution in
                Button {
                    open(distribution.downloadPage)
                } label: {
                    HStack {
                        Text(distribution.name)
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appleSiliconSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                "Apple Silicon Macs — ARM64",
                subtitle: "Native Linux setup for supported Apple Silicon Macs through Asahi Linux."
            )

            operatingSystemCard(OperatingSystemResource.fedoraAsahi) {
                Button("Open Official Setup") {
                    open(OperatingSystemResource.fedoraAsahi.downloadPage)
                }
                Button(copiedAsahiCommand ? "Copied" : "Copy Install Command") {
                    copyAsahiCommand()
                }
            }

            Label(
                "Mist Universal never runs the Asahi installer automatically. Read the official Mac model support and backup instructions first.",
                systemImage: "checkmark.shield"
            )
            .foregroundColor(.secondary)
        }
    }

    private var safetyFooter: some View {
        Label(
            "Mac-only resource screen — no downloads, scripts, partitions, or boot files are changed automatically.",
            systemImage: "checkmark.shield"
        )
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(subtitle)
                .foregroundColor(.secondary)
        }
    }

    private func operatingSystemCard(
        _ option: OperatingSystemResource,
        @ViewBuilder actions: () -> some View
    ) -> some View {
        setupCard(option) {
            actions()
            Button("Setup Guide") {
                open(option.setupGuide)
            }
        }
    }

    private func operatingSystemCard(_ option: OperatingSystemResource) -> some View {
        operatingSystemCard(option) {
            Button("Official Download") {
                open(option.downloadPage)
            }
        }
    }

    private func setupCard(
        _ resource: OperatingSystemResource,
        @ViewBuilder actions: () -> some View
    ) -> some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: resource.systemImage)
                    .font(.title2)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(resource.name)
                            .font(.headline)
                        Spacer()
                        Text(resource.architecture)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(resource.summary)
                    Text(resource.supportNote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        actions()
                    }
                }
            }
            .padding(4)
        }
    }

    private func open(_ value: String) {
        guard let url: URL = URL(string: value) else {
            return
        }
        openURL(url)
    }

    private func copyAsahiCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("curl https://alx.sh | sh", forType: .string)
        copiedAsahiCommand = true
    }
}

struct MultiOSSetupView_Previews: PreviewProvider {
    static var previews: some View {
        MultiOSSetupView(installers: [.example])
    }
}
