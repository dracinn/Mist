# Universal Installer / OpenCore Architecture

This branch scaffolds a hardware-aware, multi-OS installer builder on top of Mist without importing GPL source from TINU or other projects.

## Design goals

- Preserve Mist's existing Apple catalog, download, validation, caching, and installer export behavior.
- Add a provider model for macOS, Linux, Windows, recovery, and custom boot media.
- Add a disk planning layer for multiple installer partitions plus shared storage.
- Add an OpenCore/EFI subsystem for x86 UEFI targets.
- Keep Apple Silicon/Asahi boot strategy separate from OpenCore.
- Support imported hardware reports and future local hardware discovery.
- Resolve hardware, selected OS, SMBIOS, OpenCore, kext, SSDT, and driver compatibility before writing media.
- Keep privileged disk/EFI mutations behind the existing helper-tool boundary.

## Source inspiration and licensing

Mist remains the application base. TINU, OC-Little-Translated, Hackintosh-for-All-Computers, Dortania documentation, and OpenCorePkg are references for behavior and architecture only. Do not copy GPL source into this MIT codebase unless the project intentionally changes licensing and satisfies all applicable obligations.

## Proposed layers

1. `UniversalInstaller` models describe targets, boot strategies, partitions, hardware, and compatibility.
2. `InstallerProvider` implementations prepare one install payload (macOS full installer, recovery, Linux ISO, Windows media, etc.).
3. `CompatibilityResolver` turns hardware + OS selection into requirements and warnings.
4. `OpenCoreManager` owns EFI discovery, backup, generation, validation, and deployment.
5. `InstallerPlanBuilder` produces a deterministic disk layout before any destructive operation.
6. Existing Mist helper infrastructure performs privileged disk and EFI changes.

## Initial milestone

The first milestone is intentionally non-destructive: models, protocols, planning, validation, and architecture only. Actual partitioning, EFI mounting, OpenCore deployment, ISO extraction, and hardware probing should be implemented behind these interfaces in follow-up commits with tests.

## Boot strategies

- `nativeMacIntel`
- `openCore`
- `genericUEFI`
- `appleSilicon`
- `asahi`

OpenCore must never be treated as the Apple Silicon boot path.

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
- Add Linux and Windows providers only after the disk planner is tested.
