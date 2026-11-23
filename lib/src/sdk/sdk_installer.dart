import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../errors.dart';
import '../io/logger.dart';
import '../io/process_runner.dart';
import '../platform.dart';
import '../releases/flutter_releases.dart';
import 'cfvm_home.dart';

/// Installs Flutter SDKs into the CFVM versions directory.
abstract class SdkInstaller {
  /// Downloads, verifies and extracts an official release archive.
  Future<void> installRelease(FlutterRelease release,
      {required String baseUrl});

  /// Clones a channel (e.g. `master`) from the official Flutter repository.
  Future<void> installFromGit(String channel);
}

/// Installation is crash-safe: the SDK only appears under
/// `versions/<version>` after it has been fully downloaded, verified and
/// extracted, via a single directory rename. Anything left behind by an
/// interrupted run (`tmp/*.part`, `tmp/staging-*`) is discarded on the
/// next attempt or by `cfvm cleanup`.
class IoSdkInstaller implements SdkInstaller {
  IoSdkInstaller({
    required this.home,
    required this.host,
    required this.logger,
    required this.processRunner,
    this.environment = const {},
  });

  static const flutterRepoUrl = 'https://github.com/flutter/flutter.git';

  final CfvmHome home;
  final HostPlatform host;
  final Logger logger;
  final ProcessRunner processRunner;
  final Map<String, String> environment;

  @override
  Future<void> installRelease(
    FlutterRelease release, {
    required String baseUrl,
  }) async {
    final name = release.name;
    final dest = Directory(home.versionDir(name));
    _ensureAbsent(dest);

    Directory(home.tempDir).createSync(recursive: true);
    final archive = File(p.join(home.tempDir, p.basename(release.archive)));
    final part = File('${archive.path}.part');
    final staging = Directory(home.stagingDir(name));

    try {
      // A complete archive (renamed from .part only after a full download)
      // may remain from an attempt that failed during extraction.
      if (archive.existsSync()) {
        logger
            .info('Reusing previously downloaded ${p.basename(archive.path)}');
      } else {
        await _download(Uri.parse('$baseUrl/${release.archive}'), part);
        part.renameSync(archive.path);
      }

      final expected = release.sha256;
      if (expected == null) {
        logger.warn('No checksum published for this release; '
            'skipping verification.');
      } else {
        logger.info('Verifying SHA-256 checksum...');
        final actual = (await sha256.bind(archive.openRead()).first).toString();
        if (actual != expected.toLowerCase()) {
          archive.deleteSync();
          throw const CfvmException(
            'Checksum mismatch: the downloaded archive is corrupted.',
            hint: 'Run the install command again to re-download it.',
          );
        }
      }

      _recreate(staging);
      logger.info('Extracting...');
      await _extract(archive, staging);
      final extracted = Directory(p.join(staging.path, 'flutter'));
      if (!extracted.existsSync()) {
        throw const CfvmException(
            'Unexpected archive layout: no "flutter" directory found.');
      }
      _moveIntoPlace(extracted, dest);
      archive.deleteSync();
    } finally {
      _deleteFile(part);
      _deleteDir(staging);
      _deleteTempDirIfEmpty();
    }
  }

  @override
  Future<void> installFromGit(String channel) async {
    final dest = Directory(home.versionDir(channel));
    _ensureAbsent(dest);
    final staging = Directory(home.stagingDir(channel));
    _recreate(staging);
    try {
      final target = p.join(staging.path, 'flutter');
      logger.info('Cloning $flutterRepoUrl ($channel)...');
      final int code;
      try {
        code = await processRunner.runInteractive(
            'git', ['clone', '--branch', channel, flutterRepoUrl, target]);
      } on ProcessException {
        throw CfvmException(
          'git is required to install the "$channel" channel, '
          'but it was not found.',
          hint: 'Install git and make sure it is on your PATH.',
        );
      }
      if (code != 0) {
        throw CfvmException('git clone failed with exit code $code.');
      }
      _moveIntoPlace(Directory(target), dest);
    } finally {
      _deleteDir(staging);
      _deleteTempDirIfEmpty();
    }
  }

