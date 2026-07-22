import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: false,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
);

void logInfo(String message) => logger.i(message);
void logWarning(String message) => logger.w(message);
void logError(String message, [Object? error, StackTrace? stackTrace]) =>
    logger.e(message, error: error, stackTrace: stackTrace);
void logDebug(String message) => logger.d(message);
