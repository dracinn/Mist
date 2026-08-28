//
//  OperatingSystemResource.swift
//  Mist
//

import Foundation

enum MultiOSSection: String, CaseIterable, Identifiable, Sendable {
    case macOS
    case intel
    case appleSilicon

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .macOS:
            "macOS & OCLP"
        case .intel:
            "Intel Mac — x86-64"
        case .appleSilicon:
            "Apple Silicon — ARM64"
        }
    }

    var systemImage: String {
        switch self {
        case .macOS:
            "macos"
        case .intel:
            "cpu"
        case .appleSilicon:
            "apple.logo"
        }
    }
}

struct OperatingSystemResource: Identifiable, Hashable, Sendable {
    var id: String {
        name
    }

    var name: String
    var architecture: String
    var summary: String
    var supportNote: String
    var downloadPage: String
    var setupGuide: String
    var systemImage: String
}

extension OperatingSystemResource {
    /// Apple's native macOS installer path.
    static let nativeMacOS: OperatingSystemResource = .init(
        name: "Native macOS",
        architecture: "Intel Mac or Apple Silicon",
        summary: "Select multiple Apple catalog installers and preview one external drive layout.",
        supportNote: "Apple silicon uses only Apple's native installer and restore path.",
        downloadPage: "",
        setupGuide: "",
        systemImage: "macos"
    )

    /// OpenCore Legacy Patcher planning for eligible Intel Macs.
    static let openCoreLegacyPatcher: OperatingSystemResource = .init(
        name: "OpenCore Legacy Patcher",
        architecture: "Eligible Intel Macs only",
        summary: "Plan an OCLP-assisted macOS installer after importing an Intel Mac hardware report.",
        supportNote: "OCLP is not offered for Apple silicon or generic PCs. Model eligibility data is the next implementation stage.",
        downloadPage: "https://github.com/dortania/OpenCore-Legacy-Patcher/blob/main/docs/MODELS.md",
        setupGuide: "https://dortania.github.io/OpenCore-Legacy-Patcher/",
        systemImage: "wrench.and.screwdriver"
    )

    /// Official Windows and Linux resources for Intel Macs.
    static let intelMacOptions: [OperatingSystemResource] = [
        .init(
            name: "Windows 10",
            architecture: "x86-64",
            summary: "Microsoft ISO with Apple's Boot Camp path on listed Intel Macs.",
            supportNote: "Apple documents Windows 10 Boot Camp support. Free Windows 10 support ended in October 2025.",
            downloadPage: "https://www.microsoft.com/software-download/windows10ISO",
            setupGuide: "https://support.apple.com/102622",
            systemImage: "desktopcomputer"
        ),
        .init(
            name: "Windows 11",
            architecture: "x86-64",
            summary: "Microsoft's current Windows ISO for compatible 64-bit systems.",
            supportNote: "Not an Apple-supported Boot Camp target. Many Intel Macs do not meet Windows 11 TPM requirements.",
            downloadPage: "https://www.microsoft.com/software-download/windows11",
            setupGuide: "https://www.microsoft.com/windows/windows-11-specifications",
            systemImage: "desktopcomputer"
        ),
        .init(
            name: "Ubuntu Desktop",
            architecture: "x86-64 / AMD64",
            summary: "Ubuntu Desktop installation and live USB image.",
            supportNote: "Hardware support varies by Intel Mac model; test live media before installing.",
            downloadPage: "https://ubuntu.com/download/desktop",
            setupGuide: "https://ubuntu.com/desktop/docs/en/latest/tutorial/install-ubuntu-desktop/",
            systemImage: "terminal"
        ),
        .init(
            name: "Fedora Workstation",
            architecture: "x86-64",
            summary: "Fedora Workstation live ISO and checksum resources.",
            supportNote: "Use the official x86-64 image. Intel Mac hardware support varies by model.",
            downloadPage: "https://www.fedoraproject.org/workstation/download/",
            setupGuide: "https://docs.fedoraproject.org/en-US/fedora/latest/getting-started/",
            systemImage: "f.circle"
        ),
        .init(
            name: "Debian",
            architecture: "AMD64 / Intel 64",
            summary: "Debian stable net installer, live images, and full installation media.",
            supportNote: "Choose a 64-bit PC image. Wi-Fi or other drivers may vary by Intel Mac model.",
            downloadPage: "https://www.debian.org/distrib/",
            setupGuide: "https://www.debian.org/releases/stable/amd64/",
            systemImage: "shippingbox"
        )
    ]

    /// Official Asahi Linux resource for supported Apple-silicon Macs.
    static let fedoraAsahi: OperatingSystemResource = .init(
        name: "Fedora Asahi Remix",
        architecture: "Apple Silicon / ARM64",
        summary: "Asahi Linux's Fedora-based distribution for supported Apple-silicon Macs.",
        supportNote: "Support is model-specific. Review the current official compatibility and backup guidance before setup.",
        downloadPage: "https://asahilinux.org/fedora/",
        setupGuide: "https://docs.fedoraproject.org/en-US/fedora-asahi-remix/",
        systemImage: "apple.logo"
    )
}
