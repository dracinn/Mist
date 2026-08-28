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

    var iconAssetName: String {
        "OS Icon - \(name)"
    }
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
            summary:
            "Microsoft's established 64-bit desktop operating system for productivity, games, and Windows applications. "
                + "Download the official ISO for Apple's supported Boot Camp path on listed Intel Macs.",
            supportNote: "Apple documents Windows 10 Boot Camp support. Free Windows 10 support ended in October 2025.",
            downloadPage: "https://www.microsoft.com/software-download/windows10ISO",
            setupGuide: "https://support.apple.com/102622",
            systemImage: "desktopcomputer"
        ),
        .init(
            name: "Windows 11",
            architecture: "x86-64",
            summary:
            "Microsoft's current 64-bit desktop operating system with its modern Windows interface and application platform. "
                + "Download the official ISO only for Intel Macs that satisfy Microsoft's hardware requirements.",
            supportNote: "Not an Apple-supported Boot Camp target. Many Intel Macs do not meet Windows 11 TPM requirements.",
            downloadPage: "https://www.microsoft.com/software-download/windows11",
            setupGuide: "https://www.microsoft.com/windows/windows-11-specifications",
            systemImage: "desktopcomputer"
        )
    ]

    /// Official x86-64 Linux distribution download resources for Intel Macs.
    static let intelLinuxOptions: [OperatingSystemResource] = [
        intelLinuxResource(name: "Alpine Linux", downloadPage: "https://www.alpinelinux.org/downloads/"),
        intelLinuxResource(name: "antiX", downloadPage: "https://antixlinux.com/download/"),
        intelLinuxResource(name: "Arch Linux", downloadPage: "https://archlinux.org/download/"),
        intelLinuxResource(name: "Bazzite", downloadPage: "https://bazzite.gg/"),
        intelLinuxResource(name: "Bodhi Linux", downloadPage: "https://www.bodhilinux.com/download/"),
        intelLinuxResource(name: "CachyOS", downloadPage: "https://cachyos.org/download/"),
        intelLinuxResource(name: "Debian", downloadPage: "https://www.debian.org/distrib/"),
        intelLinuxResource(name: "elementary OS", downloadPage: "https://elementary.io/"),
        intelLinuxResource(name: "EndeavourOS", downloadPage: "https://endeavouros.com/"),
        intelLinuxResource(name: "Fedora KDE", downloadPage: "https://fedoraproject.org/kde/download"),
        intelLinuxResource(name: "Fedora Workstation", downloadPage: "https://www.fedoraproject.org/workstation/download/"),
        intelLinuxResource(name: "Garuda Linux", downloadPage: "https://garudalinux.org/downloads"),
        intelLinuxResource(name: "Linux Mint", downloadPage: "https://www.linuxmint.com/download.php"),
        intelLinuxResource(name: "Lubuntu", downloadPage: "https://lubuntu.me/downloads/"),
        intelLinuxResource(name: "MX Linux", downloadPage: "https://mxlinux.org/download-links/"),
        intelLinuxResource(name: "Nobara Linux", downloadPage: "https://nobaraproject.org/download.html"),
        intelLinuxResource(name: "openSUSE Tumbleweed", downloadPage: "https://get.opensuse.org/tumbleweed/"),
        intelLinuxResource(name: "Peppermint OS", downloadPage: "https://peppermintos.com/"),
        intelLinuxResource(name: "Pop!_OS", downloadPage: "https://system76.com/pop/download/"),
        intelLinuxResource(name: "Puppy Linux", downloadPage: "https://puppylinux-woof-ce.github.io/"),
        intelLinuxResource(name: "RHEL", downloadPage: "https://developers.redhat.com/products/rhel/download"),
        intelLinuxResource(name: "Rocky Linux", downloadPage: "https://rockylinux.org/download"),
        intelLinuxResource(name: "SteamOS", downloadPage: "https://store.steampowered.com/steamos/"),
        intelLinuxResource(name: "Ubuntu", downloadPage: "https://ubuntu.com/download/desktop"),
        intelLinuxResource(name: "Xubuntu", downloadPage: "https://xubuntu.org/download/"),
        intelLinuxResource(name: "Zorin OS", downloadPage: "https://zorin.com/os/download/")
    ]

    /// All official external operating-system resources for Intel Macs.
    static var intelMacOptions: [OperatingSystemResource] {
        intelWindowsOptions + intelLinuxOptions
    }

    /// Official Asahi Linux resource for supported Apple-silicon Macs.
    static let fedoraAsahi: OperatingSystemResource = .init(
        name: "Fedora Asahi Remix",
        architecture: "Apple Silicon / ARM64",
        summary:
        "The Fedora-based Asahi Linux desktop built specifically for supported Apple Silicon Macs. "
            + "Its installer and hardware enablement follow the official Asahi and Fedora model-support path.",
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
            summary: linuxSummary(name),
            supportNote: "",
            downloadPage: downloadPage,
            setupGuide: downloadPage,
            systemImage: "terminal"
        )
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    /// Detailed catalog description for an Intel Linux distribution.
    private static func linuxSummary(_ name: String) -> String {
        let detail: String = switch name {
        case "Ubuntu":
            "A broadly supported desktop for general work, development, and everyday applications."
        case "Fedora Workstation":
            "A modern developer-focused workstation with a current desktop and software stack."
        case "Debian":
            "A stable, community-developed system suited to dependable long-lived installations."
        case "Linux Mint":
            "A friendly desktop with a familiar workflow for office, web, and general-purpose use."
        case "Pop!_OS":
            "A productivity-oriented desktop designed for development, engineering, and creative work."
        case "openSUSE Tumbleweed":
            "A rolling-release workstation for developers, administrators, and experienced Linux users."
        case "RHEL":
            "An enterprise Linux platform intended for managed corporate and professional environments."
        case "Rocky Linux":
            "A community enterprise workstation compatible with the Red Hat Enterprise Linux ecosystem."
        case "Zorin OS":
            "An approachable desktop with a familiar interface for office users and Windows converts."
        case "Bazzite":
            "A gaming-focused immutable desktop with Steam, Proton, and controller-friendly workflows."
        case "SteamOS":
            "Valve's console-style Linux gaming environment centered on Steam and gamepad use."
        case "CachyOS":
            "A performance-oriented desktop for users who want a current, highly tuned Linux system."
        case "Nobara Linux":
            "A desktop tailored for gaming, streaming, and content creation with convenient defaults."
        case "Garuda Linux":
            "A customizable, gaming-friendly desktop with a visually rich out-of-box experience."
        case "Fedora KDE":
            "A modern Fedora desktop featuring the KDE Plasma environment and a current software stack."
        case "Arch Linux":
            "A minimal rolling-release base for experienced users who want maximum control and customization."
        case "EndeavourOS":
            "An approachable path to an Arch-based desktop with guided installation and sensible defaults."
        case "Lubuntu":
            "A lightweight Ubuntu desktop using LXQt for older Macs and lower-resource workloads."
        case "Xubuntu":
            "A lightweight Ubuntu desktop using XFCE for responsive everyday computing."
        case "MX Linux":
            "A practical, resource-conscious desktop with XFCE and a collection of system tools."
        case "antiX":
            "A very lightweight system for older hardware, minimal installations, and low memory use."
        case "Puppy Linux":
            "An extremely compact Linux environment designed for portable and low-resource use."
        case "Bodhi Linux":
            "A lightweight Ubuntu-based desktop built around the efficient Moksha environment."
        case "Peppermint OS":
            "A lightweight Debian-based desktop for web, office, and modest-hardware use."
        case "Alpine Linux":
            "A security-focused minimal distribution for technical users and highly customized installations."
        case "elementary OS":
            "A polished desktop focused on simplicity, consistency, and an integrated application experience."
        default:
            "An official Linux desktop distribution for supported Intel Mac hardware."
        }
        return "\(detail) Download the official x86-64 installer for a supported Intel Mac."
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
