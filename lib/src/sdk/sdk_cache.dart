import 'dart:io';

import 'package:path/path.dart' as p;

import '../platform.dart';
import '../version.dart';
import 'cfvm_home.dart';

/// A Flutter SDK directory under the CFVM versions directory.
class InstalledSdk {
  InstalledSdk(this.name, this.path, this.host);

  final String name;
  final String path;
  final HostPlatform host;

  String get binDir => p.join(path, 'bin');

  String get flutterExecutable =>
      p.join(binDir, host.isWindows ? 'flutter.bat' : 'flutter');

  String get dartExecutable =>
      p.join(binDir, host.isWindows ? 'dart.bat' : 'dart');

  /// False if the directory exists but does not look like a Flutter SDK.
  bool get isComplete => File(flutterExecutable).existsSync();
}

/// Read/remove access to installed SDKs.
class SdkCache {
  SdkCache(this.home, this.host);

  final CfvmHome home;
  final HostPlatform host;

  /// Installed SDKs, newest version first.
  List<InstalledSdk> list() {
    final dir = Directory(home.versionsDir);
    if (!dir.existsSync()) return [];
    final sdks = [
      for (final entry in dir.listSync())
        if (entry is Directory && !p.basename(entry.path).startsWith('.'))
          InstalledSdk(p.basename(entry.path), entry.path, host),
    ];
    sdks.sort((a, b) => compareVersions(b.name, a.name));
    return sdks;
  }

  /// The SDK directory for [name], or null if it does not exist.
  InstalledSdk? find(String name) {
    if (!isValidVersionName(name)) return null;
    final path = home.versionDir(name);
    return Directory(path).existsSync() ? InstalledSdk(name, path, host) : null;
  }

  bool isInstalled(String name) => find(name)?.isComplete ?? false;

  Future<void> remove(InstalledSdk sdk) async {
    // Safety net: only ever delete directories inside the CFVM versions dir.
    if (!p.isWithin(home.versionsDir, sdk.path)) {
      throw StateError('Refusing to delete ${sdk.path}');
    }
    await Directory(sdk.path).delete(recursive: true);
  }
}
