# Agent instructions

## Iteration completion: update the Android emulator

This rule applies to every agent completing an implementation iteration in this repository. The coordinating agent owns deployment after parallel work is integrated; subagents must include this requirement in their handoff.

Before marking an iteration complete:

1. Finish the iteration's changes and required checks, then run `pwsh -NoProfile -File scripts/deploy-emulator.ps1` from the final integrated working tree. Use `docs/DEVELOPER_SETUP.md` for setup and explicit emulator selection. The script builds a fresh debug APK, installs with `-r`, relaunches the app and checks that its process stays running. An older APK or hot reload does not satisfy this gate; rerun if application code or assets change afterward.
2. Preserve app data: never uninstall, clear storage or wipe the emulator to make deployment pass without explicit user permission. If the emulator target is unavailable or ambiguous, resolve it with the user rather than installing on an arbitrary device.
3. Visually verify startup and smoke-test the iteration's changed flow; a running process alone is not acceptance evidence. Leave the updated app installed and running for the user.
4. In the completion report, include the emulator serial, build/install outcome and smoke-test result. If build, installation or verification fails, report the concrete blocker and keep iteration completion blocked until resolved or explicitly waived by the user.

Planning/documentation-only tasks do not require deployment. Emulator smoke testing supplements, rather than replaces, any required profile/release or physical-device acceptance tests.
