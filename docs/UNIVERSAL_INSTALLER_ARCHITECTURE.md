# Multi-macOS Installer / OpenCore Architecture

This branch scaffolds a hardware-aware builder for multiple macOS installers on one drive without importing GPL source from TINU or other projects.

## Design goals

- Preserve Mist's existing Apple catalog, download, validation, caching, and installer export behavior.
- Add a provider model for full macOS installers and macOS recovery media.
- Add a disk planning layer for multiple macOS installer partitions and one EFI partition.
- Add an OpenCore/EFI subsystem for x86 UEFI targets.
- Keep native Intel Mac and Apple Silicon boot paths separate from OpenCore.
- Support imported hardware reports and future local hardware discovery.
- Resolve hardware, selected OS, SMBIOS, OpenCore, kext, SSDT, and driver compatibility before writing media.
- Keep privileged disk/EFI mutations behind the existing helper-tool boundary.

## Source inspiration and licensing

Mist remains the application base. TINU, OC-Little-Translated, Hackintosh-for-All-Computers, Dortania documentation, and OpenCorePkg are references for behavior and architecture only. Do not copy GPL source into this MIT codebase unless the project intentionally changes licensing and satisfies all applicable obligations.

## Proposed layers

1. `UniversalInstaller` models describe targets, boot strategies, partitions, hardware, and compatibility.
2. `InstallerProvider` implementations prepare one full macOS installer or recovery payload.
3. `CompatibilityResolver` turns hardware + OS selection into requirements and warnings.
4. `OpenCoreManager` owns EFI discovery, backup, generation, validation, and deployment.
5. `InstallerPlanBuilder` produces a deterministic disk layout before any destructive operation.
6. Existing Mist helper infrastructure performs privileged disk and EFI changes.

## Initial milestone

The first milestone is intentionally non-destructive: models, protocols, planning, validation, and architecture only. Actual partitioning, EFI mounting, OpenCore deployment, ISO extraction, and hardware probing should be implemented behind these interfaces in follow-up commits with tests.

Mist catalog installers are converted into macOS targets using their Apple build metadata and package source. The planner adds explicit working-space overhead, and `InstallerPlanPreview` exposes the proposed layout and remaining capacity without performing any disk operation.

The installer catalog toolbar exposes a preview-only multi-selection sheet. It lets users compare a proposed EFI and multi-macOS partition layout for a chosen capacity and boot strategy, but deliberately provides no disk-selection or execution control.

The preview may read external physical-disk metadata through `diskutil` plist output. Discovery is restricted to writable, external, whole, physical devices with nonzero capacity; internal and virtual disks are excluded. This path invokes only `diskutil list` and `diskutil info` and cannot mount, unmount, erase, or partition media.

Each selected macOS catalog entry carries its own boot strategy, allowing a single preview to model Native Intel, OpenCore, and Apple Silicon installer targets independently.

## Current scope

- `nativeMacIntel`
- `openCore`
- `appleSilicon`

OpenCore must never be treated as the Apple Silicon boot path.

Linux, Windows, generic UEFI, Asahi, shared data partitions, and arbitrary custom media are intentionally deferred.

## Suggested build flow

1. Select target drive.
2. Add installer targets.
3. Import or detect target hardware when OpenCore is selected.
4. Resolve compatibility and required components.
5. Calculate partition sizes and display the complete plan.
6. Require an explicit destructive-action confirmation.
7. Partition the drive.
8. Install each target using its provider.
9. Build/validate/deploy EFI where applicable.
10. Verify expected boot files and installer payloads.

## Next implementation slices

- Integrate the new model files into the Xcode target.
- Add unit tests for plan validation and sizing.
- Add a read-only hardware report importer.
- Add a read-only EFI detector/mounter abstraction.
- Add a macOS provider wrapping Mist's existing installer creation path.
- Add OpenCore configuration generation as a separate service.
- Add a second, explicit safety review before any future disk-writing implementation is designed.
