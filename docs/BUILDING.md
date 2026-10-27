# Building Paddr

[Back to Paddr](../README.md) · [CLI guide](CLI.md)

Xcode 27 with the macOS 27 SDK is required:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
BUILD_SCRATCH_PATH="$PWD/.build/xcode27" \
scripts/build-app.sh
open dist/Paddr.app
```

Paddr builds for arm64. The binary deployment target remains macOS 26.0; confirmed controller support requires macOS 27 or later.

Run commands from the repository root. Local builds are ad-hoc signed by default; moving or replacing a build can require granting permissions again.

For the required test and release checks, see [Contributing](../CONTRIBUTING.md#development). Distribution packaging requires a clean checkout at an annotated version tag matching `Packaging/Info.plist`; see `scripts/package-release.sh`. Developer ID signing and Apple notarization are separate from a local build.
