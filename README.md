# Mist Universal

Mist Universal is a macOS installer workspace for genuine Apple computers. It is being developed to preview and eventually create external drives containing multiple macOS installers, with distinct support paths for Intel Macs and Apple-silicon Macs.

The current development version is **0.1**.

## Version 0.1

- Browse Apple's macOS installer and firmware catalogs using Mist's established download tools.
- Select multiple macOS installers and preview their proposed partition layout.
- Discover eligible external physical disks without modifying them.
- Discover existing EFI partitions without mounting or changing them.
- Import and review a local Apple Mac hardware report in JSON format.
- Model native Intel Mac, OCLP Intel Mac, and native Apple-silicon installer paths separately.

The multi-installer interface is currently **preview only**. It does not erase, partition, mount, install, or modify OpenCore/OCLP data.

## Hardware scope

Supported development targets are:

- Apple Intel Macs
- Apple-silicon Macs

Generic PCs, Hackintosh systems, non-Apple SMBIOS identities, and arbitrary OpenCore configurations are not supported. OpenCore Legacy Patcher is treated only as a compatibility path for eligible Intel Macs. Apple silicon always uses Apple's native installer or restore path.

## Hardware report format

Version 0.1 accepts a local JSON report containing an Apple manufacturer, platform, model identifier, and device list. Imports are read-only and reject remote URLs, symbolic links, oversized files, non-Apple manufacturers, and invalid Apple-style model identifiers.

See [the architecture document](docs/UNIVERSAL_INSTALLER_ARCHITECTURE.md) for the current schema, boundaries, and safety model.

## Building

- Xcode 26
- Swift 6.3.1
- macOS Monterey 12 or later

Automatic application updates are disabled for development builds. Builds and source updates come from this repository.

## Upstream and credits

This project is based on [Mist](https://github.com/ninxsoft/Mist), created and maintained upstream by [Nindi Gill / Ninxsoft](https://github.com/ninxsoft). Mist provides the application foundation, Apple catalog support, downloads, validation, exports, caching, and privileged-helper architecture.

[OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher) is the primary compatibility reference for supported legacy Intel Macs. The archived [OCLP-Mod](https://github.com/laobamac/OCLP-Mod) project is consulted only as a historical interface and compatibility reference; its PC/Hackintosh features, services, and binaries are not used.

Additional upstream dependencies and contributors remain credited in their source repositories and license notices.

## License

Mist Universal retains Mist's MIT license and upstream copyright notice. See [LICENSE](LICENSE) for details. Project names and third-party components remain the property of their respective owners.
