//
//  SettingsAboutView.swift
//  Mist
//
//  Created by Nindi Gill on 15/6/2022.
//

import SwiftUI

struct SettingsAboutView: View {
    @Environment(\.openURL)
    var openURL: OpenURLAction
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    private let length: CGFloat = 128
    private let spacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                ScaledImage(length: length)
                VStack(alignment: .leading) {
                    Text("Mist Universal")
                        .font(.largeTitle)
                    Text("Apple Mac Multi-Installer")
                        .font(.title3)
                    HStack(spacing: spacing) {
                        Text("Version: \(version)")
                        Text("(\(build))")
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            PaddedDivider()
            HStack {
                Text("Based on [Mist](https://github.com/ninxsoft/Mist) by Ninxsoft · Universal installer development by [dracinn](https://github.com/dracinn)")
                Spacer()
                Button("Visit Homepage") {
                    visitHomepage()
                }
            }
        }
        .padding()
    }

    private func visitHomepage() {
        guard let url: URL = URL(string: .repositoryURL) else {
            return
        }

        openURL(url)
    }
}

struct SettingsAboutView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsAboutView()
    }
}
