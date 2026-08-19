// Enforces the project's 100-line-per-file budget.
//
// A file that outgrows a screenful stops being one idea. The cap is mechanical
// so it cannot be argued with case by case; when a file exceeds it, the fix is
// to extract a type, not to raise the number.
//
// Run: dart run tool/check_file_length.dart
import 'dart:io';

/// Source trees the budget applies to.
const _roots = [
  'lib',
  'test',
  'tool',
  'android/app/src/main/kotlin',
  'android/app/src/main/cpp',
];

/// Vendored code we do not own and must not reformat.
const _excludedSegments = ['third_party', 'build', '.dart_tool'];

const _extensions = {'.dart', '.kt', '.cpp', '.h', '.hpp', '.c'};

const _limit = 100;

void main(List<String> args) {
  final offenders = <(String, int)>[];

  for (final root in _roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;

    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File) continue;

      final path = entity.path;
      if (_isExcluded(path) || !_isSource(path)) continue;

      final lines = entity.readAsLinesSync().length;
      if (lines > _limit) offenders.add((path, lines));
    }
  }

  if (offenders.isEmpty) {
    stdout.writeln('All source files are within the $_limit-line budget.');
    return;
  }

  offenders.sort((a, b) => b.$2.compareTo(a.$2));

  stderr.writeln('${offenders.length} file(s) exceed the $_limit-line budget:');
  stderr.writeln();
  for (final (path, lines) in offenders) {
    stderr.writeln('  ${lines.toString().padLeft(5)}  $path');
  }
  stderr.writeln();
  stderr.writeln('Extract a type into its own file rather than raising the cap.');
  exitCode = 1;
}

bool _isExcluded(String path) {
  final segments = path.split(Platform.pathSeparator);
  return segments.any(_excludedSegments.contains);
}

bool _isSource(String path) {
  final dot = path.lastIndexOf('.');
  return dot != -1 && _extensions.contains(path.substring(dot));
}
