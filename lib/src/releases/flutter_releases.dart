import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors.dart';
import '../platform.dart';
import '../cli_name.dart';
import '../version.dart';

/// One entry of Flutter's official release metadata
/// (`releases_<os>.json`).
class FlutterRelease {
  const FlutterRelease({
    required this.hash,
    required this.channel,
    required this.version,
    required this.archive,
    this.arch,
    this.sha256,
  });

  factory FlutterRelease.fromJson(Map<String, dynamic> json) => FlutterRelease(
        hash: json['hash'] as String,
        channel: json['channel'] as String,
        version: json['version'] as String,
        archive: json['archive'] as String,
        arch: json['dart_sdk_arch'] as String?,
        sha256: json['sha256'] as String?,
      );

  final String hash;
  final String channel;
  final String version;

  /// Archive path relative to the metadata's `base_url`.
  final String archive;

  /// `x64` or `arm64`. Missing on old releases, which are all x64.
  final String? arch;
  final String? sha256;

  /// Directory name used for this release under the CFVM versions dir.
  String get name => canonicalVersion(version);

  String get effectiveArch => arch ?? 'x64';
}

/// Parsed release metadata for one operating system.
class ReleaseIndex {
  ReleaseIndex({
    required this.baseUrl,
    required this.currentReleases,
    required this.releases,
  });

  factory ReleaseIndex.fromJson(Map<String, dynamic> json) {
    try {
      return ReleaseIndex(
        baseUrl: json['base_url'] as String,
        currentReleases:
            Map<String, String>.from(json['current_release'] as Map),
        releases: [
          for (final r in json['releases'] as List)
            FlutterRelease.fromJson(r as Map<String, dynamic>),
        ],
      );
    } on TypeError {
      throw const CfvmException(
          'Flutter release metadata has an unexpected format.');
    }
  }

  final String baseUrl;

  /// Channel name -> commit hash of the channel's current release.
  final Map<String, String> currentReleases;

  /// All releases, newest first.
  final List<FlutterRelease> releases;

  /// Finds the archive release for [request] (a version such as `3.19.0`, or
  /// the `stable`/`beta` channel) that runs on [host].
  ///
  /// Prefers a build for the host's architecture and falls back to x64 where
  /// the host can emulate it.
  FlutterRelease resolve(String request, HostPlatform host) {
    final name = canonicalVersion(request);
    final List<FlutterRelease> candidates;
    if (archiveChannels.contains(name)) {
      final hash = currentReleases[name];
      candidates =
          releases.where((r) => r.channel == name && r.hash == hash).toList();
      if (candidates.isEmpty) {
        throw CfvmException('No current "$name" release found for ${host.os}.');
      }
    } else {
      candidates = releases.where((r) => r.name == name).toList();
      if (candidates.isEmpty) {
        throw CfvmException(
          'Flutter version "$request" was not found in the official '
          '${host.os} release list.',
          hint: 'Use a released version such as 3.19.0, or a channel: '
              'stable, beta, master.\n'
              'See https://docs.flutter.dev/release/archive for all versions.',
        );
      }
    }

    for (final r in candidates) {
      if (r.effectiveArch == host.arch) return r;
    }
    if (host.canRunX64) {
      for (final r in candidates) {
        if (r.effectiveArch == 'x64') return r;
      }
    }
    throw CfvmException(
      'Flutter ${candidates.first.name} has no official build for $host.',
      hint: 'Official archives for this platform are x64 only. '
          'The master channel (built from source with git) may work: '
          '$cliName install master',
    );
  }
}

/// Source of Flutter release metadata.
abstract class ReleaseRepository {
  Future<ReleaseIndex> fetch();
}

/// Downloads metadata from Flutter's official release storage.
class HttpReleaseRepository implements ReleaseRepository {
  HttpReleaseRepository(this.host);

  static const metadataBaseUrl =
      'https://storage.googleapis.com/flutter_infra_release/releases';

  final HostPlatform host;
  ReleaseIndex? _cached;

  Uri get metadataUrl => Uri.parse('$metadataBaseUrl/releases_${host.os}.json');

  @override
  Future<ReleaseIndex> fetch() async {
    final cached = _cached;
    if (cached != null) return cached;

    final url = metadataUrl;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final response =
          await (await client.getUrl(url)).close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw CfvmException('Could not fetch Flutter releases from $url '
            '(HTTP ${response.statusCode}).');
      }
      final body =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) throw const FormatException();
      return _cached = ReleaseIndex.fromJson(json);
    } on FormatException {
      throw CfvmException(
          'Flutter release metadata at $url is not valid JSON.');
    } on SocketException catch (e) {
      throw _networkError(url, e.message);
    } on HttpException catch (e) {
      throw _networkError(url, e.message);
    } on TimeoutException {
      throw _networkError(url, 'timed out');
    } finally {
      client.close(force: true);
    }
  }

  static const _timeout = Duration(seconds: 60);

  CfvmException _networkError(Uri url, String reason) => CfvmException(
        'Could not fetch Flutter releases from $url: $reason',
        hint: 'Check your internet connection and try again.',
      );
}
