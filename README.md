# CFVM — Chegz Flutter Version Management

A lightweight command-line tool for installing several Flutter SDK versions
side by side and choosing which one each project uses.

- Downloads **official** Flutter releases (with SHA-256 verification).
- Pins a Flutter version per project in a small `.cfvm.json` file.
- Falls back to a **global** default version outside pinned projects.
- Runs `flutter` / `dart` from the selected SDK.
- **Never touches** your existing Flutter installation or your system `PATH`.

## Requirements

- Dart SDK 3.0 or newer (any Dart, including the one bundled with an existing
  Flutter install, can run CFVM).
- macOS: `unzip` (preinstalled).
- Linux: `tar` with `xz` support (`xz-utils`).
- Windows: Windows 10 (1803) or newer (uses the built-in `tar.exe`).
- `git`, only for installing the `master` channel.

## Installation

CFVM is published on [pub.dev](https://pub.dev/packages/cfvm).
`dart run cfvm` runs CFVM for the **current directory**. Choose one of these:

**Option A: add it as a dev dependency of your project** (so `dart run cfvm`
works inside that project):

```yaml
# pubspec.yaml of your Flutter project
dev_dependencies:
  cfvm: ^1.0.0
```

```bash
dart pub get
dart run cfvm use 3.19.0
```

`dart run` uses the `dart` on your `PATH` to resolve your project's
dependencies. For a Flutter project, that `dart` must be able to do this,
which in practice means the one bundled with an existing Flutter install. If
that's a problem, use Option B.

**Option B: activate it globally** (the command is then `cfvm`, available
everywhere):

```bash
dart pub global activate cfvm
cfvm list
```

Messages printed by CFVM always show the `dart run cfvm …` form. With Option B,
type `cfvm …` instead.

## Usage

| Command | Description |
|---|---|
| `dart run cfvm install [version]` | Download and install a Flutter SDK. Accepts a version (`3.19.0`) or a channel (`stable`, `beta`, `master`). Without a version, installs the version configured for the current project. |
| `dart run cfvm use <version>` | Pin the Flutter version for the current project (writes `.cfvm.json`). Installs it first if needed. |
| `dart run cfvm global [version]` | Set the default Flutter version. Installs it first if needed. Without a version, shows the current one. |
| `dart run cfvm list` | List installed SDKs and show which are used by the project and globally. |
| `dart run cfvm cleanup [--yes]` | Find installed versions that nothing uses and offer to remove them. |
| `dart run cfvm flutter <args>` | Run `flutter` from the selected SDK. |
| `dart run cfvm dart <args>` | Run `dart` from the selected SDK. |

Global option: `-v, --verbose` prints which SDK is being used.

### Typical workflow

```bash
dart run cfvm global stable         # installs the current stable (e.g. 3.50.1)
                                    # and makes it the default
cd my_app
dart run cfvm use 3.19.0            # installs 3.19.0 if needed; this project
                                    # now uses it
dart run cfvm flutter --version     # -> Flutter 3.19.0
dart run cfvm dart pub get
dart run cfvm flutter run           # interactive commands work too

dart run cfvm list
dart run cfvm cleanup
```

### Versions and channels

- **Versions** (`3.19.0`, `3.20.0-1.2.pre`, `v1.22.6`) are looked up in the
  official release list for your OS.
- **`stable` / `beta`** resolve to the channel's *current* release and install
  that exact version (e.g. `stable` → `3.50.1`). `use stable` and
  `global stable` also pin the exact version. Your project then stays on that
  version until you change it.
- **`master`** has no release archives, so it is cloned from
  `https://github.com/flutter/flutter.git`. This is a full clone, so it is
  slow and large. The first `flutter` command downloads the Dart SDK. To
  update it, run `dart run cfvm flutter upgrade` in a project using `master`.

### How the SDK is chosen

For `flutter` and `dart` commands, CFVM checks in this order:

1. `.cfvm.json` in the current directory or the nearest parent directory.
2. The global version.
3. If neither is set, or the version is not installed, CFVM exits with an
   error that names the command to run.

## Files and directories

**Project configuration**: `.cfvm.json` in the project root (next to
`pubspec.yaml`). Commit it so your team uses the same version:

```json
{
  "flutter": "3.19.0"
}
```

**CFVM home**: a normal, visible folder named `cfvm` in your home directory:

| OS | Default location |
|---|---|
| macOS | `~/cfvm` (e.g. `/Users/you/cfvm`) |
| Linux | `~/cfvm` (e.g. `/home/you/cfvm`) |
| Windows | `%USERPROFILE%\cfvm` (e.g. `C:\Users\you\cfvm`) |

SDKs live in `cfvm/versions/<version>/`. To use another location (for
example an external drive), set the `CFVM_HOME` environment variable.

```
~/cfvm/
  config.json            global version + projects where `use` was run
  versions/3.19.0/       installed SDKs (one complete Flutter SDK each)
  tmp/                   downloads and extractions in progress (temporary)
```

## Safety

- **Downloads** go to `cfvm/tmp/*.part`. The archive is checked against the
  official SHA-256 checksum and extracted into `cfvm/tmp/staging-<version>`. Only then
  is it moved into `versions/<version>` in a single step. An interrupted or
  failed install never leaves a half-installed SDK that looks usable. Running
  the command again starts clean, and `cleanup` deletes the leftovers.
- **Existing SDKs are never overwritten.** If `versions/<version>` exists but
  is incomplete, `install` asks before deleting it.
- **`cleanup` asks before deleting anything.** It treats a version as in use
  if it is the global version, if the current project uses it, or if any
  project where you ran `use` still uses it. When not run in a terminal (CI),
  it only lists what it would remove, unless you pass `--yes`.
- CFVM only ever writes inside `~/cfvm` and the project's `.cfvm.json`. Your
  system Flutter installation and `PATH` are not changed. `flutter`/`dart`
  child processes get the selected SDK's `bin` directory prepended to *their*
  `PATH` only.

## Platform notes and limitations

- **macOS on Apple Silicon**: CFVM installs arm64 builds. Older releases that
  only have x64 builds get the x64 build, which runs under Rosetta 2. CFVM
  prints a warning when this happens.
- **Linux on arm64**: Flutter publishes no official Linux arm64 archives, so
  only `master` (built from source via git) can be installed.
- **Windows**: `flutter.bat`/`dart.bat` run through `cmd.exe`, so arguments
  containing cmd special characters (`&`, `|`, `^`, `%`) may need extra
  quoting. Windows on Arm installs x64 builds (emulated).
- Interrupted downloads restart from the beginning (no resume).
- Don't run two `install` commands for the same version at the same time.
- `global` does not put Flutter on your `PATH`. Run it through
  `dart run cfvm flutter …`, or add `~/cfvm/versions/<version>/bin` to your
  `PATH` yourself.
- Verified on macOS (Apple Silicon). Linux and Windows code paths are
  implemented, but this release was not run on those systems.

## Development

```bash
git clone https://github.com/ChegzDev/cfvm.git
cd cfvm
dart pub get
dart run cfvm --help
dart analyze
dart test
```

Project layout:

```
bin/cfvm.dart                 entry point (`dart run cfvm`)
lib/src/cli/                  argument parsing and the seven commands
lib/src/config/               global config.json and project .cfvm.json
lib/src/releases/             official release metadata: fetch + version lookup
lib/src/sdk/                  CFVM home layout, installed SDKs, installer,
                              version resolution (project → global)
lib/src/io/                   logger, prompts, process execution
test/                         unit tests (fakes in test/helpers.dart)
```

## License

MIT. See [LICENSE](LICENSE).
