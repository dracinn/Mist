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

    /// Official Windows resources for Intel Macs.
    static let intelWindowsOptions: [OperatingSystemResource] = [
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
        )
    ]

    /// Official x86-64 Linux distribution download resources for Intel Macs.
    static let intelLinuxOptions: [OperatingSystemResource] = [
        intelLinuxResource(name: "Ubuntu", downloadPage: "https://ubuntu.com/download/desktop"),
        intelLinuxResource(name: "Fedora Workstation", downloadPage: "https://www.fedoraproject.org/workstation/download/"),
        intelLinuxResource(name: "Debian", downloadPage: "https://www.debian.org/distrib/"),
        intelLinuxResource(name: "Linux Mint", downloadPage: "https://www.linuxmint.com/download.php"),
        intelLinuxResource(name: "Pop!_OS", downloadPage: "https://system76.com/pop/download/"),
        intelLinuxResource(name: "openSUSE Tumbleweed", downloadPage: "https://get.opensuse.org/tumbleweed/"),
        intelLinuxResource(name: "RHEL", downloadPage: "https://developers.redhat.com/products/rhel/download"),
        intelLinuxResource(name: "Rocky Linux", downloadPage: "https://rockylinux.org/download"),
        intelLinuxResource(name: "Zorin OS", downloadPage: "https://zorin.com/os/download/"),
        intelLinuxResource(name: "Bazzite", downloadPage: "https://bazzite.gg/"),
        intelLinuxResource(name: "SteamOS", downloadPage: "https://store.steampowered.com/steamos/"),
        intelLinuxResource(name: "CachyOS", downloadPage: "https://cachyos.org/download/"),
        intelLinuxResource(name: "Nobara Linux", downloadPage: "https://nobaraproject.org/download.html"),
        intelLinuxResource(name: "Garuda Linux", downloadPage: "https://garudalinux.org/downloads"),
        intelLinuxResource(name: "Fedora KDE", downloadPage: "https://fedoraproject.org/kde/download"),
        intelLinuxResource(name: "Arch Linux", downloadPage: "https://archlinux.org/download/"),
        intelLinuxResource(name: "EndeavourOS", downloadPage: "https://endeavouros.com/"),
        intelLinuxResource(name: "Lubuntu", downloadPage: "https://lubuntu.me/downloads/"),
        intelLinuxResource(name: "Xubuntu", downloadPage: "https://xubuntu.org/download/"),
        intelLinuxResource(name: "MX Linux", downloadPage: "https://mxlinux.org/download-links/"),
        intelLinuxResource(name: "antiX", downloadPage: "https://antixlinux.com/download/"),
        intelLinuxResource(name: "Puppy Linux", downloadPage: "https://puppylinux-woof-ce.github.io/"),
        intelLinuxResource(name: "Bodhi Linux", downloadPage: "https://www.bodhilinux.com/download/"),
        intelLinuxResource(name: "Peppermint OS", downloadPage: "https://peppermintos.com/"),
        intelLinuxResource(name: "Alpine Linux", downloadPage: "https://www.alpinelinux.org/downloads/"),
        intelLinuxResource(name: "elementary OS", downloadPage: "https://elementary.io/")
    ]

    /// All official external operating-system resources for Intel Macs.
    static var intelMacOptions: [OperatingSystemResource] {
        intelWindowsOptions + intelLinuxOptions
    }

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

    /// Creates a compact Intel Linux download entry.
    ///
    /// - Parameters:
    ///   - name:         The distribution name.
    ///   - downloadPage: The distribution's official download page.
    ///
    /// - Returns: A compact x86-64 Linux resource.
    private static func intelLinuxResource(name: String, downloadPage: String) -> OperatingSystemResource {
        .init(
            name: name,
            architecture: "x86-64",
            summary: "",
            supportNote: "",
            downloadPage: downloadPage,
            setupGuide: downloadPage,
            systemImage: "terminal"
        )
    }
}
