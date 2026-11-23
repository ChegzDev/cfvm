import 'package:cfvm/src/errors.dart';
import 'package:cfvm/src/platform.dart';
import 'package:cfvm/src/releases/flutter_releases.dart';
import 'package:cfvm/src/version.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('canonicalVersion', () {
    test('trims, lowercases and strips a leading v', () {
      expect(canonicalVersion(' 3.19.0 '), '3.19.0');
      expect(canonicalVersion('v1.12.13+hotfix.9'), '1.12.13+hotfix.9');
      expect(canonicalVersion('Stable'), 'stable');
    });
  });

  group('isValidVersionName', () {
    test('accepts versions and channels', () {
      for (final v in [
        '3.19.0',
        '3.20.0-1.2.pre',
        '1.12.13+hotfix.9',
        'master'
      ]) {
        expect(isValidVersionName(v), isTrue, reason: v);
      }
    });

    test('rejects path-like or empty names', () {
      for (final v in ['', '../x', 'a/b', r'a\b', '.hidden', '3..1', 'x y']) {
        expect(isValidVersionName(v), isFalse, reason: v);
      }
    });
  });

  group('compareVersions', () {
    test('orders numerically, pre-releases before releases, names last', () {
      final versions = [
        'master',
        '3.19.0',
        '3.20.0-1.2.pre',
        '3.3.10',
        '3.20.0',
        '1.12.13+hotfix.9',
        '3.20.0-0.1.pre',
      ]..sort(compareVersions);
      expect(versions, [
        '1.12.13+hotfix.9',
        '3.3.10',
        '3.19.0',
        '3.20.0-0.1.pre',
        '3.20.0-1.2.pre',
        '3.20.0',
        'master',
      ]);
    });
  });

  group('ReleaseIndex.resolve', () {
    final index = ReleaseIndex.fromJson(sampleMetadata());

    test('resolves a channel to its current release', () {
      final r = index.resolve('stable', linuxX64);
      expect(r.name, '3.22.1');
      expect(r.effectiveArch, 'x64');
      expect(index.resolve('beta', linuxX64).name, '3.23.0-0.1.pre');
    });

    test('prefers the host architecture', () {
      final r = index.resolve('3.22.1', const HostPlatform('macos', 'arm64'));
      expect(r.effectiveArch, 'arm64');
    });

    test('falls back to x64 where emulation exists', () {
      final r = index.resolve('3.19.0', const HostPlatform('macos', 'arm64'));
      expect(r.effectiveArch, 'x64');
    });

    test('does not fall back to x64 on Linux arm64', () {
      expect(
          () => index.resolve('3.19.0', const HostPlatform('linux', 'arm64')),
          throwsA(isA<CfvmException>()));
    });

    test('matches old versions with or without the v prefix', () {
      expect(index.resolve('1.12.13+hotfix.9', linuxX64).version,
          'v1.12.13+hotfix.9');
      expect(index.resolve('v1.12.13+hotfix.9', linuxX64).name,
          '1.12.13+hotfix.9');
    });

    test('reports unknown versions', () {
      expect(
        () => index.resolve('9.9.9', linuxX64),
        throwsA(isA<CfvmException>()
            .having((e) => e.message, 'message', contains('not found'))),
      );
    });

    test('rejects malformed metadata', () {
      expect(() => ReleaseIndex.fromJson({'base_url': 1}),
          throwsA(isA<CfvmException>()));
    });
  });
}
