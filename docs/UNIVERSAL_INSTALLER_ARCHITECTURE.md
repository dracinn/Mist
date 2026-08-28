# Multi-macOS Installer Architecture for Apple Macs

This branch scaffolds a hardware-aware builder for multiple macOS installers on one drive. Hardware support is intentionally limited to genuine Apple Intel Macs and Apple-silicon Macs. Generic PCs and Hackintosh targets are out of scope.

## Design goals

- Preserve Mist's existing Apple catalog, download, validation, caching, and installer export behavior.
- Add a provider model for full macOS installers and macOS recovery media.
- Add a disk planning layer for multiple macOS installer partitions and one EFI partition.
- Support native installers for Apple Intel Macs and Apple-silicon Macs.
- Treat OpenCore Legacy Patcher (OCLP) as an Intel-Mac-only compatibility path.
- Keep Apple silicon on Apple's native installer and restore paths; never offer OCLP for Apple silicon.
- Support imported hardware reports and future local hardware discovery.
- Resolve the Apple model identifier, platform, selected OS, and OCLP eligibility before writing media.
- Keep privileged disk/EFI mutations behind the existing helper-tool boundary.
- Reject generic PC and Hackintosh hardware profiles.

## Source inspiration and licensing

Mist remains the application base. The official [OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher) project is the primary reference for legacy Intel Mac model eligibility and compatibility behavior. Its supported-model documentation explicitly excludes Apple silicon and unlisted machines.

The archived [OCLP-Mod](https://github.com/laobamac/OCLP-Mod) project may be consulted only as a historical user-experience and compatibility reference. Mist does not use its PC/Hackintosh features, SimpleHac API, binaries, services, or support claims. Neither project is a source dependency, and GPL source must not be copied into this MIT codebase without an intentional licensing change and full license compliance.

## Proposed layers

1. `UniversalInstaller` models describe targets, boot strategies, partitions, hardware, and compatibility.
2. `InstallerProvider` implementations prepare one full macOS installer or recovery payload.
3. `CompatibilityResolver` turns Apple model + OS selection into requirements and warnings.
4. A future OCLP adapter may prepare an eligible Intel Mac path without reimplementing or silently bundling OCLP.
5. `InstallerPlanBuilder` produces a deterministic disk layout before any destructive operation.
6. Existing Mist helper infrastructure performs privileged disk and EFI changes.

## Initial milestone

The first milestone is intentionally non-destructive: models, protocols, planning, validation, and architecture only. Actual partitioning, EFI mounting, OpenCore deployment, ISO extraction, and hardware probing should be implemented behind these interfaces in follow-up commits with tests.

Mist catalog installers are converted into macOS targets using their Apple build metadata and package source. The planner adds explicit working-space overhead, and `InstallerPlanPreview` exposes the proposed layout and remaining capacity without performing any disk operation.

The installer catalog toolbar exposes a preview-only multi-selection sheet. It lets users compare a proposed EFI and multi-macOS partition layout for a chosen capacity and boot strategy, but deliberately provides no disk-selection or execution control.

The preview may read external physical-disk metadata through `diskutil` plist output. Discovery is restricted to writable, external, whole, physical devices with nonzero capacity; internal and virtual disks are excluded. This path invokes only `diskutil list` and `diskutil info` and cannot mount, unmount, erase, or partition media.

Each selected macOS catalog entry carries its own boot strategy, allowing a single preview to model native Intel Mac, OCLP Intel Mac, and native Apple-silicon installer targets independently.

Existing EFI partitions are discovered through read-only `diskutil list` and `diskutil info` plist queries. Discovery is scoped to a selected whole disk and returns partition identity, size, and existing mount state without mounting, unmounting, or modifying the EFI partition.

Hardware profiles can be imported from a local, versioned JSON report. Import is read-only, limited to regular files of at most 1 MiB, rejects symbolic links, and validates schema version 1 before producing a normalized `HardwareProfile`. A report must identify `Apple Inc.` as its manufacturer, declare either an Intel Mac or Apple-silicon Mac platform, and contain an Apple-style model identifier. These checks enforce product scope but are not cryptographic hardware attestation. Local hardware probing remains intentionally unavailable.

```json
{
  "schemaVersion": 1,
  "manufacturer": "Apple Inc.",
  "platform": "intelMac",
  "modelIdentifier": "MacBookPro11,3",
  "modelName": "MacBook Pro (Retina, 15-inch, Mid 2014)",
  "boardName": "Mac-2BD1B31983FE1663",
  "devices": [
    {
      "category": "cpu",
      "name": "Intel Core i7",
      "vendorID": "8086",
      "deviceID": "1234",
      "subsystemID": "5678"
    }
  ],
  "acpiTableNames": ["DSDT", "SSDT-EC"]
}
```

## Current scope

- `nativeMacIntel`
- `openCoreLegacyPatcher` (listed Intel Macs only)
- `appleSilicon`

OCLP must never be treated as the Apple-silicon boot path. Generic OpenCore configuration generation, non-Apple SMBIOS identities, PC ACPI customization, and Hackintosh kext selection are explicitly excluded.

The visible Multi-OS Setup screen may provide official, external resources for Windows 10/11 and x86-64 Linux distributions on Intel Macs, plus Fedora Asahi Remix on supported Apple-silicon Macs. This resource layer does not download images directly, run installers, or add those operating systems to the disk planner yet.

Generic UEFI PCs, Hackintosh systems, shared data partitions, and arbitrary custom media remain excluded. Windows 11 is clearly marked as outside Apple's supported Boot Camp path, while Asahi setup remains user-initiated through the official project.

## Suggested build flow

1. Select target drive.
2. Add installer targets.
3. Import or detect the Apple model and platform when OCLP is selected for an Intel Mac.
4. Resolve compatibility and required components.
5. Calculate partition sizes and display the complete plan.
6. Require an explicit destructive-action confirmation.
7. Partition the drive.
8. Install each target using its provider.
9. Prepare the OCLP path for an eligible Intel Mac where applicable.
10. Verify expected boot files and installer payloads.

## Next implementation slices

- Integrate the new model files into the Xcode target.
- Add unit tests for plan validation and sizing.
- Add a read-only UI for selecting and reviewing an imported hardware report.
- Add an explicit, privileged EFI mounting abstraction after a dedicated safety review.
- Add a macOS provider wrapping Mist's existing installer creation path.
- Add an OCLP supported-model data adapter with source/version provenance.
- Add verified download metadata providers before bringing Windows, Linux, or Asahi payloads into the planner.
- Add a second, explicit safety review before any future disk-writing implementation is designed.
