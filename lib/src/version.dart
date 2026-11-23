import 'errors.dart';

/// Channels that are installed from official release archives.
const archiveChannels = {'stable', 'beta'};

/// Channels that have no release archives and are installed with git.
const gitChannels = {'master'};

bool isChannel(String name) =>
    archiveChannels.contains(name) || gitChannels.contains(name);

/// Normalizes user input or metadata versions to the name CFVM uses on disk:
/// trims whitespace, lowercases, and strips a leading `v` from versions such
/// as `v1.12.13+hotfix.9`.
String canonicalVersion(String input) {
  final v = input.trim().toLowerCase();
  if (v.length > 1 && v[0] == 'v' && _isDigit(v.codeUnitAt(1))) {
    return v.substring(1);
  }
  return v;
}

final _validName = RegExp(r'^[a-z0-9][a-z0-9._+-]*$');

/// Version names become directory names, so reject anything that could
/// escape the versions directory (e.g. `../foo`) or is otherwise malformed.
bool isValidVersionName(String name) =>
    _validName.hasMatch(name) && !name.contains('..');

void validateVersionName(String name) {
  if (!isValidVersionName(name)) {
    throw CfvmException(
      '"$name" is not a valid Flutter version.',
      hint: 'Use a version such as 3.19.0, or a channel: stable, beta, master.',
    );
  }
}

/// Orders version names. Release versions compare numerically, a pre-release
/// (`3.20.0-1.2.pre`) sorts before its release (`3.20.0`), and non-numeric
/// names such as `master` sort after every version.
int compareVersions(String a, String b) {
  final aIsVersion = _startsWithDigit(a);
  final bIsVersion = _startsWithDigit(b);
  if (aIsVersion != bIsVersion) return aIsVersion ? -1 : 1;
  if (!aIsVersion) return a.compareTo(b);

  final aDash = a.indexOf('-');
  final bDash = b.indexOf('-');
  final aCore = aDash == -1 ? a : a.substring(0, aDash);
  final bCore = bDash == -1 ? b : b.substring(0, bDash);
  final core = _compareNumbers(aCore, bCore);
  if (core != 0) return core;

  if (aDash == -1 && bDash == -1) return 0;
  if (aDash == -1) return 1;
  if (bDash == -1) return -1;
  return _compareNumbers(a.substring(aDash + 1), b.substring(bDash + 1));
}

final _number = RegExp(r'\d+');

int _compareNumbers(String a, String b) {
  final an = _number.allMatches(a).map((m) => int.parse(m[0]!)).toList();
  final bn = _number.allMatches(b).map((m) => int.parse(m[0]!)).toList();
  for (var i = 0; i < an.length && i < bn.length; i++) {
    if (an[i] != bn[i]) return an[i].compareTo(bn[i]);
  }
  return an.length.compareTo(bn.length);
}

bool _startsWithDigit(String s) => s.isNotEmpty && _isDigit(s.codeUnitAt(0));

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
