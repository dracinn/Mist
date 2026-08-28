//
//  SettingsView.swift
//  Mist
//
//  Created by Nindi Gill on 15/6/2022.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var sparkleUpdater: SparkleUpdater
    var embedded: Bool = false
    private let width: CGFloat = 540

    var body: some View {
        TabView {
            SettingsGeneralView(sparkleUpdater: sparkleUpdater)
                .tabItem { Label("General", systemImage: "gear") }
            SettingsFirmwaresView()
                .tabItem { Label("Firmwares", systemImage: "memorychip") }
            SettingsInstallersView()
                .tabItem { Label("Installers", systemImage: "desktopcomputer.and.arrow.down") }
            SettingsApplicationsView()
                .tabItem { Label("Applications", systemImage: "macwindow") }
            SettingsDiskImagesView()
                .tabItem { Label("Disk Images", systemImage: "opticaldiscdrive") }
            SettingsISOsView()
                .tabItem { Label("ISOs", systemImage: "opticaldisc") }
            SettingsPackagesView()
                .tabItem { Label("Packages", systemImage: "shippingbox") }
            SettingsAboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(
            minWidth: embedded ? 620 : width,
            idealWidth: embedded ? 820 : width,
            maxWidth: embedded ? .infinity : width,
            minHeight: embedded ? 520 : nil,
            maxHeight: embedded ? .infinity : nil
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(sparkleUpdater: SparkleUpdater())
        SettingsView(sparkleUpdater: SparkleUpdater(), embedded: true)
    }
}
