import 'package:logger/logger.dart';

/// Set once the database is ready (see `main.dart`), so every log event can
/// be persisted for later viewing/sharing. Kept as a plain callback rather
/// than an import of the repository, so this low-level, widely-imported
/// module never depends on the data layer. Before it is set, log events are
/// console-only, same as before this feature existed.
typedef LogSink = void Function(String level, String message);
LogSink? logSink;

class _PersistingOutput extends LogOutput {
  @override
  void output(OutputEvent event) => logSink?.call(event.level.name, event.lines.join('\n'));
}

final logger = Logger(
  // The package's default filter drops debug/trace output in release
  // builds. This app ships release APKs only and has no telemetry, so that
  // would silently mean the least detail is captured exactly where a real
  // user hits a real problem. ProductionFilter keeps full verbosity in both.
  filter: ProductionFilter(),
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: false,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
  output: MultiOutput([ConsoleOutput(), _PersistingOutput()]),
);

void logInfo(String message) => logger.i(message);
void logWarning(String message) => logger.w(message);
void logError(String message, [Object? error, StackTrace? stackTrace]) =>
    logger.e(message, error: error, stackTrace: stackTrace);
void logDebug(String message) => logger.d(message);
