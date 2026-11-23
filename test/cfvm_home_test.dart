import 'package:cfvm/src/errors.dart';
import 'package:cfvm/src/sdk/cfvm_home.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CfvmHome.fromEnvironment', () {
    test('defaults to a visible "cfvm" folder in HOME on macOS/Linux', () {
      final home =
          CfvmHome.fromEnvironment({'HOME': '/Users/me'}, isWindows: false);
      expect(home.root, p.normalize(p.absolute('/Users/me/cfvm')));
      expect(
          home.versionDir('3.19.0'), p.join(home.root, 'versions', '3.19.0'));
    });

    test('uses USERPROFILE on Windows', () {
      final home = CfvmHome.fromEnvironment(
          {'USERPROFILE': p.absolute('profile')},
          isWindows: true);
      expect(home.root, p.join(p.absolute('profile'), 'cfvm'));
    });

    test('CFVM_HOME overrides the default', () {
      final home = CfvmHome.fromEnvironment(
          {'HOME': '/Users/me', 'CFVM_HOME': p.absolute('custom')},
          isWindows: false);
      expect(home.root, p.absolute('custom'));
    });

    test('fails clearly without a home directory', () {
      expect(() => CfvmHome.fromEnvironment({}, isWindows: false),
          throwsA(isA<CfvmException>()));
    });
  });
}
