import 'dart:convert';
import 'dart:io';

import 'package:cfvm/src/config/global_config.dart';
import 'package:cfvm/src/config/project_config.dart';
import 'package:cfvm/src/errors.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('cfvm_config_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('ProjectConfig', () {
    test('saves readable JSON and loads it back', () {
      ProjectConfig.save(tmp.path, '3.19.0');
      final file = File(p.join(tmp.path, '.cfvm.json'));
      expect(jsonDecode(file.readAsStringSync()), {'flutter': '3.19.0'});
      expect(ProjectConfig.load(tmp.path)!.flutterVersion, '3.19.0');
    });

    test('keeps unknown keys when updating', () {
      File(p.join(tmp.path, '.cfvm.json'))
          .writeAsStringSync('{"flutter": "3.19.0", "note": "keep"}');
      ProjectConfig.save(tmp.path, '3.22.1');
      final json =
          jsonDecode(File(p.join(tmp.path, '.cfvm.json')).readAsStringSync());
      expect(json, {'flutter': '3.22.1', 'note': 'keep'});
    });

    test('find searches parent directories', () {
      ProjectConfig.save(tmp.path, '3.19.0');
      final nested = Directory(p.join(tmp.path, 'lib', 'src'))
        ..createSync(recursive: true);
      final found = ProjectConfig.find(nested.path)!;
      expect(found.flutterVersion, '3.19.0');
      expect(p.equals(found.directory, tmp.path), isTrue);
    });

    test('findProjectRoot prefers an existing config, then pubspec.yaml', () {
      final app = Directory(p.join(tmp.path, 'app'))..createSync();
      final nested = Directory(p.join(app.path, 'lib'))..createSync();
      File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync('name: app');
      expect(p.equals(ProjectConfig.findProjectRoot(nested.path)!, app.path),
          isTrue);

      ProjectConfig.save(tmp.path, '3.19.0');
      expect(p.equals(ProjectConfig.findProjectRoot(nested.path)!, tmp.path),
          isTrue);
    });

    test('rejects invalid content', () {
      final file = File(p.join(tmp.path, '.cfvm.json'));
      file.writeAsStringSync('not json');
      expect(() => ProjectConfig.load(tmp.path), throwsA(isA<CfvmException>()));
      file.writeAsStringSync('{"flutter": 3}');
      expect(() => ProjectConfig.load(tmp.path), throwsA(isA<CfvmException>()));
      file.writeAsStringSync('{"flutter": "../../evil"}');
      expect(() => ProjectConfig.load(tmp.path), throwsA(isA<CfvmException>()));
    });
  });

  group('GlobalConfig', () {
    test('defaults to empty when missing', () {
      final config = GlobalConfig.load(p.join(tmp.path, 'config.json'));
      expect(config.globalVersion, isNull);
      expect(config.projects, isEmpty);
    });

    test('round-trips version and projects without duplicates', () {
      final path = p.join(tmp.path, 'nested', 'config.json');
      GlobalConfig(globalVersion: '3.19.0')
        ..addProject('/a')
        ..addProject('/a')
        ..addProject('/b')
        ..save(path);
      final loaded = GlobalConfig.load(path);
      expect(loaded.globalVersion, '3.19.0');
      expect(loaded.projects, ['/a', '/b']);
      expect(File('$path.tmp').existsSync(), isFalse);
    });

    test('rejects invalid content', () {
      final path = p.join(tmp.path, 'config.json');
      File(path).writeAsStringSync('{"globalVersion": ["x"]}');
      expect(() => GlobalConfig.load(path), throwsA(isA<CfvmException>()));
    });
  });
}
