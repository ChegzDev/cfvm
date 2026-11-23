## 1.0.0

Initial release.

- Commands: `install`, `use`, `global`, `list`, `cleanup`, `flutter`, `dart`.
- Installs official Flutter release archives with SHA-256 verification;
  `stable`/`beta` resolve to their current release, `master` is cloned with git.
- Crash-safe installs into `~/cfvm/versions/<version>` (override with `CFVM_HOME`).
- Per-project version in `.cfvm.json`, falling back to a global version.
- Never modifies the system Flutter installation or `PATH`.
- macOS, Linux and Windows.
