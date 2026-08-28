//
//  WorkspaceSection.swift
//  Mist
//

import Foundation

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case catalog
    case installerPlanner
    case multiOS
    case devices
    case activity
    case logs
    case settings

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .catalog:
            "Universal Catalog"
        case .installerPlanner:
            "Installer Planner"
        case .multiOS:
            "Multi-OS Setup"
        case .devices:
            "Mac Hardware"
        case .activity:
            "Activity"
        case .logs:
            "Logs"
        case .settings:
            "App Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .catalog:
            "macOS, Windows and Linux"
        case .installerPlanner:
            "Plan macOS media and disk layouts"
        case .multiOS:
            "Windows, Linux, OCLP & Asahi"
        case .devices:
            "Intel & Apple Silicon Macs"
        case .activity:
            "Downloads and installer tasks"
        case .logs:
            "Mist diagnostic log"
        case .settings:
            "Downloads, exports and updates"
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
        case .devices:
            "desktopcomputer"
        case .activity:
            "waveform.path.ecg"
        case .logs:
            "doc.text.magnifyingglass"
        case .settings:
            "gearshape"
        }
    }
}