  Future<void> _download(Uri url, File target) async {
    logger.info('Downloading $url');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    IOSink? sink;
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw CfvmException(
            'Download failed: HTTP ${response.statusCode} for $url');
      }
      final total = response.contentLength;
      var received = 0;
      var lastPercent = -1;
      sink = target.openWrite();
      // Fail if the connection stalls instead of hanging forever.
      await for (final chunk in response.timeout(const Duration(minutes: 2))) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final percent = received * 100 ~/ total;
          if (percent != lastPercent) {
            lastPercent = percent;
            logger
                .progress('  $percent% (${_mb(received)} / ${_mb(total)} MB)');
          }
        }
      }
      await sink.close();
      sink = null;
      logger.progressDone();
      if (total > 0 && received != total) {
        throw CfvmException(
          'Download incomplete: received $received of $total bytes.',
          hint: 'Run the install command again.',
        );
      }
    } on SocketException catch (e) {
      throw _downloadError(e.message);
    } on HttpException catch (e) {
      throw _downloadError(e.message);
    } on TimeoutException {
      throw _downloadError('the connection stalled');
    } finally {
      try {
        await sink?.close();
      } catch (_) {
        // Already failing; the partial file is deleted by the caller.
      }
      client.close(force: true);
    }
  }

  CfvmException _downloadError(String reason) => CfvmException(
        'Download failed: $reason',
        hint: 'Check your internet connection and run the install command '
            'again.',
      );

  Future<void> _extract(File archive, Directory into) async {
    // System tools preserve file permissions and symlinks, which the Flutter
    // SDK depends on.
    final String executable;
    final List<String> args;
    if (archive.path.endsWith('.zip')) {
      if (host.isWindows) {
        // Use the bsdtar bundled with Windows 10+ (it reads zip files), not
        // a GNU tar that may come first on PATH (e.g. from Git Bash).
        final systemRoot = environment['SystemRoot'] ?? r'C:\Windows';
        executable = p.join(systemRoot, 'System32', 'tar.exe');
        args = ['-xf', archive.path, '-C', into.path];
      } else {
        executable = 'unzip';
        args = ['-q', archive.path, '-d', into.path];
      }
    } else if (archive.path.endsWith('.tar.xz')) {
      executable = 'tar';
      args = ['-xJf', archive.path, '-C', into.path];
    } else {
      throw CfvmException('Unsupported archive format: ${archive.path}');
    }

    final ProcessResult result;
    try {
      result = await processRunner.runCaptured(executable, args);
    } on ProcessException {
      throw CfvmException(
        'Could not run "$executable" to extract the SDK.',
        hint: 'Make sure $executable is installed and on your PATH.',
      );
    }
    if (result.exitCode != 0) {
      throw CfvmException(
          'Extraction failed ($executable exited with ${result.exitCode}): '
          '${result.stderr.toString().trim()}');
    }
  }

  void _ensureAbsent(Directory dest) {
    if (dest.existsSync()) {
      throw CfvmException('Refusing to overwrite existing ${dest.path}.');
    }
  }

  /// The single atomic step that makes an SDK visible as installed.
  void _moveIntoPlace(Directory source, Directory dest) {
    dest.parent.createSync(recursive: true);
    source.renameSync(dest.path);
  }

  void _recreate(Directory dir) {
    _deleteDir(dir);
    dir.createSync(recursive: true);
  }

  void _deleteDir(Directory dir) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  /// Keeps the CFVM folder tidy after a successful install. A verified
  /// archive kept after a failed extraction stays, so a retry can reuse it.
  void _deleteTempDirIfEmpty() {
    final temp = Directory(home.tempDir);
    if (temp.existsSync() && temp.listSync().isEmpty) temp.deleteSync();
  }

  void _deleteFile(File file) {
    if (file.existsSync()) file.deleteSync();
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
