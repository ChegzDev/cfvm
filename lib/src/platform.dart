import 'dart:ffi' show Abi;
import 'dart:io';

import 'errors.dart';

/// The operating system and CPU architecture CFVM is running on, using the
/// names from Flutter's release metadata (`macos`/`linux`/`windows`,
/// `x64`/`arm64`).
class HostPlatform {
  const HostPlatform(this.os, this.arch);

  factory HostPlatform.current() {
    final String os;
    if (Platform.isMacOS) {
      os = 'macos';
    } else if (Platform.isLinux) {
      os = 'linux';
    } else if (Platform.isWindows) {
      os = 'windows';
    } else {
      throw CfvmException(
        'Unsupported operating system: ${Platform.operatingSystem}. '
        'CFVM supports macOS, Linux and Windows.',
      );
    }
    final abi = Abi.current();
    final isArm64 = abi == Abi.macosArm64 ||
        abi == Abi.linuxArm64 ||
        abi == Abi.windowsArm64;
    return HostPlatform(os, isArm64 ? 'arm64' : 'x64');
  }

  final String os;
  final String arch;

  bool get isWindows => os == 'windows';

  /// Whether x64 builds can run on this host via emulation (Rosetta on
  /// macOS, built-in emulation on Windows on Arm). Linux has none.
  bool get canRunX64 => arch == 'x64' || os == 'macos' || os == 'windows';

  @override
  String toString() => '$os-$arch';
}
